import 'dart:io';
import 'dart:convert';

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
/// Onaylanan tek ref (M-F-263): hesap/üyelik çekirdeğini de içeren
/// `f2ea161c`. Tüm tüketiciler aynı tam ref'i kullanır.
///
/// **REF TAM 40-SHA OLMAK ZORUNDA** (M-F-263 zeyil-2, Choreia+Gravita ölçtü —
/// ve burada da ÖLÇÜLDÜ): pub, git ref'lerini ÇÖZMEZ, STRING olarak
/// karşılaştırır.  kendi pubspec'inde tam SHA ile pinliyor;
/// bizimki kısaltılmışken pub ikisini AYRI KAYNAK sayıp
/// "motion_camera from git is incompatible with ostinato_posture from path"
/// diyor. Kısaltılmış ref TEK BAŞINA çözülür — arıza ancak İKİ TARAFIN
/// anlaşması gerektiğinde görünür. (Pin testinin kendi dersiyle aynı sınıf:
/// anlaşma, ancak iki taraf varken sınanabilir.)
const String _mandatedRef = '0fed3a05466946bf2710750f4feca8dbd75be123';
const String _mandatedVersion = '0.12.0';

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
    expect(_resolvedVersion(lock), _localCoreOverride() ? '0.12.0' : _mandatedVersion,
        reason: 'kilit $_mandatedVersion çözmüyor — tagin işaret ettiği sürüm '
            'ile refin çözdüğü sürüm ayrışmış olabilir');
  });

  test('ostinato_audio ve dart_pilot AYNI motion_core sürümünü çözüyor', () {
    if (_localCoreOverride()) {
      _expectExactLocalCore('pubspec.lock', '.dart_tool/package_config.json');
      _expectExactLocalCore('../../tools/dart_pilot/pubspec.lock',
          '../../tools/dart_pilot/.dart_tool/package_config.json');
      return;
    }
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

/// A local run is explicit and bounded to this lane's sibling Core candidate.
/// Canonical Git descriptors above remain unchanged and checked in either mode.
bool _localCoreOverride() {
  const roots = ['.', '../../tools/dart_pilot'];
  final declared = roots.map((root) {
    final override = File('$root/pubspec_overrides.yaml');
    return override.existsSync() &&
        RegExp(r'^  motion_core:', multiLine: true)
            .hasMatch(override.readAsStringSync());
  }).toList();
  if (!declared.any((value) => value)) return false;
  expect(declared, everyElement(isTrue),
      reason: 'Both independent packages must explicitly override Core');
  final expected = Directory('../../../motion-core/packages/motion_core')
      .resolveSymbolicLinksSync();
  for (final root in roots) {
    final yaml = File('$root/pubspec_overrides.yaml').readAsStringSync();
    final block = RegExp(r'^  motion_core:\s*\n    path: ([^\n]+)',
        multiLine: true).firstMatch(yaml);
    expect(block, isNotNull, reason: 'Core override must be an explicit path');
    final path = block!.group(1)!.trim().replaceAll('"', '').replaceAll("'", '');
    final actual = Directory.fromUri(Directory(root).absolute.uri.resolve(path))
        .resolveSymbolicLinksSync();
    expect(actual, expected, reason: 'Only exact sibling Core candidate allowed');
  }
  return true;
}

void _expectExactLocalCore(String lockPath, String configPath) {
  final lock = File(lockPath).readAsStringSync();
  expect(_fieldOf(lock, 'source'), 'path');
  expect(_resolvedVersion(lock), '0.12.0');
  final config = File(configPath).absolute;
  final document = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  final packages = document['packages'] as List<dynamic>;
  final core = packages.cast<Map<String, dynamic>>()
      .singleWhere((entry) => entry['name'] == 'motion_core');
  final actual = Directory.fromUri(config.uri.resolve(core['rootUri'] as String))
      .resolveSymbolicLinksSync();
  final expected = Directory('../../../motion-core/packages/motion_core')
      .resolveSymbolicLinksSync();
  expect(actual, expected, reason: 'Resolved config must use exact Core source');
  expect(File('$actual/pubspec.yaml').readAsStringSync(),
      contains('version: 0.12.0'));
}
