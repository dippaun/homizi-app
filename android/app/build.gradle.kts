import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. Never commit key.properties or the keystore.
// Environment variables override the file so CI can inject them without a checkout secret.
// See docs/release/SIGNING.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.isFile) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun signingValue(property: String, envName: String): String {
    val fromEnv = System.getenv(envName)?.trim().orEmpty()
    if (fromEnv.isNotEmpty()) {
        return fromEnv
    }
    return keystoreProperties.getProperty(property)?.trim().orEmpty()
}

fun resolveUploadStoreFile(raw: String): File? {
    if (raw.isEmpty()) {
        return null
    }
    val direct = File(raw)
    val candidates = if (direct.isAbsolute) {
        listOf(direct)
    } else {
        // key.properties lives in android/. Paths are accepted from that
        // directory or from the app module.
        listOf(
            File(rootProject.projectDir, raw),
            File(rootProject.projectDir, "app/$raw"),
        )
    }
    return candidates.firstOrNull { it.isFile }
}

val uploadStoreFileRaw = signingValue("storeFile", "HOMIZI_UPLOAD_STORE_FILE")
val uploadStorePassword = signingValue("storePassword", "HOMIZI_UPLOAD_STORE_PASSWORD")
val uploadKeyAlias = signingValue("keyAlias", "HOMIZI_UPLOAD_KEY_ALIAS")
val uploadKeyPassword = signingValue("keyPassword", "HOMIZI_UPLOAD_KEY_PASSWORD")
val uploadStoreFile = resolveUploadStoreFile(uploadStoreFileRaw)
val releaseSigningReady =
    uploadStoreFile != null &&
        uploadStorePassword.isNotEmpty() &&
        uploadKeyAlias.isNotEmpty() &&
        uploadKeyPassword.isNotEmpty()

if (!releaseSigningReady) {
    val missing = buildList {
        if (uploadStoreFile == null) add("storeFile")
        if (uploadStorePassword.isEmpty()) add("storePassword")
        if (uploadKeyAlias.isEmpty()) add("keyAlias")
        if (uploadKeyPassword.isEmpty()) add("keyPassword")
    }
    println(
        "WARNING: HOMIZI release signing is not configured (missing: ${missing.joinToString(", ")}). " +
            "This release build is signed with the debug keystore and must not be uploaded to Google Play. " +
            "Provide android/key.properties or HOMIZI_UPLOAD_STORE_FILE, HOMIZI_UPLOAD_STORE_PASSWORD, " +
            "HOMIZI_UPLOAD_KEY_ALIAS, and HOMIZI_UPLOAD_KEY_PASSWORD. Values are not printed.",
    )
} else {
    println(
        "HOMIZI release signing: using the upload key. The keystore path and passwords are not printed.",
    )
}

android {
    namespace = "app.homizi"
    // Play requires API 36+ for new apps and updates from 31 Aug 2026.
    // https://support.google.com/googleplay/android-developer/answer/11926878
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
                storePassword = uploadStorePassword
                storeFile = uploadStoreFile
            }
        }
    }

    defaultConfig {
        // OWNER DECISION: placeholder store id. Confirm before any store listing.
        // `in` is not a valid Java package segment, so the Android namespace is app.homizi.
        applicationId = "in.homizi.app"
        // sentry_flutter 10 requires Android 8 (API 26).
        minSdk = 26
        targetSdk = 36
        // versionName is MAJOR.MINOR.PATCH and versionCode is the integer after +
        // in pubspec.yaml. CI may pass --build-name and --build-number.
        // See docs/release/VERSIONING.md.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // R8 shrinks and obfuscates the Android (Java/Kotlin) code.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (releaseSigningReady) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Applied only after the owner drops android/app/google-services.json.
// The file is gitignored. A missing file must not fail the build.
if (file("google-services.json").isFile) {
    apply(plugin = "com.google.gms.google-services")
}
