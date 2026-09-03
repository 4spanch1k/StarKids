plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("Release", ignoreCase = true) ||
        taskName.contains("Profile", ignoreCase = true)
}

fun configuredValue(propertyName: String, environmentName: String): String? =
    providers.gradleProperty(propertyName)
        .orElse(providers.environmentVariable(environmentName))
        .orNull
        ?.trim()
        ?.takeIf { it.isNotEmpty() }

val productionApplicationId = configuredValue(
    propertyName = "ANDROID_APPLICATION_ID",
    environmentName = "ANDROID_APPLICATION_ID",
)
val releaseStoreFile = configuredValue("RELEASE_STORE_FILE", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = configuredValue("RELEASE_STORE_PASSWORD", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = configuredValue("RELEASE_KEY_ALIAS", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = configuredValue("RELEASE_KEY_PASSWORD", "ANDROID_KEY_PASSWORD")
val releaseSigningConfigured = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }

if (
    releaseTaskRequested &&
    (productionApplicationId == null || productionApplicationId.startsWith("com.example."))
) {
    throw GradleException(
        "Production Android applicationId is not configured. " +
            "Set -PANDROID_APPLICATION_ID or ANDROID_APPLICATION_ID before a release build.",
    )
}

if (releaseTaskRequested && !releaseSigningConfigured) {
    throw GradleException(
        "Production Android release signing is not configured. " +
            "Set RELEASE_STORE_FILE/RELEASE_STORE_PASSWORD/RELEASE_KEY_ALIAS/RELEASE_KEY_PASSWORD " +
            "or their ANDROID_* environment variables. Debug signing is never used for release.",
    )
}

android {
    namespace = "com.example.star_kids_mobile"
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
        // Debug keeps the legacy package until the deployment owner supplies the
        // authoritative production application id. Release builds fail above
        // when that value is not explicitly configured.
        applicationId = productionApplicationId ?: "com.example.star_kids_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("productionRelease") {
            storeFile = releaseStoreFile?.let { file(it) }
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("productionRelease")
        }
    }
}

flutter {
    source = "../.."
}
