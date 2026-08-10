plugins {
    id("com.android.application")

    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("com.google.firebase.crashlytics")

    id("kotlin-android")

    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Left as com.goouts.driver_app ON PURPOSE. `namespace` is a build time
    // detail that must keep matching the Kotlin package of MainActivity, and
    // changing it would mean moving the source directory for no user visible
    // gain. The identity that matters is `applicationId` below.
    namespace = "com.goouts.driver_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // com.goouts.lead, matching iOS. Corrected 3 August 2026: this was
        // com.goouts.driver_app while iOS was com.goouts.lead, so the same app
        // had two identities. Safe to change because Android has never been
        // released: no signing keystore, and CI only builds iOS TestFlight.
        //
        // After a Play release this would NOT have been safe. A changed
        // applicationId is a new app that existing installs never receive.
        applicationId = "com.goouts.lead"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so flutter run --release works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}