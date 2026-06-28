import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material. Local builds read it from key.properties (gitignored);
// CI reads it from environment variables (secrets via env only — see CLAUDE.md).
// When neither is configured, the release build falls back to the debug keys so
// `flutter run --release` and local dev keep working with no secrets.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun signingValue(propKey: String, envKey: String): String? =
    keystoreProperties.getProperty(propKey) ?: System.getenv(envKey)

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val hasReleaseSigning = !releaseStoreFile.isNullOrBlank()

// Meta glasses release channel (M10). The native mirror of the Dart
// `GLASSES_ENABLED` dart-define: pass `-Pglasses=true` (or set GLASSES_ENABLED=true)
// to build the glasses-channel target. The Meta Device Access Toolkit is
// proprietary and not on a public Maven repo, so it is never committed; drop the
// vendored `.aar`/`.jar` into `app/android/app/libs/` for this target only. The
// SDK is detected reflectively at runtime (see DatSdkClient.kt), so the default
// consumer build — which links nothing here — falls back to MockSensorSource.
val glassesChannel = (project.findProperty("glasses") as String?)?.toBoolean()
    ?: System.getenv("GLASSES_ENABLED").toBoolean()

android {
    namespace = "com.gymbuddy.gymbuddy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.gymbuddy.gymbuddy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect (the health package's Android backend) requires API 26+.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Sign with the real release keystore when it's configured (CI/beta
            // pipeline); otherwise fall back to the debug keys so local
            // `flutter run --release` works with no secrets.
            signingConfig =
                if (hasReleaseSigning) {
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

dependencies {
    // Link any vendored DAT SDK artifacts only for the glasses release channel.
    // Harmless when libs/ is empty (fileTree matches nothing); the default
    // consumer build never references it.
    if (glassesChannel) {
        implementation(
            fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar", "*.jar"))),
        )
    }
}

flutter {
    source = "../.."
}
