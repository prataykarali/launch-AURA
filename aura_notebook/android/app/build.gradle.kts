plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.example.aura_notebook" // Ensure this matches your package name
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.14904198"
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // This replaces the deprecated jvmTarget line
        freeCompilerArgs += listOf("-P", "plugin:org.jetbrains.kotlin.panel:jvmTarget=17")
    }

    defaultConfig {
        applicationId = "com.example.aura_notebook"
        minSdk = flutter.minSdkVersion // Required for many Rust-based libraries
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Only arm64-v8a is built/tested. Locking the ABI here prevents an
        // accidental stale-arch .so (e.g. an old armeabi-v7a/x86_64 build that
        // predates a flutter_rust_bridge regen) from being packaged and shipped
        // — which is exactly how the bridge-desync crash slipped out before.
        ndk { abiFilters += "arm64-v8a" }
    }

    buildTypes {
        getByName("release") {
            // Using debug signing for local cable deployment
            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
