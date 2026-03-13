plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.insta360_bridge"
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
        applicationId = "com.example.insta360_bridge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = 33
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

    packaging {
        jniLibs {
            pickFirsts.add("**/libc++_shared.so")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.10.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.9.0")
    implementation("androidx.activity:activity:1.7.2")

    // HTTP Server
    implementation("org.nanohttpd:nanohttpd:2.3.1")

    // Insta360 SDK
    implementation("com.arashivision.sdk:sdkcamera:1.9.4")
    implementation("com.arashivision.sdk:sdkmedia:1.9.4")
    
}

configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.10.1")
        force("androidx.core:core-ktx:1.10.1")
        force("androidx.appcompat:appcompat:1.6.1")
        force("androidx.appcompat:appcompat-resources:1.6.1")
        force("androidx.annotation:annotation-experimental:1.3.0")
        force("androidx.activity:activity:1.7.2")
    }
}
