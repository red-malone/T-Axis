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

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Product flavors so the same codebase can build a phone companion app
    // and a Wear OS app. The Flutter entry points (lib/main_mobile.dart,
    // lib/main_watch.dart) and source sets (src/mobile, src/watch) map to
    // these flavors. They share the applicationId "com.example.t_axis" so the
    // single google-services.json (Firebase) keeps matching — the two apps run
    // on separate devices (phone vs Wear OS), so they don't collide.
    flavorDimensions += "device"
    productFlavors {
        create("mobile") {
            dimension = "device"
        }
        create("watch") {
            dimension = "device"
        }
    }
}

flutter {
    source = "../.."
}
