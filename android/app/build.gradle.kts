import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val googleMapsApiKey: String =
    localProperties.getProperty("GOOGLE_MAPS_API_KEY")
        ?: System.getenv("GOOGLE_MAPS_API_KEY")
        ?: ""

fun releaseSigningValue(propertyName: String, envName: String): String? =
    localProperties.getProperty(propertyName)
        ?: System.getenv(envName)

val releaseStoreFile = releaseSigningValue("RELEASE_STORE_FILE", "ANDROID_RELEASE_STORE_FILE")
val releaseStorePassword = releaseSigningValue("RELEASE_STORE_PASSWORD", "ANDROID_RELEASE_STORE_PASSWORD")
val releaseKeyAlias = releaseSigningValue("RELEASE_KEY_ALIAS", "ANDROID_RELEASE_KEY_ALIAS")
val releaseKeyPassword = releaseSigningValue("RELEASE_KEY_PASSWORD", "ANDROID_RELEASE_KEY_PASSWORD")
val hasReleaseSigningConfig = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "com.runnerio.app"
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
        applicationId = "com.runnerio.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.17.0")
}

flutter {
    source = "../.."
}
