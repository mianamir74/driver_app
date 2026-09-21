import java.util.Properties
import java.io.FileInputStream

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

// ── Release signing — added 18 September 2026, Play Store submission prep ──
//
// Android has never had a real release build (see comment on applicationId
// below) — release always signed with the debug keys. Play Store requires a
// real upload key.
//
// Reads android/key.properties, which is gitignored (see android/.gitignore)
// and refused by the repo's push scripts (_PUSH_ENGINE.bat's secret scan) —
// so this file must be created LOCALLY on the machine doing the release
// build, never committed. Generate it once with:
//
//   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
//     -keysize 2048 -validity 10000 -alias upload
//
// then create android/key.properties (NOT committed) with:
//   storePassword=<password you set above>
//   keyPassword=<password you set above>
//   keyAlias=upload
//   storeFile=/absolute/path/to/upload-keystore.jks
//
// If key.properties is missing (e.g. a normal dev machine), release builds
// fall back to debug signing exactly as before — `flutter run --release`
// keeps working without a real keystore. Only a build with key.properties
// present produces something installable/uploadable to Play Console.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real upload key when android/key.properties exists (see the
            // comment above), debug keys otherwise so `flutter run --release`
            // keeps working on a normal dev machine without one.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}