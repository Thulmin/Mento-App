plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("com.google.android.libraries.mapsplatform.secrets-gradle-plugin")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "thulmin.icbt.mento"
    // Current AndroidX transitive dependencies require API 36 at compile time.
    // This does not independently change the target or minimum SDK behavior.
    compileSdk = 36
    // Flutter 3.29 defaults to NDK 26.3, but this workstation's 26.3 package
    // is incomplete. NDK 27 is installed and is compatible with the plugins
    // used by Mento; pinning it also makes CI/tooling requirements explicit.
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "thulmin.icbt.mento"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Local release verification uses the debug key. Configure a
            // protected upload keystore in CI before distributing a store build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

secrets {
    defaultPropertiesFileName = "secrets.properties.defaults"
    ignoreList.add("keyToIgnore")
}

flutter {
    source = "../.."
}
