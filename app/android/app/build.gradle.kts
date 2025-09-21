plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vigil.night.night_vigil"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8 // It's safer to stick to 1.8 for wider compatibility
        targetCompatibility = JavaVersion.VERSION_1_8
        // --- THIS IS THE FIX ---
        isCoreLibraryDesugaringEnabled = true
        // -------------------
    }

    kotlinOptions {
        jvmTarget = "1.8" // Match the compatibility version
    }

    defaultConfig {
        applicationId = "com.vigil.night.night_vigil"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // This line is still required
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}