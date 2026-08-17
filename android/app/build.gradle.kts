plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.btcc.app2"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.btcc.app2"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Debug/profile: include x86_64 so Android Studio emulators can load
        // libflutter.so. Release stays arm64-only (Play / physical devices).
        ndk {
            abiFilters.clear()
            abiFilters.addAll(listOf("arm64-v8a", "x86_64"))
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Play's 16 KB check is for 64-bit only; ship arm64-v8a to avoid
            // Studio/Play noise from 32-bit and emulator x86_64 prebuilts.
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

dependencies {
    // Required for FlexMul / FlexAddV2 in the scoring model.
    // Paired with MainActivity FlexDelegate → Dart InterpreterOptions.
    //
    // WARNING: Maven 2.16.1 ships libtensorflowlite_flex_jni.so with 4 KB ELF
    // alignment. That triggers Android Studio's 16 KB page-size warning and
    // prevents loading on 16 KB devices (many newer Samsungs). There is no
    // official 16 KB select-tf-ops AAR yet; LiteRT core is 16 KB but Flex is not.
    // Emulators (4 KB pages) work; physical 16 KB phones need a rebuilt Flex
    // .so or a model without SELECT_TF_OPS.
    implementation("org.tensorflow:tensorflow-lite-select-tf-ops:2.16.1")
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

