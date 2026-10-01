import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ANDROID RELEASE İMZASI — sessiz debug-imzası/sessiz-uyarı GERİ GELEMEZ
/// (O-103 → J-215 sertliği).
///
/// ## Neden bir kapı, neden Dart tarafında
///
/// `verifyReleaseSigning` (O-103, 2026-08-12) SESSİZ değildi ama YETERSİZDİ:
/// anahtar yoksa yalnız `logger.error` basıp release'i **debug anahtarıyla
/// üretmeye devam ediyordu**. Play böyle bir paketi REDDEDER; kusur ancak
/// yüklemede görünürdü — en pahalı yerde. jablab aynı sınıf kusuru
/// `J-215`'te SERT DURMAYA çevirdi (uyarı → `GradleException`); bu dosya
/// aynı sertliği ostinato'ya taşıyor ve **kaynak metni** denetler.
///
/// ⚠️ GÖREV ADI VE TELİ BİLEREK KORUNDU (jablab'ın `taskGraph.whenReady`
/// desenine tam geçilmedi): `tools/validate_release_signing.py`
/// (pre-commit'in kendi python kapısı) `verifyReleaseSigning` adını ve
/// `assembleRelease`/`bundleRelease`e BAĞLANTISINI METİN düzeyinde arıyor —
/// bu depo her-commit süitinde Gradle koşturmuyor, o yüzden görevin
/// VARLIĞI+BAĞLANTISI tek kanıt kanalı. Bu dosya o python kapısıyla AYNI
/// üç şeyi ölçer, farklı dilde: değişen yalnız gövde (throw, artık log
/// değil).
///
/// ⚠️ NE ÖLÇMÜYOR: Gradle'ın gerçekten durduğunu. O davranış gerçek bir
/// `--dry-run` koşumuyla ayrıca doğrulandı (bkz. workspace DEFTER); burada
/// denetlenen, o mekanizmanın **yerinde durduğu.** İkisi ayrı sorular ve
/// ikisi de gerekli.
void main() {
  final File gradle = File('android/app/build.gradle.kts');

  test('POZİTİF KONTROL — dosya okunuyor ve beklenen yapıyı taşıyor', () {
    // Bir "yok" bulgusu, aracın o şeyi BULABİLDİĞİ kanıtlanmadan
    // raporlanmaz. Dosya boş/yanlış yolda olsaydı aşağıdaki testler
    // vakum-doğru geçerdi.
    expect(gradle.existsSync(), isTrue, reason: 'build.gradle.kts bulunamadı');
    final String src = gradle.readAsStringSync();
    expect(
      src,
      contains('buildTypes'),
      reason:
          'dosya okundu ama Gradle yapısı yok — yol ya da içerik bozuk, '
          'aşağıdaki sonuçlar ANLAMSIZ olurdu',
    );
    expect(src, contains('release'), reason: 'release blok yok');
  });

  test('🔴 SESSİZ DEBUG İMZASI YOK — release, debug anahtarına düşmüyor', () {
    final List<String> offenders = <String>[
      for (final String line in gradle.readAsLinesSync())
        // Yorumlar serbest: kuralı ANLATAN satır kuralı ihlal etmez.
        if (!line.trimLeft().startsWith('//') &&
            RegExp(
              r'signingConfig\s*=\s*signingConfigs\.getByName\(\s*"debug"\s*\)',
            ).hasMatch(line))
          line.trim(),
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'release build type DEBUG anahtarıyla imzalanıyor — üretilen '
          'artefakt Play tarafından REDDEDİLİR ve bunu build ANINDA hiçbir '
          'şey söylemez (sessiz-hiçlik). Panzehir: key.properties yoksa '
          'release görevini GÜRÜLTÜLÜ durdur, debug\'a DÜŞME.',
    );
  });

  test(
    '🟡 SESSİZ UYARI-VE-DEVAM YOK — `verifyReleaseSigning` artık DURUYOR, yalnız LOGLAMIYOR',
    () {
      // O-103'ün kendi kusuru: anahtar yoksa `logger.error` BASIP release'i
      // yine üretmekti — görev ADI/TELİ kalsın (python kapısı bunu arıyor,
      // bkz. sınıf yorumu), ama GÖVDESİ bir daha "yalnız log" olmasın.
      final String src = gradle.readAsStringSync();
      final RegExpMatch? taskBody = RegExp(
        r'tasks\.register\("verifyReleaseSigning"\)\s*\{.*?\n\}',
        dotAll: true,
      ).firstMatch(src);
      expect(
        taskBody,
        isNotNull,
        reason:
            '`verifyReleaseSigning` görev tanımı bulunamadı — aşağıdaki '
            'testler onu ARADIĞI için önce bu doğru biçimde var olmalı',
      );
      final String body = taskBody!.group(0)!;
      expect(
        body,
        contains('throw GradleException'),
        reason:
            'görev gövdesi artık `throw GradleException` İÇERMİYOR — '
            'yalnız `logger.error` basıp devam etmek, reddedilecek '
            'artefaktı yine üretmek olurdu (O-103\'ün kendi kusuru)',
      );
    },
  );

  test(
    '🔒 GÜRÜLTÜLÜ DURMA MEKANİZMASI YERİNDE (+ `validate_release_signing.py` ile aynı üç kontrol)',
    () {
      final String src = gradle.readAsStringSync();
      // Üçü birden — `tools/validate_release_signing.py`nin kendi üç
      // değişmeziyle BİREBİR aynı: koşul · adıyla-uyaran görev · release
      // yoluna BAĞLANTI. Biri düşerse kusur sessizleşir.
      expect(
        src,
        contains('hasReleaseKeystore'),
        reason: 'anahtar-var-mı koşulu kaybolmuş',
      );
      expect(
        src,
        contains('tasks.register("verifyReleaseSigning")'),
        reason:
            'adıyla-uyaran görev kaydı kaybolmuş — '
            '`tools/validate_release_signing.py` da bunu metinde arıyor',
      );
      expect(
        src,
        contains('GradleException'),
        reason:
            'kapı artık build\'i DURDURMUYOR — uyarı basıp devam etmek, '
            'reddedilecek artefaktı yine üretmek olurdu',
      );
      expect(
        RegExp(
          r'\.configureEach\s*\{\s*dependsOn\(verifyReleaseSigning\)',
        ).hasMatch(src),
        isTrue,
        reason:
            'görev kaydı var ama release yoluna (assembleRelease/'
            'bundleRelease) BAĞLI değil — kaydın varlığı tetiğinin '
            'varlığı değildir (aynı ayrım validate_release_signing.py\'de)',
      );
    },
  );

  test(
    '🚪 CI KAÇIŞ KAPISI — `allowDebugSigning` ailenin dördüncü kez doğrulanmış deseniyle var',
    () {
      // Köken: Gravita G-192 → Lissom bayrağıyla birleşti → jablab JAB-P0-004 →
      // choreia CHO-P0-002 → burada ostinato'ya taşındı. motion-core
      // consumer-matrix'inin `android_release` adımı HER app'te AYNI komutu
      // (`-PallowDebugSigning=true`) koşuyor — bu bayrak yoksa bu adım CI'da
      // (gerçek keystore YOK ve OLMAMALI) SESSİZCE değil ama YİNE DE geçemezdi.
      final String src = gradle.readAsStringSync();
      expect(
        src,
        contains('allowDebugSigning'),
        reason:
            'CI kaçış bayrağı yok — consumer-matrix\'in android_release '
            'adımı (-PallowDebugSigning=true) gerçek keystore olmadan '
            'geçemez, ve gerçek keystore CI\'da OLMAMALI (sır, kurucuda)',
      );
      expect(
        src,
        contains('findProperty("allowDebugSigning")'),
        reason:
            'bayrak okunmuyor — jablab/choreia\'nın `findProperty(...) '
            '== "true"` deseniyle AYNI olmalı (yalnız AÇIKÇA "true" '
            'verildiğinde devreye girsin, salt varlık değil)',
      );
      // Bayrak VERİLDİĞİNDE durdurucu SUSMALI (yalnız uyarmalı) — aksi hâlde
      // kaçış kapısı hiç var olmamış demektir (jablab'ın kendi ölçtüğü tuzak).
      final RegExpMatch? taskBody = RegExp(
        r'tasks\.register\("verifyReleaseSigning"\)\s*\{.*?\n\}',
        dotAll: true,
      ).firstMatch(src);
      expect(taskBody, isNotNull);
      expect(
        taskBody!.group(0)!,
        contains('allowDebugSigning'),
        reason:
            'görev gövdesi bayrağı hiç KONTROL ETMİYOR — bayrak '
            'verilse bile hâlâ throw ederdi, kaçış kapısı susmaz',
      );
    },
  );

  test(
    '🐍 PYTHON KAPISI DA TEMİZ — `tools/validate_release_signing.py` bu dosyayla AYNI hükmü veriyor',
    () {
      // İki bağımsız denetçi (bu Dart testi + reponun kendi python kapısı)
      // AYNI dosyayı okuyup AYNI sonuca varmalı — biri yeşil biri kırmızıysa
      // ikisinden biri yanlış ölçüyordur.
      final ProcessResult result = Process.runSync('python3', <String>[
        'tools/validate_release_signing.py',
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'validate_release_signing.py KIRMIZI:\n${result.stdout}',
      );
    },
  );

  test('⛔ SIR DEPOYA GİREMEZ — key.properties ve keystore git-dışı', () {
    // Kapının yan etkisi: kurucu bir keystore ürettiğinde onu yanlışlıkla
    // commit etmek MÜMKÜN OLMAMALI.
    final String ignore = File('android/.gitignore').readAsStringSync();
    for (final String pat in <String>[
      'key.properties',
      '*.keystore',
      '*.jks',
    ]) {
      expect(
        ignore,
        contains(pat),
        reason: '$pat .gitignore\'da değil — imza sırrı depoya sızabilir',
      );
    }
    // Yerel imzalama için dosya bulunabilir; güvenlik sınırı Git'e
    // eklenmemesidir. Dosyanın içeriğini hiçbir zaman okumuyoruz.
    final ProcessResult tracked = Process.runSync('git', <String>[
      'ls-files',
      '--error-unmatch',
      'android/key.properties',
    ]);
    expect(
      tracked.exitCode,
      isNot(0),
      reason:
          'key.properties Git tarafından izleniyor — imza sırrı '
          'depoya girebilir',
    );
  });
}
