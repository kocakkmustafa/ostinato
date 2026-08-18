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
// ⚠️ GÜNCELLEME (motion-core consumer-matrix taraması, 2026-08-19): bu blok
// "geri-düşme KALDIRILAMAZ — kaldırılırsa debug yapıları bile yapılandırma
// anında patlar" diyordu, ama bu ÖLÇÜLMEMİŞ bir varsayımdı (LifeOS'un kendi
// deseninden miras). jablab aynı sınıf kusuru `J-215`'te SERT DURMAYA çevirdi
// ve KENDİ `--dry-run` ölçümüyle kanıtladı: `signingConfig = null` release'in
// debug yapılarını KIRMIYOR (yalnız release görev grafiği etkileniyor). Desen
// artık buraya da taşındı: geri-düşme YOK, kapı SESSİZ değil.
//
// `verifyReleaseSigning` GÖREV ADI ve `assembleRelease`/`bundleRelease`e
// BAĞLANTISI BİLEREK KORUNDU (jablab'ın `taskGraph.whenReady` desenine tam
// geçilmedi): `tools/validate_release_signing.py` bu ikisini METİN
// düzeyinde arıyor — bu deponun her-commit süiti Gradle koşturmuyor, o
// yüzden görevin VARLIĞI ve BAĞLANTISI (kaydın kendisi değil, adı+teli) tek
// kanıt kanalı. Değişen yalnız görevin gövdesi: `logger.error` (log basıp
// devam) yerine `GradleException` (durur).
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
        // Yalnız gerçek anahtar VARSA tanımlanır. Boş/yer-tutucu bir release
        // config tanımlamak, olmayan bir imzayı VARMIŞ gibi gösterirdi.
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            isDebuggable = false
            isJniDebuggable = false
            // ⚠️ `null` BİLEREK (J-215 deseni): debug'a artık DÜŞMÜYORUZ.
            // Anahtar yoksa imza YOK, ve aşağıdaki kapı release görev
            // grafiğini zaten başlatmıyor.
            signingConfig = if (hasReleaseKeystore) signingConfigs.getByName("release") else null
        }
    }
}

// ⑤a KAPISI — sessiz düşmeyi ADIYLA söyleyen görev (O-103 → J-215 sertliği).
//
// Neden bir görev, neden yapılandırma-anı `throw` değil: yapılandırma anında
// fırlatmak `--debug` yapılarını da kırardı. Bu görev YALNIZ release
// paketleme yolunda çalışır ve o yolda kusur ADIYLA görünür.
//
// ⛔ Kapı, keystore'un VARLIĞINI şart koşmaz (o kurucuda) — SESSİZLİĞİ
// yasaklar. Kurucu keystore'u verdiği an kapı kendiliğinden susar.
val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    doLast {
        if (!hasReleaseKeystore) {
            throw GradleException(
                "\n⛔ RELEASE İMZASI: `android/key.properties` YOK → bu paket " +
                "imzasız kalır (signingConfig artık null — debug'a DÜŞMÜYOR).\n" +
                "   Mağaza imzasız/yanlış-imzalı bir paketi REDDEDER. Ölçüldü " +
                "2026-08-12: önceki (debug'a düşen) sürümün ürettiği APK'nın " +
                "imzası gerçekten `CN=Android Debug` çıkmıştı.\n" +
                "   Bu bir yapılandırma kusuru DEĞİL: yapılandırma hazır, " +
                "eksik olan KEYSTORE (kurucu kalemi, ~/.secrets/yula/).\n" +
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
