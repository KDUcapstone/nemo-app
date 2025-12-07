import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")        // ✅ 이렇게 변경
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")      // ✅ Google Services 플러그인 추가
}

val keystoreProperties: Properties = Properties()
val keystorePropertiesFile: File = rootProject.file("keystore.properties")

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { input ->
        keystoreProperties.load(input)
    }
}

android {
    namespace = "com.example.frontend"
    // Override Flutter's default to compile against Android 36
    compileSdk = 36
    ndkVersion =  "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.frontend"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("nemoDebug") {
            val storeFilePath: String =
                (keystoreProperties["storeFile"] as String?) ?: "app/keystore/nemo-debug.jks"
            val storePasswordProp: String? = keystoreProperties["storePassword"] as String?
            val keyAliasProp: String = (keystoreProperties["keyAlias"] as String?) ?: "nemo-debug"
            val keyPasswordProp: String? = keystoreProperties["keyPassword"] as String?

            storeFile = file(storeFilePath)
            storePassword = storePasswordProp
            keyAlias = keyAliasProp
            keyPassword = keyPasswordProp
        }
    }


    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("nemoDebug")
            isMinifyEnabled = false
            // shrinkResources 기본 false
        }
        release {
            signingConfig = signingConfigs.getByName("nemoDebug")
            // shrinkResources 쓰고 싶으면:
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
}