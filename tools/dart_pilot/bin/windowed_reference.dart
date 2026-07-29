import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

/// Koordinatör talimatı — ARA ADIM 1b (M-O-40 yanıtı, DEFTER M-F-75).
///
/// M-O-40 iki olası sebep buldu: (a) az kaynak, (b) take birimi tam-video
/// olduğu için posture anı dersin geri kalanıyla sulanıyor. Koordinatör
/// kararı: (a)'ya (hedefli hasat) rig-sınıfı bir izolatör gelmeden
/// BAŞLANMAZ — o koordinatör işi. Bu araç (b)'yi ayıklamak için `pilot.dart`ın
/// "en durağan 90 kare" sezgisiyle fixture'ları KESER — sezgiselin kendisi
/// sorun DEĞİLDİ, BEYANSIZLIĞI sorundu (M-O-31 dersiyle aynı sınıf: "üretici
/// yoksa iddia dilek olur"). Burada üretici VAR ve beyanı KONSOLDA açık:
/// `windowRule: heuristic-mostStatic90, PROVISIONAL`.
///
/// Soru: sulanma gidince posture pencereleri ANLAŞIYOR MU?
///  - Anlaşıyorsa → eksik olan yalnız rig-sınıfı izolasyon, hasat gerekmez.
///  - Anlaşmıyorsa (hâlâ 15-60°) → anlaşmazlık GERÇEK, (a)/(b) kararı gerçek
///    sayılarla verilir.
/// Sayılar HER İKİ durumda da PROVISIONAL (pencere sezgisel, rig-onaylı değil).
void main(List<String> args) async {
  final want = args.isEmpty ? null : args.first;
  if (want == null) {
    stderr.writeln('kullanım: dart run bin/windowed_reference.dart <voice|guitar|piano>');
    exit(64);
  }

  final lib = Directory('${Platform.environment['HOME']}/motion-harvest/ostinato/landmarks');
  final instFile = File('${Directory.current.path}/../../config/fixture-instrument-map.json');
  final instMap = (jsonDecode(instFile.readAsStringSync()) as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, v as String));

  final files = lib.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final rawFixturesById = <String, Fixture>{};
  for (final f in files) {
    final id = f.uri.pathSegments.last.split('.').first;
    if (instMap[id] != want) continue;
    rawFixturesById[id] = Fixture.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
  }

  stdout.writeln('ÇALGI: $want — kaynak havuzu: ${rawFixturesById.length}');
  stdout.writeln('windowRule: heuristic-mostStatic90, PROVISIONAL '
      '(pilot.dart sezgisi — 90 karelik en az hareketli açı-uzayı penceresi; '
      'rig-onaylı izolasyon DEĞİL)\n');

  const extractor = JointAngleExtractor(specs: StandardJoints.upperBody);
  final normalizer = PoseNormalizer();
  final windowedFixturesById = <String, Fixture>{};

  for (final entry in rawFixturesById.entries) {
    final id = entry.key;
    final fx = entry.value;
    final elig = ReferenceCli.eligibilityOf(fx);
    final size = fx.recordingMeta.frameSize;
    final frames = fx.frames;

    if (frames.length <= 90) {
      windowedFixturesById[id] = fx;
      stdout.writeln('  $id  frames=${frames.length} eligible=$elig  '
          '(90 kareden kısa/eşit — pencere uygulanmadı, olduğu gibi)');
      continue;
    }

    // pilot.dart ile AYNI arama: isotropic-düzeltilmiş açı-vektörleri
    // üzerinde 90 karelik (≈3sn), adım-30 taramayla en az hareketli pencere.
    final vectors = <JointAngleVector>[];
    for (var frame in frames) {
      if (size != null) frame = frame.toIsotropic(size);
      vectors.add(extractor.extract(normalizer.normalize(frame)));
    }
    var bestStart = 0;
    var bestMotion = double.infinity;
    for (var s = 0; s + 90 <= vectors.length; s += 30) {
      var motion = 0.0;
      for (var i = s + 1; i < s + 90; i++) {
        for (var j = 0; j < vectors[i].values.length; j++) {
          final a = vectors[i].values[j], b = vectors[i - 1].values[j];
          if (a.isNaN || b.isNaN) continue;
          motion += (a - b).abs();
        }
      }
      if (motion < bestMotion) {
        bestMotion = motion;
        bestStart = s;
      }
    }

    final windowFrames = frames.sublist(bestStart, bestStart + 90);
    final tStart = windowFrames.first.tSeconds;
    final tEnd = windowFrames.last.tSeconds;
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
    stdout.writeln('  $id  frames=${frames.length}→90 eligible=$elig  '
        'pencere=[${tStart.toStringAsFixed(1)}s-${tEnd.toStringAsFixed(1)}s] '
        '(video ${(frames.last.tSeconds).toStringAsFixed(0)}s uzunluğunda)');
  }

  const cli = ReferenceCli(specs: StandardJoints.upperBody);

  stdout.writeln('\n=== periyot ölçümü (uygun kaynaklar, PENCERELİ — notApplied beklenir: madde 3) ===');
  const periodEstimator = CyclePeriodEstimator();
  for (final e in windowedFixturesById.entries) {
    if (ReferenceCli.eligibilityOf(e.value) != TakeEligibility.attested) continue;
    final prepared = cli.prepareTake(e.key, e.value);
    final p = periodEstimator.estimate(prepared.take.frames);
    stdout.writeln('  ${e.key}: measured=${p.measured} '
        '${p.measured ? "periodFrames=${p.periodFrames} periodicity=${p.periodicity.toStringAsFixed(3)}" : "reason=${p.reason}"}');
  }

  Map<String, dynamic> artifact;
  try {
    artifact = cli.buildArtifact(technique: want, fixturesById: windowedFixturesById);
  } on ArgumentError catch (e) {
    stdout.writeln('\n⛔ buildArtifact REDDETTİ (havuz kapı-altı):\n   $e');
    exit(2);
  } on ReferenceAgreementError catch (e) {
    stdout.writeln('\n⛔ buildArtifact REDDETTİ (M-F-47 anlaşma kapısı — SULANMA GİDİNCE DE ANLAŞMIYOR):');
    stdout.writeln('   $e');
    exit(2);
  }

  stdout.writeln('\n✅ buildArtifact KABUL ETTİ (sulanma giderilince ANLAŞTI) — sayılar yine de PROVISIONAL:');
  final result = artifact['result'] as Map<String, dynamic>;
  stdout.writeln('  measurementProvenance : ${artifact['measurementProvenance']} (+ windowRule: heuristic-mostStatic90)');
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
