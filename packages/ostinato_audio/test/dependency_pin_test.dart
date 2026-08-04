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
/// Direktifle MÜHÜRLENEN tek ref (M-F-263): `motion_core-v0.11.0` ve
/// `motion_camera-v0.1.2` AYRI commit'lerde durur ama pin TEKTİR — ikisini de
/// içeren `f13bdc9`. Doğrulandı: v0.11.0 -> 2018469, v0.1.2 -> f13bdc9, ve
/// f13bdc9 her ikisini de içeriyor (merge-base ataları).
const String _mandatedRef = 'f13bdc9';
const String _mandatedVersion = '0.11.0';

void main() {
  test('pin MÜHÜRLENEN refte — "ikisi aynı" yetmez, DOĞRU şeyde aynı olmalı', () {
    // ÜÇÜNCÜ ÇAPA (MUT-A dersi, O-029 sınıfı): eşitlik kapısı iki kaynağı
    // KARŞILAŞTIRIR; ikisini BİRLİKTE başka bir ref'e taşıyan bir düzenleme
    // sessizce geçer. Karşılaştırılacak bir DIŞ sabit olmadan "pin mühürlü"
    // cümlesi, pubspec'leri düzenleyen herkese açıktır.
    const Map<String, String> specs = {
      'ostinato_audio': 'pubspec.yaml',
      'dart_pilot': '../../tools/dart_pilot/pubspec.yaml',
    };
    for (final MapEntry<String, String> e in specs.entries) {
      final String yaml = File(e.value).readAsStringSync();
      expect(yaml, contains('ref: $_mandatedRef'),
          reason: '${e.key} pubspec.yaml mühürlenen refi ($_mandatedRef) '
              'taşımıyor — M-F-263 tek-pin şartı');
    }
    final String lock = File('pubspec.lock').readAsStringSync();
    expect(_resolvedVersion(lock), _mandatedVersion,
        reason: 'kilit $_mandatedVersion çözmüyor — tagin işaret ettiği sürüm '
            'ile refin çözdüğü sürüm ayrışmış olabilir');
  });

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

/// `<indent>motion_core:` bloğundaki `version:` değerini döner.
String? _resolvedVersion(String lockYaml) => _fieldOf(lockYaml, 'version');

/// `<indent>motion_core:` bloğundaki `resolved-ref:` değerini döner.
/// Blok, aynı girintide yeni bir üst-seviye anahtar görülünce biter.
String? _resolvedRef(String lockYaml) => _fieldOf(lockYaml, 'resolved-ref');

String? _fieldOf(String lockYaml, String field) {
  final List<String> lines = lockYaml.split('\n');
  int i = 0;
  while (i < lines.length && lines[i] != '  motion_core:') {
    i++;
  }
  if (i == lines.length) return null;
  for (int j = i + 1; j < lines.length; j++) {
    final String line = lines[j];
    if (RegExp(r'^  \S').hasMatch(line)) break; // yeni üst-seviye anahtar
    final Match? m = RegExp('^\\s*$field:\\s*"?([^"\\s]+)"?').firstMatch(line);
    if (m != null) return m.group(1);
  }
  return null;
}
