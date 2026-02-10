import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // Kotlin Android plugin
    id("org.jetbrains.kotlin.android")
    // Flutter plugin must come after Android & Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase / Google Services
    id("com.google.gms.google-services")
}

// ✅ Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// ✅ Force compatible androidx versions
configurations.all {
    resolutionStrategy {
        force("androidx.activity:activity:1.9.0")
        force("androidx.activity:activity-ktx:1.9.0")
    }
}

android {
    namespace = "com.bmmworkforce.driverapp"
    compileSdk = flutter.compileSdkVersion

    // ✅ Required for Firebase / background services
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.bmmworkforce.driverapp"
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ✅ PROPER RELEASE SIGNING (Play Store REQUIRED)
   signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}


    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    implementation("androidx.activity:activity:1.9.0")
    implementation("androidx.activity:activity-ktx:1.9.0")
}
