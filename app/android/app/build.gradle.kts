import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Play Store signing: android/key.properties (git-ignored) with storeFile, storePassword,
// keyAlias and keyPassword. Without it, release builds fall back to the debug key.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.notivo.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "com.notivo.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Flutter's plugin lists every ABI here, so plugin .so files (dartjni) ship for all of them even
        // with --target-platform: a 32-bit phone would install the arm64 APK and crash on launch.
        (project.findProperty("target-platform") as String?)?.let { platforms ->
            val abis = mapOf("android-arm" to "armeabi-v7a", "android-arm64" to "arm64-v8a", "android-x64" to "x86_64")
            ndk {
                abiFilters.clear()
                abiFilters += platforms.split(",").map { abis.getValue(it) }
            }
        }
    }
    signingConfigs {
        if (keyProperties.isNotEmpty()) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // shortcut: R8 fails here (AGP 9.1 does not extract proguard-android-optimize.txt),
            // so release builds skip shrinking; turn it back on once AGP/Flutter fix it.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin { compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 } }
flutter { source = "../.." }
