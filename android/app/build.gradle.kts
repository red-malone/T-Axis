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
    namespace = "com.example.t_axis"
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
        // Base Application ID
        applicationId = "com.example.t_axis"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 1. Add the flavor dimension
    flavorDimensions += "platform"

    // 2. Define the Watch and Mobile flavors using Kotlin DSL syntax
    productFlavors {
        create("watch") {
            dimension = "platform"
            applicationIdSuffix = ".watch"
            versionNameSuffix = "-watch"
            // Wear OS strictly requires at least SDK 23
            minSdk = 23
        }
        create("mobile") {
            dimension = "platform"
            // The mobile app inherits the base configurations
        }
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