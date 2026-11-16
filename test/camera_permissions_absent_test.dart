import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// KAMERA İZNİ YOK (1.0.3 öncesi kaldırma). Kamera özellik bayrakları kapalı;
/// uygulama hiçbir platformda kamera izni ya da zorunlu kamera özelliği
/// bildirmez. Mikrofon izni (ses dinleme) yerinde kalır.
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
    r'<uses-(?:permission|feature)\b[^>]*?/>',
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

  group('iOS', () {
    test('Info.plist: kamera anahtarı yok, mikrofon var', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, isNot(contains('NSCameraUsageDescription')));
      expect(plist, contains('NSMicrophoneUsageDescription'));
    });

    test('InfoPlist.strings (14 dil): kamera satırı yok, mikrofon var', () {
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
        expect(s, isNot(contains('NSCameraUsageDescription')), reason: f.path);
        expect(s, contains('"NSMicrophoneUsageDescription"'), reason: f.path);
      }
    });
  });
}
