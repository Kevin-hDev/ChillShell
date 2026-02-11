plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Local AAR files (e.g. libtailscale.aar built from gomobile)
repositories {
    flatDir {
        dirs("libs")
    }
}

android {
    namespace = "com.vibeterm.vibeterm"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vibeterm.vibeterm"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 31
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // AndroidX Core for NotificationCompat in TailscaleVpnService
    implementation("androidx.core:core-ktx:1.12.0")

    // libtailscale.aar built from gomobile (tailscale-android)
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))
}

flutter {
    source = "../.."
}
