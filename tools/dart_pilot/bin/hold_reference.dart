import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

/// M-F-75 ARA ADIM 1b-v2 (koordinatör): sezgisel pencere yerine
/// `hold_isolator@4ad1e2c` çıktısını (`tools/find_hold_windows.py`nin
/// yazdığı `~/motion-harvest/ostinato/hold-windows-<çalgı>.json`) kullanır.
/// windowRule artık gerçekten beyanlı: `hold_isolator@4ad1e2c, maxDrift=X`.
/// Pencere BULUNAMAYAN kaynak isimle dışlanır (sessiz atlama yok).
void main(List<String> args) async {
  final want = args.isEmpty ? null : args.first;
  if (want == null) {
    stderr.writeln('kullanım: dart run bin/hold_reference.dart <voice|guitar|piano>');
    exit(64);
  }

  final manifestFile =
      File('${Platform.environment['HOME']}/motion-harvest/ostinato/hold-windows-$want.json');
  if (!manifestFile.existsSync()) {
    stderr.writeln('⛔ manifest yok: ${manifestFile.path} — önce '
        'python tools/find_hold_windows.py $want koştur');
    exit(66);
  }
  final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final sources = (manifest['sources'] as List).cast<Map<String, dynamic>>();

  final lib = Directory('${Platform.environment['HOME']}/motion-harvest/ostinato/landmarks');
  stdout.writeln('ÇALGI: $want — hold_isolator manifest kaynak sayısı: ${sources.length}');
  stdout.writeln('windowRule: hold_isolator@4ad1e2c, defaultMaxDrift=${manifest['defaultMaxDrift']} '
      'fallbackMaxDrift=${manifest['fallbackMaxDrift']}\n');

  final windowedFixturesById = <String, Fixture>{};
  final notFound = <String>[];

  for (final row in sources) {
    final id = row['videoId'] as String;
    if (row['found'] != true) {
      notFound.add(id);
      stdout.writeln('  $id  ⛔ pencere BULUNAMADI (hold_isolator ${manifest['fallbackMaxDrift']} '
          'geri-çekilmesinde bile) — dışlandı');
      continue;
    }
    final f = File('${lib.path}/$id.full.json');
    final doc = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final fx = Fixture.fromJson(doc);
    // Python'un start_frame/end_frame'i HAM (undetected dahil) kare
    // indeksi; Dart'ın Fixture.frames'i yalnız TESPİT EDİLMİŞ kareleri
    // (gap'siz) tutuyor — ikisi birebir eşleşmez. SÜRE ortak koordinat
    // (M-O-23/27): Python fps'ten tStartS/tEndS türetti, burada Dart
    // frame'leri tSeconds'a göre seçilir, indekse göre DEĞİL.
    final tStart = (row['tStartS'] as num).toDouble();
    final tEnd = (row['tEndS'] as num).toDouble();
    final windowFrames =
        fx.frames.where((pf) => pf.tSeconds >= tStart && pf.tSeconds < tEnd).toList();
    if (windowFrames.isEmpty) {
      stdout.writeln('  $id  ⛔ [${tStart.toStringAsFixed(1)}s-${tEnd.toStringAsFixed(1)}s] '
          'aralığında TESPİT EDİLMİŞ kare yok — dışlandı');
      notFound.add(id);
      continue;
    }
    windowedFixturesById[id] = Fixture(
      app: fx.app,
      technique: fx.technique,
      frames: windowFrames,
      schemaVersion: fx.schemaVersion,
      modelVersion: fx.modelVersion,
      recordingMeta: fx.recordingMeta,
      labels: fx.labels,
      provenance: fx.provenance,
    );
    stdout.writeln('  $id  [${tStart.toStringAsFixed(1)}s-${tEnd.toStringAsFixed(1)}s] '
        '→ ${windowFrames.length} tespit edilmiş kare (${row['seconds']}s beyan edilen) '
        'drift=${row['drift']} (maxDrift=${row['maxDriftUsed']}) '
        'enerji/s=${row['energyPerS']} adayIsabet=${row['candidateHit']}');
  }

  const cli = ReferenceCli(specs: StandardJoints.upperBody);
  if (windowedFixturesById.length < 3) {
    stdout.writeln('\n⛔ hold-pencereli havuz ${windowedFixturesById.length} < 3 (minTakes) — '
        'kanonik CLI DENENMEDİ (kapı-altı, gerekçesi zaten manifestte)');
    exit(2);
  }

  Map<String, dynamic> artifact;
  try {
    artifact = cli.buildArtifact(technique: want, fixturesById: windowedFixturesById);
  } on ArgumentError catch (e) {
    stdout.writeln('\n⛔ buildArtifact REDDETTİ (havuz kapı-altı):\n   $e');
    exit(2);
  } on ReferenceAgreementError catch (e) {
    stdout.writeln('\n⛔ buildArtifact REDDETTİ (M-F-47 anlaşma kapısı — HOLD PENCERELERİ DE ANLAŞMIYOR):');
    stdout.writeln('   $e');
    exit(2);
  }

  stdout.writeln('\n✅ buildArtifact KABUL ETTİ (hold pencereleri ANLAŞTI) — sayılar PROVISIONAL '
      '(rig-onaylı ama eşikler PROVISIONAL, coordinator kalibrasyonu sürüyor):');
  final result = artifact['result'] as Map<String, dynamic>;
  stdout.writeln('  measurementProvenance : ${artifact['measurementProvenance']}');
  stdout.writeln('  contributingTakes     : ${result['contributingTakes']}');
  stdout.writeln('  distinctSources       : ${result['distinctSources']}');
  stdout.writeln('  mirrorConfident       : ${result['mirrorConfident']} (gapMeasured: ${result['mirrorGapMeasured']})');
  stdout.writeln('  unreliableJoints      : ${result['unreliableJoints']}');
  stdout.writeln('  meanAgreement         : ${result['meanAgreement']}');

  stdout.writeln('\n=== eklem başına dispersiyon (deg, medyan) ===');
  final joints = artifact['joints'] as List;
  final dispersionRad = artifact['frames']['dispersionRad'] as List;
  for (var j = 0; j < joints.length; j++) {
    final vals = <double>[];
    for (final frame in dispersionRad) {
      final v = (frame as List)[j] as double;
      if (!v.isNaN) vals.add(v * 180 / math.pi);
    }
    if (vals.isEmpty) continue;
    vals.sort();
    stdout.writeln('  ${(joints[j] as String).padRight(20)} '
        'medyan ${vals[vals.length ~/ 2].toStringAsFixed(1)}°  (n=${vals.length} kare)');
  }
}
