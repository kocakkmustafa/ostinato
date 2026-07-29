import 'dart:io';

import 'package:test/test.dart';

/// İKİ KİLİT DOSYASI, TEK PİN — JabLab'ın J-030 desenini uyarlar (M-F-82).
///
/// `packages/ostinato_audio/pubspec.yaml` ve `tools/dart_pilot/pubspec.yaml`
/// AYRI AYRI motion_core pinliyor. Bu turda GERÇEKTEN sürüklenmiş
/// bulundu: dart_pilot `0.8.2`'ye taşınırken ostinato_audio sessizce
/// `0.2.1`'de kalmıştı (dev_dependency olduğu ve doğrudan koşulmadığı için
/// hiçbir test bunu yakalamıyordu). Bu test o günü beklemeden kırar: iki
/// `pubspec.lock`'un `motion_core` için çözdüğü `resolved-ref` birebir
/// aynı olmalı.
void main() {
  test('ostinato_audio ve dart_pilot AYNI motion_core sürümünü çözüyor', () {
    final String? audioRef =
        _resolvedRef(File('pubspec.lock').readAsStringSync());
    final String? pilotRef = _resolvedRef(
        File('../../tools/dart_pilot/pubspec.lock').readAsStringSync());

    expect(audioRef, isNotNull,
        reason: 'pubspec.lock içinde motion_core.resolved-ref bulunamadı — '
            'önce `dart pub get` koştur');
    expect(pilotRef, isNotNull,
        reason: 'tools/dart_pilot/pubspec.lock içinde '
            'motion_core.resolved-ref bulunamadı — önce o klasörde de '
            '`dart pub get` koştur');
    expect(audioRef, pilotRef,
        reason: 'İKİ KİLİT DOSYASI FARKLI SÜRÜM ÇÖZÜYOR: ostinato_audio '
            '$audioRef, dart_pilot $pilotRef. Pin yükseltmesi her iki '
            'pubspec.yaml\'da da yapılmalı, sonra HER İKİ klasörde de '
            '`dart pub get` (M-F-82 / J-030 nüksü).');
  });
}

/// `<indent>motion_core:` bloğundaki `resolved-ref:` değerini döner.
/// Blok, aynı girintide yeni bir üst-seviye anahtar görülünce biter.
String? _resolvedRef(String lockYaml) {
  final List<String> lines = lockYaml.split('\n');
  int i = 0;
  while (i < lines.length && lines[i] != '  motion_core:') {
    i++;
  }
  if (i == lines.length) return null;
  for (int j = i + 1; j < lines.length; j++) {
    final String line = lines[j];
    if (RegExp(r'^  \S').hasMatch(line)) break; // yeni üst-seviye anahtar
    final Match? m = RegExp(r'^\s*resolved-ref:\s*(\S+)').firstMatch(line);
    if (m != null) return m.group(1);
  }
  return null;
}
