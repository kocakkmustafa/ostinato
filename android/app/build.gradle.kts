import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ⑤a — İMZA YAPILANDIRMASI (O-103, yayın engeli denetimi kalemi 5).
//
// ÖLÇÜLDÜ (2026-08-12, artefakttan): bu blok şablonun TODO'suyla duruyordu ve
// `assembleRelease` gerçekten koştuğunda üretilen APK'nın imzası
// `C=US, O=Android, CN=Android Debug` çıkıyordu — yani release yapısı
// SESSİZCE debug anahtarıyla imzalanıyordu. Mağaza böyle bir paketi reddeder;
// daha kötüsü, kusur bir hata mesajı üretmiyor.
//
// Desen LifeOS'tan ADAPTE edildi (icat değil): `key.properties` varsa gerçek
// imza, yoksa debug'a düşer. Geri-düşme KALDIRILAMAZ — kaldırılırsa taze
// klonda ve CI'da `--debug` yapıları bile yapılandırma anında patlar (LifeOS
// bunu ölçmüş). Ama geri-düşme SESSİZ olamaz: `verifyReleaseSigning` görevi
// release yolunda çalışır ve düşüşü ADIYLA söyler.
//
// SINIR: keystore'un KENDİSİ kurucudadır (sır). Bu blok onu beklemez —
// hat-yereli iş, kurucu kaleminin altına saklanmadan bugün kapanır.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "com.yulalab.ostinato"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yulalab.ostinato"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            isDebuggable = false
            isJniDebuggable = false
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Geri-düşme KASITLI (LifeOS ölçümü): kaldırılırsa taze klonda
                // ve CI'da debug yapıları bile yapılandırma anında patlar.
                // Ama SESSİZ değil — `verifyReleaseSigning` aşağıda öter.
                signingConfigs.getByName("debug")
            }
        }
    }
}

// ⑤a KAPISI — sessiz düşmeyi ADIYLA söyleyen görev.
//
// Neden bir görev, neden yapılandırma-anı `throw` değil: yapılandırma anında
// fırlatmak `--debug` yapılarını da kırar (LifeOS'un ölçtüğü tuzak). Bu görev
// YALNIZ release paketleme yolunda çalışır ve o yolda kusur ADIYLA görünür.
//
// ⛔ Kapı, keystore'un VARLIĞINI şart koşmaz (o kurucuda) — SESSİZLİĞİ
// yasaklar. Kurucu keystore'u verdiği an kapı kendiliğinden susar.
val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    doLast {
        if (!hasReleaseKeystore) {
            logger.error(
                "\n⛔ RELEASE İMZASI: `android/key.properties` YOK → bu paket " +
                "DEBUG anahtarıyla imzalanıyor (CN=Android Debug).\n" +
                "   Mağaza böyle bir paketi REDDEDER. Ölçüldü 2026-08-12: " +
                "üretilen APK'nın imzası gerçekten debug sertifikasıydı.\n" +
                "   Bu bir yapılandırma kusuru DEĞİL: yapılandırma hazır, " +
                "eksik olan KEYSTORE (kurucu kalemi).\n" +
                "   Gerekli: keyAlias · keyPassword · storeFile · storePassword\n"
            )
        } else {
            logger.lifecycle("✅ RELEASE İMZASI: key.properties bulundu, " +
                "release yapılandırması kullanılıyor.")
        }
    }
}

tasks.matching { it.name == "assembleRelease" || it.name == "bundleRelease" }
    .configureEach { dependsOn(verifyReleaseSigning) }

flutter {
    source = "../.."
}
