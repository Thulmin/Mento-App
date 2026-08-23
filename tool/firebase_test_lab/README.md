# Mento authenticated Robo test

This Firebase Test Lab journey uses normal email/password authentication and the
dedicated test credentials embedded in `mento_authenticated_robo.json`. It does
not use Google or Apple authentication, does not open password reset, and does
not sign out or delete account data.

The journey verifies:

1. normal email/password login and the authenticated Today dashboard
2. the live Mento assistant with a read-only account-context prompt
3. Plan, Focus, Progress, and Profile navigation
4. AI study-plan generation when the account has the required active work and
   the Today screen exposes `Build a study plan`

The assistant and planner each retry up to three times when their stable error
marker appears. If the free AI provider remains unavailable after those retries,
the response check is recorded but does not fail the whole app matrix. Plan
results are never accepted, so the planner test performs no plan write. The
script terminates the crawl after its guarded journey.

## Why this version is more reliable

The previous script failed on its eighth action and then Robo switched to
uncontrolled exploration. Flutter text fields also had empty Android resource
IDs, which made Firebase's predefined text input unreliable.

Mento now assigns stable Android accessibility/resource identifiers to the
login fields, submit action, authenticated screen titles, AI composer, retry
markers, and response markers. The script uses those identifiers instead of
screen coordinates or OCR for critical actions and assertions.

Study Locations is deliberately excluded from this Robo journey. Frame-by-frame
video and log analysis of the 11 August Pixel 5/API 30 run showed that login,
Today, the map, and the saved location all rendered successfully. Robo then
stalled while traversing the Google Maps platform-view accessibility tree after
Flutter logged `Rejecting attempt to make a View its own child`. This is a Robo
and embedded-platform-view compatibility problem, not an app crash. Test the map
separately with a Flutter integration or Android instrumentation test.

The runner also passes `--no-auto-google-login`, uses strict script execution,
and requests post-script crawl termination. See the official
[Robo scripts reference](https://firebase.google.com/docs/test-lab/android/robo-scripts-reference)
for these options.

## Prerequisites

- Google Cloud CLI available on `PATH`
- JDK 17 through 23 (the runner auto-detects common Windows installations)
- an active `gcloud auth login` session
- access to the Firebase project in `.firebaserc`
- Firebase Test Lab enabled for the project
- `android/app/google-services.json` present locally
- sufficient Test Lab quota or billing allowance

The runner passes `--no-resign` so Test Lab exercises the exact locally signed
APK that was built and validated.

## Run

Build the updated APK and submit the API 36 Medium Phone test:

```powershell
.\tool\firebase_test_lab\run_authenticated_robo.ps1
```

The command is synchronous, uses a 12-minute timeout, and preserves Test Lab's
documented exit code. Do not reduce the timeout below 10 minutes: the Pixel 5
failure from 11 August had only a short execution window, while the guarded AI
retries can legitimately take several minutes. If you upload the script through
the Firebase console instead of using this runner, set **Test timeout** to at
least **12 minutes**.

Validate the script and preview the command without building or uploading:

```powershell
.\tool\firebase_test_lab\run_authenticated_robo.ps1 -DryRun
```

Reuse an APK only after rebuilding it with the new Robo selectors:

```powershell
flutter build apk --debug
.\tool\firebase_test_lab\run_authenticated_robo.ps1 -SkipBuild
```

If the compatible JDK is installed somewhere else, select it without changing
Flutter's global configuration:

```powershell
.\tool\firebase_test_lab\run_authenticated_robo.ps1 `
  -JavaHome "C:\path\to\jdk-23"
```

The pre-existing APK from before this change does not contain the identifiers
required by the authenticated script.

Select another supported device or a small matrix:

```powershell
.\tool\firebase_test_lab\run_authenticated_robo.ps1 `
  -Device @(
    "model=MediumPhone.arm,version=35,locale=en,orientation=portrait",
    "model=MediumPhone.arm,version=36,locale=en,orientation=portrait"
  )
```

Test Lab device availability changes. If the runner returns exit code 18, list
currently supported models with:

```powershell
gcloud firebase test android models list --filter=virtual
```

## Files

- `mento_authenticated_robo.json` — guarded login, navigation, AI retries, and
  exclusions
- `run_authenticated_robo.ps1` — build, preflight, submit, wait, and exit-code
  runner
