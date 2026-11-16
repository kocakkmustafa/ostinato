import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ANDROID'DE KAMERA İZNİ YOK. Kamera özellik bayrakları kapalı; Android
/// kamera izni ve zorunlu kamera özelliği bildirmez. iOS'ta kamera eklentileri
/// bağlı kaldığı için NSCameraUsageDescription DURUR (ayrı bilet
/// OST-CAM-IOS-01); bayraklar kapalıyken istenmez. Mikrofon izni yerinde.
///
/// Android'de kamera eklentileri (camera_android_camerax, motion_camera,
/// ostinato_posture) kendi manifestlerinde CAMERA iznini ve camera özelliğini
/// getirir; birleşik manifest bunları geri sokar. Bu yüzden KAYNAK manifestte
/// `tools:node="remove"` direktifi şarttır; düz `uses-permission` olarak CAMERA
/// geçemez. Bayrak açılırken izinler yeniden eklenmeli (bkz.
/// docs/yula-execution/design/camera-izni-kaldirma-notu.md).
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  // Yorumları at: yalnız gerçek öğeler sayılır.
  final xml = manifest.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final elements = RegExp(
    r'<uses-(?:permission|feature)\b[^>]*?(?:/>|>\s*</uses-(?:permission|feature)\s*>)',
    dotAll: true,
  ).allMatches(xml).map((m) => m.group(0)!).toList();

  bool names(String e, String name) =>
      RegExp('android:name="${RegExp.escape(name)}"').hasMatch(e);
  bool removes(String e) => e.contains('tools:node="remove"');

  group('Android kaynak manifesti', () {
    test('CAMERA yalnız tools:node="remove" ile geçer', () {
      final camera = elements
          .where((e) => names(e, 'android.permission.CAMERA'))
          .toList();
      expect(
        camera,
        isNotEmpty,
        reason: 'remove direktifi şart: eklenti CAMERA getirmesin',
      );
      for (final e in camera) {
        expect(
          removes(e),
          isTrue,
          reason: 'CAMERA düz uses-permission olamaz: $e',
        );
      }
    });

    test('camera.any / autofocus zorunlu değil', () {
      final features = elements
          .where(
            (e) =>
                e.startsWith('<uses-feature') &&
                RegExp(
                  r'android:name="android\.hardware\.camera[^"]*"',
                ).hasMatch(e),
          )
          .toList();
      expect(
        features.where((e) => e.contains('android.hardware.camera.any')),
        isNotEmpty,
        reason: 'camera.any satırı kaynak manifestte durmalı',
      );
      for (final e in features) {
        final optional = removes(e) || e.contains('android:required="false"');
        expect(optional, isTrue, reason: 'kamera özelliği zorunlu: $e');
      }
    });

    test('mikrofon izni (RECORD_AUDIO) yerinde', () {
      final audio = elements
          .where((e) => names(e, 'android.permission.RECORD_AUDIO'))
          .toList();
      expect(audio, hasLength(1));
      expect(removes(audio.single), isFalse);
    });
  });

  group('Birleşik release manifesti (varsa)', () {
    // `./gradlew :app:processReleaseMainManifest` çıktısı; yoksa atlanır.
    // Kanıt betiği: tools/verify_merged_manifest_no_camera.py.
    final merged = File(
      'build/app/intermediates/merged_manifest/release/'
      'processReleaseMainManifest/AndroidManifest.xml',
    );
    test('CAMERA yok, zorunlu kamera özelliği yok', () {
      final x = merged.readAsStringSync().replaceAll(
        RegExp(r'<!--.*?-->', dotAll: true),
        '',
      );
      expect(x, isNot(contains('android.permission.CAMERA')));
      for (final m in RegExp(
        r'<uses-feature\b[^>]*android\.hardware\.camera[^>]*>',
        dotAll: true,
      ).allMatches(x)) {
        expect(m.group(0), contains('android:required="false"'));
      }
    }, skip: merged.existsSync() ? false : 'birleşik manifest üretilmemiş');
  });

  group('iOS', () {
    // iOS'ta kamera eklentileri bağlı: açıklama metni DURUR, kamera
    // bayrakları kapalıyken istenmez.
    final retention = RegExp(
      r'\b(keeps?|kept|retain|stores?|stored)\b',
      caseSensitive: false,
    );

    test('Info.plist: kamera açıklaması VAR ve dürüst, mikrofon var', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final m = RegExp(
        r'<key>NSCameraUsageDescription</key>\s*<string>([^<]+)</string>',
      ).firstMatch(plist);
      expect(m, isNotNull);
      expect(m!.group(1)!.trim(), isNotEmpty);
      expect(
        retention.hasMatch(m.group(1)!),
        isFalse,
        reason: 'saklama iddiası yok',
      );
      expect(plist, contains('NSMicrophoneUsageDescription'));
    });

    test('InfoPlist.strings (14 dil): kamera + mikrofon satırı var', () {
      final files = Directory('ios/Runner')
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.endsWith('.lproj'))
          .map((d) => File('${d.path}/InfoPlist.strings'))
          .where((f) => f.existsSync())
          .toList();
      expect(files.length, greaterThanOrEqualTo(14));
      for (final f in files) {
        final s = f.readAsStringSync();
        expect(
          RegExp(r'"NSCameraUsageDescription"\s*=\s*"[^"]+";').hasMatch(s),
          isTrue,
          reason: f.path,
        );
        expect(s, contains('"NSMicrophoneUsageDescription"'), reason: f.path);
      }
    });
  });
}
