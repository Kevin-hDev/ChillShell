import java.util.Properties
import java.io.FileInputStream

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

// Load release signing properties if available
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
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

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.vibeterm.vibeterm"
        minSdk = 31
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use production keystore if key.properties exists, otherwise debug keys
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // TODO: Configure key.properties for production signing
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    // AndroidX Core for NotificationCompat in TailscaleVpnService
    implementation("androidx.core:core-ktx:1.12.0")

    // EncryptedSharedPreferences for libtailscale AppContext
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // Coroutines for async IPN Bus watcher and LocalAPI calls
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // libtailscale.aar built from gomobile (tailscale-android)
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))
}

flutter {
    source = "../.."
}
