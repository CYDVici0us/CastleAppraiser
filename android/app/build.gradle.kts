plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.btcc.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.btcc.app"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Play's 16 KB check is for 64-bit only; ship arm64-v8a to avoid
        // Studio/Play noise from 32-bit and emulator x86_64 prebuilts.
        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            ndk {
                abiFilters.clear()
                abiFilters.add("arm64-v8a")
            }
        }
    }

    androidResources {
        noCompress += listOf("tflite", "lite")
    }

    // Keep native libs uncompressed so 16 KB ELF alignment is preserved in the APK/AAB.
    packaging {
        jniLibs {
            useLegacyPackaging = false
            excludes += setOf(
                "**/armeabi-v7a/**",
                "**/x86/**",
                "**/x86_64/**",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

// 16 KB page-size: pin AndroidX natives known to pass Play/Studio checks, and
// drop unused LiteRT GPU .so (this app does not enable the GPU delegate).
configurations.configureEach {
    exclude(group = "com.google.ai.edge.litert", module = "litert-gpu")
    exclude(group = "com.google.ai.edge.litert", module = "litert-gpu-api")
    resolutionStrategy {
        force("androidx.datastore:datastore:1.2.1")
        force("androidx.datastore:datastore-android:1.2.1")
        force("androidx.datastore:datastore-core:1.2.1")
        force("androidx.datastore:datastore-core-android:1.2.1")
        force("androidx.datastore:datastore-preferences:1.2.1")
        force("androidx.datastore:datastore-preferences-android:1.2.1")
        force("androidx.datastore:datastore-preferences-core:1.2.1")
        force("androidx.camera:camera-core:1.6.1")
    }
}

