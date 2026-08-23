[CmdletBinding()]
param(
    [string]$ProjectId = "",
    [string]$ApkPath = "build\app\outputs\flutter-apk\app-debug.apk",
    [string]$RoboScriptPath = "",
    [string[]]$Device = @(
        "model=MediumPhone.arm,version=36,locale=en,orientation=portrait"
    ),
    [ValidatePattern('^\d+(s|m|h)$')]
    [string]$Timeout = "12m",
    [string]$MatrixLabel = "",
    [string]$JavaHome = "",
    [switch]$SkipBuild,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-AbsoluteProjectPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $Path))
}

function Assert-CommandAvailable {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$InstallHint
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "'$Name' is required. $InstallHint"
    }
}

function Get-CompatibleJavaHome {
    param(
        [string]$RequestedJavaHome
    )

    $candidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($RequestedJavaHome)) {
        $candidates.Add($RequestedJavaHome)
    }
    else {
        foreach ($candidate in @(
            $env:MENTO_JAVA_HOME,
            $env:JAVA_HOME,
            "C:\Program Files\Java\jdk-23",
            "C:\Program Files\Java\jdk-21",
            "C:\Program Files\Java\jdk-17",
            "C:\Program Files\Android\Android Studio\jbr"
        )) {
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                $candidates.Add($candidate)
            }
        }
    }

    foreach ($candidate in $candidates) {
        $resolvedCandidate = [System.IO.Path]::GetFullPath($candidate)
        $javaExecutable = Join-Path $resolvedCandidate "bin\java.exe"
        if (-not (Test-Path -LiteralPath $javaExecutable -PathType Leaf)) {
            continue
        }

        $versionOutput = (& $javaExecutable -version 2>&1 | Out-String)
        $versionMatch = [System.Text.RegularExpressions.Regex]::Match(
            $versionOutput,
            'version\s+"(?:1\.)?(\d+)'
        )
        if (-not $versionMatch.Success) {
            continue
        }
        $majorVersion = [int]$versionMatch.Groups[1].Value
        if ($majorVersion -ge 17 -and $majorVersion -le 23) {
            return [pscustomobject]@{
                Home = $resolvedCandidate
                MajorVersion = $majorVersion
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestedJavaHome)) {
        throw "-JavaHome must point to a JDK 17 through 23 installation."
    }
    throw (
        "A compatible Android JDK was not found. Install JDK 17 through 23, " +
        "then pass -JavaHome or set MENTO_JAVA_HOME. Java 25 is not compatible " +
        "with this project's current Gradle/Kotlin toolchain."
    )
}

function Assert-RoboScriptShape {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $source = Get-Content -LiteralPath $Path -Raw
    if ($source -notmatch '"strict"\s*:\s*true') {
        throw "The Robo script must use strict execution so missing actions fail the matrix."
    }
    if ($source -notmatch '"postscript"\s*:\s*\{[^}]*"terminate"\s*:\s*true') {
        throw "The Robo script must terminate the crawl after its guarded journey."
    }

    $actionsStart = $source.IndexOf("[", [System.StringComparison]::Ordinal)
    if ($actionsStart -lt 0) {
        throw "The Robo script does not contain an action array."
    }

    try {
        $topLevelItems = @($source.Substring($actionsStart) | ConvertFrom-Json)
    }
    catch {
        throw "The Robo action array is not valid JSON: $($_.Exception.Message)"
    }

    $actions = @(
        foreach ($item in $topLevelItems) {
            if ($null -ne $item.actions) {
                @($item.actions)
            }
            elseif ($null -ne $item.eventType) {
                $item
            }
        }
    )
    $eventTypes = @($actions | ForEach-Object { $_.eventType })
    foreach ($requiredEvent in @(
        "VIEW_TEXT_CHANGED",
        "VIEW_CLICKED",
        "WAIT_FOR_ELEMENT",
        "ASSERTION",
        "ELEMENT_IGNORED",
        "TERMINATE_CRAWL"
    )) {
        if ($requiredEvent -notin $eventTypes) {
            throw "The Robo script is missing the required '$requiredEvent' action."
        }
    }

    foreach ($forbiddenTarget in @("Continue with Google", "Forgot password?", "Send reset link")) {
        $unsafeClick = @(
            $actions | Where-Object {
                if ($_.eventType -ne "VIEW_CLICKED") {
                    return $false
                }
                $visionMatches =
                    $_.PSObject.Properties.Name -contains "visionText" -and
                    $_.visionText -eq $forbiddenTarget
                $descriptorMatches = $false
                if ($_.PSObject.Properties.Name -contains "elementDescriptors") {
                    foreach ($descriptor in @($_.elementDescriptors)) {
                        if (
                            $descriptor.PSObject.Properties.Name -contains "contentDescription" -and
                            $descriptor.contentDescription -eq $forbiddenTarget
                        ) {
                            $descriptorMatches = $true
                        }
                    }
                }
                return $visionMatches -or $descriptorMatches
            }
        )
        if ($unsafeClick.Count -gt 0) {
            throw "The Robo script must not click '$forbiddenTarget'."
        }
    }

    $mapsClicks = @(
        $actions | Where-Object {
            if (
                $_.eventType -ne "VIEW_CLICKED" -or
                -not ($_.PSObject.Properties.Name -contains "elementDescriptors")
            ) {
                return $false
            }
            foreach ($descriptor in @($_.elementDescriptors)) {
                if (
                    $descriptor.PSObject.Properties.Name -contains "resourceIdRegex" -and
                    $descriptor.resourceIdRegex -match "mento_open_study_locations"
                ) {
                    return $true
                }
            }
            return $false
        }
    )
    if ($mapsClicks.Count -gt 0) {
        throw (
            "Do not open Study Locations in this Robo journey. On API 30 the " +
            "embedded Google Map can stall Robo while it traverses the platform " +
            "view accessibility tree. Test Maps separately with an integration test."
        )
    }
}

function Get-TestLabExitMessage {
    param(
        [Parameter(Mandatory)]
        [int]$Code
    )

    switch ($Code) {
        0 { "All authenticated Mento Robo executions passed." }
        1 { "A general failure occurred (for example, upload, file, network, auth, or API failure)." }
        2 { "gcloud rejected an argument. Update the Google Cloud CLI and review the generated command." }
        10 { "At least one test execution did not pass." }
        15 { "Test Lab could not determine whether the matrix passed." }
        18 { "The selected device and Android version combination is unsupported." }
        19 { "The test matrix was canceled." }
        20 { "Firebase Test Lab reported an infrastructure error." }
        default { "gcloud exited with unexpected code $Code." }
    }
}

$projectRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..\..")
)
$defaultRoboScript = Join-Path $PSScriptRoot "mento_authenticated_robo.json"

$timeoutMatch = [System.Text.RegularExpressions.Regex]::Match(
    $Timeout,
    '^(\d+)(s|m|h)$'
)
$timeoutAmount = [int]$timeoutMatch.Groups[1].Value
$timeoutSeconds = switch ($timeoutMatch.Groups[2].Value) {
    "s" { $timeoutAmount }
    "m" { $timeoutAmount * 60 }
    "h" { $timeoutAmount * 3600 }
}
if ($timeoutSeconds -lt 600) {
    throw (
        "The authenticated journey requires a timeout of at least 10 minutes. " +
        "Use the default -Timeout 12m. A one-minute matrix expires during login."
    )
}

if ([string]::IsNullOrWhiteSpace($RoboScriptPath)) {
    $RoboScriptPath = $defaultRoboScript
}
if ([string]::IsNullOrWhiteSpace($MatrixLabel)) {
    $MatrixLabel = "Mento Authenticated $(Get-Date -Format 'yyyyMMdd-HHmmss')"
}
if ($MatrixLabel.Contains(",")) {
    throw "MatrixLabel cannot contain a comma because gcloud treats it as a map separator."
}

$resolvedApk = Get-AbsoluteProjectPath -Path $ApkPath -ProjectRoot $projectRoot
$resolvedRoboScript = Get-AbsoluteProjectPath `
    -Path $RoboScriptPath `
    -ProjectRoot $projectRoot

if (-not (Test-Path -LiteralPath $resolvedRoboScript -PathType Leaf)) {
    throw "Robo script not found: $resolvedRoboScript"
}
Assert-RoboScriptShape -Path $resolvedRoboScript

if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    $firebaseAliasPath = Join-Path $projectRoot ".firebaserc"
    if (-not (Test-Path -LiteralPath $firebaseAliasPath -PathType Leaf)) {
        throw "Pass -ProjectId because .firebaserc was not found."
    }
    $firebaseAliases = Get-Content -LiteralPath $firebaseAliasPath -Raw |
        ConvertFrom-Json
    $ProjectId = [string]$firebaseAliases.projects.default
}
if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    throw "Firebase ProjectId could not be resolved."
}

Push-Location $projectRoot
try {
    if (-not $DryRun -and -not $SkipBuild) {
        $firebaseConfig = Join-Path $projectRoot "android\app\google-services.json"
        if (-not (Test-Path -LiteralPath $firebaseConfig -PathType Leaf)) {
            throw "Missing android\app\google-services.json. Add the ignored Firebase Android configuration before building."
        }

        $jdk = Get-CompatibleJavaHome -RequestedJavaHome $JavaHome
        $gradleWrapper = Join-Path $projectRoot "android\gradlew.bat"
        if (-not (Test-Path -LiteralPath $gradleWrapper -PathType Leaf)) {
            throw "Gradle wrapper not found: $gradleWrapper"
        }

        Write-Host (
            "Building a debug APK with stable Firebase Robo selectors " +
            "using JDK $($jdk.MajorVersion)..."
        )
        $previousJavaHome = $env:JAVA_HOME
        $previousPath = $env:Path
        try {
            $env:JAVA_HOME = $jdk.Home
            $env:Path = (Join-Path $jdk.Home "bin") + ";" + $previousPath
            & $gradleWrapper assembleDebug --no-daemon
            if ($LASTEXITCODE -ne 0) {
                throw "Android debug APK build failed with exit code $LASTEXITCODE."
            }
        }
        finally {
            $env:JAVA_HOME = $previousJavaHome
            $env:Path = $previousPath
        }
    }

    if (-not (Test-Path -LiteralPath $resolvedApk -PathType Leaf)) {
        throw "APK not found: $resolvedApk. Run without -SkipBuild or pass -ApkPath."
    }
    $apkFile = Get-Item -LiteralPath $resolvedApk
    if ($apkFile.Length -eq 0) {
        throw "APK is empty: $resolvedApk"
    }

    $gcloudArguments = @(
        "firebase",
        "test",
        "android",
        "run",
        "--project=$ProjectId",
        "--type=robo",
        "--app=$resolvedApk",
        "--robo-script=$resolvedRoboScript",
        "--timeout=$Timeout",
        "--no-auto-google-login",
        "--no-resign",
        "--record-video",
        "--performance-metrics",
        "--results-history-name=mento-authenticated-robo",
        "--client-details=matrixLabel=$MatrixLabel"
    )
    foreach ($deviceSpec in $Device) {
        if (-not [string]::IsNullOrWhiteSpace($deviceSpec)) {
            $gcloudArguments += "--device=$deviceSpec"
        }
    }

    $displayArguments = $gcloudArguments | ForEach-Object {
        if ($_ -match '\s') { "'$_'" } else { $_ }
    }
    Write-Host ""
    Write-Host "Firebase project: $ProjectId"
    Write-Host "APK: $resolvedApk ($([math]::Round($apkFile.Length / 1MB, 1)) MiB)"
    Write-Host "Robo script: $resolvedRoboScript"
    Write-Host "Command:"
    Write-Host "gcloud $($displayArguments -join ' ')"

    if ($DryRun) {
        Write-Host ""
        Write-Host "Dry run complete. Nothing was built or uploaded."
        return
    }

    Assert-CommandAvailable `
        -Name "gcloud" `
        -InstallHint "Install the Google Cloud CLI, then run 'gcloud auth login'."

    $activeAccounts = @(
        & gcloud auth list `
            --filter="status:ACTIVE" `
            --format="value(account)" 2>$null
    )
    if ($LASTEXITCODE -ne 0 -or $activeAccounts.Count -eq 0) {
        throw "No active gcloud account. Run 'gcloud auth login' and retry."
    }

    Write-Host ""
    Write-Host "Submitting the synchronous authenticated Mento Robo matrix..."
    & gcloud @gcloudArguments
    $testExitCode = $LASTEXITCODE
    $resultMessage = Get-TestLabExitMessage -Code $testExitCode

    if ($testExitCode -eq 0) {
        Write-Host ""
        Write-Host $resultMessage -ForegroundColor Green
        return
    }

    Write-Error $resultMessage -ErrorAction Continue
    exit $testExitCode
}
finally {
    Pop-Location
}
