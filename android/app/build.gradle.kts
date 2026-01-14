plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.health_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true // Giữ nguyên dòng này
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.example.health_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Tắt tối ưu hóa code (R8) để tránh lỗi xung đột thư viện khi build file APK
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // CHỈ dòng này dùng coreLibraryDesugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Các dòng dưới đây dùng implementation
    implementation("com.google.android.gms:play-services-auth:21.3.0")

    // --- QUAN TRỌNG: Ép dùng bản 1.15.0 để không bị lỗi Gradle ---
    implementation("androidx.core:core-ktx:1.15.0")

    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.22")
}