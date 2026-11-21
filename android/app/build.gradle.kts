import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// امضای ثابت release: با key.properties همهٔ نسخه‌ها یک امضا دارند و روی هم
// نصب (آپدیت) می‌شوند. بدون آن، کلید debug هر سیستم فرق می‌کند و اندروید
// خطای «برنامه نصب نشد» می‌دهد.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.forougharya.forough_mobile"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications به desugaring نیاز دارد (java.time روی API<26)
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.forougharya.forough_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // کاهش حجم: فقط زبان‌هایی که اپ لازم دارد بسته‌بندی شود
        resourceConfigurations += listOf("fa", "en")
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // کاهش حجم: کوچک‌سازی کد (R8) + حذف منابع بی‌استفاده
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")

            ndk {
                // حذف معماری شبیه‌ساز x86_64 از نسخهٔ نهایی (~۱۵ تا ۲۵ مگابایت کاهش حجم APK یونیورسال)
                // هر دو معماری گوشی‌های واقعی (arm64-v8a و armeabi-v7a) حفظ می‌شوند و با --split-per-abi سازگار است
                abiFilters.remove("x86_64")
                // حذف جدول سمبل‌های دیباگ بومی از فایل‌های .so
                debugSymbolLevel = "NONE"
            }
        }
    }

    packaging {
        jniLibs {
            // فشرده‌سازی کتابخانه‌های بومی (libflutter.so / libapp.so) داخل فایل APK:
            // در minSdk>=23 پیش‌فرض جدید اندروید ذخیره‌سازی بدون فشرده‌سازی است که حجم فایل APK را ۲ برابر می‌کند!
            useLegacyPackaging = true
        }
        resources {
            excludes += setOf(
                "META-INF/*.version",
                "META-INF/androidx.*",
                "META-INF/*.kotlin_module",
                "META-INF/kotlin-project-structure-metadata.json",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
                "DebugProbesKt.bin",
                "kotlin-tooling-metadata.json",
            )
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // برای درخواست مجوز میکروفن (ContextCompat / ActivityCompat)
    implementation("androidx.core:core-ktx:1.13.1")
}
