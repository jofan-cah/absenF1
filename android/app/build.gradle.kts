// android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Firebase
}

android {
    namespace = "com.example.f1absensi"
    compileSdk = 36  // UPDATE KE 36
    ndkVersion = "27.0.12077973"  // UPDATE KE 27

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.f1absensi"
        minSdk = flutter.minSdkVersion
        targetSdk = 36  // UPDATE KE 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
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
    // Core library desugaring (UPDATE KE 2.1.4)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // Multidex
    implementation("androidx.multidex:multidex:2.0.1")
}
