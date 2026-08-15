import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.google.gms.google-services")
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ————— Yayın imzası —————
// Anahtar bilgileri android/key.properties'ten okunur; o dosya da .jks de
// .gitignore'dadır (repo public). Dosya yoksa debug anahtarına düşülür ama o APK
// aileye DAĞITILMAMALIDIR: debug anahtarı makineye özeldir, üstüne güncelleme
// kurulamaz (INSTALL_FAILED_UPDATE_INCOMPATIBLE) ve uygulamayı silmek gerekir.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKey = keystorePropertiesFile.exists()

android {
    namespace = "com.hophop.hophop"
    compileSdk = 37 // flutter_secure_storage / permission_handler gereksinimi
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hophop.hophop"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // APK'nın taşıdığı mimariler BURADA sabitlenir.
        //
        // NEDEN: `flutter build apk --target-platform android-arm64` yalnızca
        // FLUTTER'ın kendi kitaplıklarını (libflutter.so, libapp.so) kısıtlar;
        // eklentilerin .so dosyaları (webrtc, ML Kit, datastore…) yine her
        // mimari için pakete girer. Sonuçta APK "x86_64 destekliyorum" der ama
        // içinde x86_64 motoru yoktur. Android cihazın tercih ettiği ilk
        // mimariyi seçtiği için emülatörde (abilist: x86_64,arm64-v8a)
        // primaryCpuAbi=x86_64 seçilir ve uygulama açılışta çöker:
        //   dlopen failed: libflutter.so is for EM_AARCH64 instead of EM_X86_64
        // Aynı tuzak 32-bit (armeabi-v7a) telefonlarda da geçerliydi.
        //
        // Süzme paketleme adımında yapılıyor (aşağıdaki `packaging` bloğu);
        // defaultConfig.ndk.abiFilters bağımlılıklardan (AAR) gelen .so
        // dosyalarını süzmüyor — denendi, pakete yine giriyorlar.
    }

    // APK'ya YALNIZCA istenen mimarilerin kitaplıkları girsin.
    //
    // NEDEN GEREKLİ: `flutter build apk --target-platform android-arm64`
    // yalnızca FLUTTER'ın kitaplıklarını (libflutter.so, libapp.so) kısıtlıyor;
    // eklentilerin .so dosyaları (webrtc, ML Kit, datastore…) yine her mimari
    // için pakete giriyordu. Sonuçta APK "x86_64 destekliyorum" diyor ama içinde
    // x86_64 motoru yok. Android cihazın tercih ettiği İLK mimariyi seçtiği için
    // emülatörde (abilist: x86_64,arm64-v8a) primaryCpuAbi=x86_64 seçiliyor ve
    // uygulama açılışta çöküyordu:
    //   dlopen failed: libflutter.so is for EM_AARCH64 instead of EM_X86_64
    // Aynı tuzak 32-bit (armeabi-v7a) telefonlarda da geçerliydi. Yan fayda:
    //   ölü kitaplıklar çıkınca APK 87.5 MB → 49.2 MB.
    //
    // defaultConfig.ndk.abiFilters bunu YAPMIYOR (denendi) — bağımlılıklardan
    // (AAR) gelen .so dosyaları o süzgece takılmıyor, paketleme adımı gerekiyor.
    //
    // Süzgeç Flutter'ın verdiği -Ptarget-platform ile kendiliğinden hizalanır;
    // emülatör için x86_64 motorlu derleme almak yeterli:
    //   flutter build apk --debug --target-platform android-arm64,android-x64
    packaging {
        jniLibs {
            val abiOf = mapOf(
                "android-arm" to "armeabi-v7a",
                "android-arm64" to "arm64-v8a",
                "android-x64" to "x86_64",
            )
            val requested = (project.findProperty("target-platform") as String?)
                ?.split(",")
                ?.mapNotNull { abiOf[it.trim()] }
                ?: abiOf.values.toList()
            // target-platform verilmediyse (düz `flutter build apk`) hiçbir şey
            // süzülmez — Flutter zaten her mimariyi paketler.
            excludes += (abiOf.values + "x86")
                .filterNot { it in requested }
                .map { "lib/$it/**" }
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "\n⚠ android/key.properties yok → release APK DEBUG anahtarıyla " +
                    "imzalanıyor.\n  Aileye dağıtmadan önce: app/ dizininde " +
                    "./make-release-key.sh çalıştır (SETUP.md §4.5).\n")
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


dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
