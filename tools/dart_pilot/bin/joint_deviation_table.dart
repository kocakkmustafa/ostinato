import 'dart:convert';
import 'dart:io';

import 'package:motion_core/motion_core.dart';

/// Koordinatör talimatı (M-F-96, M-O-45 yanıtı): gitarın 11-18° sapması
/// HANGİ eklemlerden geliyor? Kanonik `ReferenceBuilder._deviationsFromConsensus`
/// tam bunu ölçüyor ama sonucu eklem-medyanına sıkıştırıp tek sayı döndürüyor
/// (`build()`ın attığı `ReferenceAgreementError` de bu medyanı taşır). O metot
/// private — burada AYNI algoritma, aynı public parçalarla (circularStats,
/// wrapPi, radToDeg, Dtw.medianDtUs hepsi kanonik barrel'dan), yalnız
/// eklem-medyanına sıkıştırmadan, TABLO olarak tekrarlanıyor.
void main(List<String> args) {
  final want = args.isEmpty ? 'guitar' : args.first;
  final manifestFile =
      File('${Platform.environment['HOME']}/motion-harvest/ostinato/hold-windows-$want.json');
  final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final sources = (manifest['sources'] as List).cast<Map<String, dynamic>>();
  final lib = Directory('${Platform.environment['HOME']}/motion-harvest/ostinato/landmarks');

  const cli = ReferenceCli(specs: StandardJoints.upperBody);
  const builder = ReferenceBuilder();
  final takes = <ReferenceTake>[];

  for (final row in sources) {
    if (row['found'] != true) continue;
    final id = row['videoId'] as String;
    final f = File('${lib.path}/$id.full.json');
    final doc = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final fx = Fixture.fromJson(doc);
    final tStart = (row['tStartS'] as num).toDouble();
    final tEnd = (row['tEndS'] as num).toDouble();
    final windowFrames =
        fx.frames.where((pf) => pf.tSeconds >= tStart && pf.tSeconds < tEnd).toList();
    final windowed = Fixture(
      app: fx.app, technique: fx.technique, frames: windowFrames,
      schemaVersion: fx.schemaVersion, modelVersion: fx.modelVersion,
      recordingMeta: fx.recordingMeta, labels: fx.labels, provenance: fx.provenance,
    );
    final prepared = cli.prepareTake(id, windowed);
    if (prepared.take.frames.isEmpty) {
      stdout.writeln('  ⛔ $id: kanonik kapıdan 0 kare çıktı — atlandı');
      continue;
    }
    takes.add(prepared.take);
    stdout.writeln('  $id: ${prepared.take.frames.length} kare kanonik kapıdan geçti');
  }

  if (takes.length < 2) {
    stderr.writeln('en az 2 take gerekir, ${takes.length} var');
    exit(1);
  }

  // build()'ın attığı hata da bu ÇÖZÜLMÜŞ (mirror-resolved) take listesi
  // üzerinden hesaplanıyordu — aynı girdiyle başlıyoruz.
  final resolution = builder.resolveMirroring(takes);
  final resolved = resolution.takes;
  stdout.writeln('\nmirrorConfident=${resolution.confident} '
      'gapMeasured=${resolution.gapMeasured} flipped=${resolution.flippedIds}');

  final medoid = builder.selectMedoid(resolved);
  final base = resolved[medoid].frames;
  stdout.writeln('medoid: ${resolved[medoid].id}\n');

  final aligned = <List<JointAngleVector>>[
    for (var t = 0; t < resolved.length; t++)
      if (t == medoid)
        base
      else
        (() {
          final r = builder.dtw.align(
            base.length,
            resolved[t].frames.length,
            (i, j) => builder.similarity.distance(base[i], resolved[t].frames[j]),
            dtUs: Dtw.medianDtUs([for (final f in resolved[t].frames) f.tUs]),
          );
          return List<JointAngleVector>.generate(
              base.length, (i) => resolved[t].frames[r.refToLearner[i]]);
        })(),
  ];

  final jointSpecs = base.first.specs;
  stdout.writeln('=== eklem başına sapma (deg) — takes[t] vs leave-one-out konsensüs ===');
  stdout.write(''.padRight(20));
  for (final t in resolved) {
    stdout.write(t.id.padLeft(16));
  }
  stdout.writeln();

  final perTakeMedian = <String, List<double>>{for (final t in resolved) t.id: []};
  for (var j = 0; j < jointSpecs.length; j++) {
    final row = <String>[];
    for (var t = 0; t < resolved.length; t++) {
      double sum = 0;
      int n = 0;
      for (var f = 0; f < base.length; f++) {
        final others = <double>[
          for (var u = 0; u < resolved.length; u++)
            if (u != t) aligned[u][f][j],
        ];
        final stats = circularStats(others);
        final own = aligned[t][f][j];
        if (own.isNaN || stats.count == 0) continue;
        sum += wrapPi(own - stats.mean).abs();
        n++;
      }
      final degVal = n > 0 ? (sum / n) * radToDeg : double.nan;
      if (!degVal.isNaN) perTakeMedian[resolved[t].id]!.add(degVal);
      row.add(degVal.isNaN ? 'NaN'.padLeft(16) : degVal.toStringAsFixed(1).padLeft(16));
    }
    stdout.writeln('${jointSpecs[j].id.padRight(20)}${row.join()}');
  }

  stdout.writeln('\n=== doğrulama: eklem-medyanı (build()ın attığı hatayla eşleşmeli) ===');
  for (final t in resolved) {
    final vals = List<double>.from(perTakeMedian[t.id]!)..sort();
    final median = vals.isEmpty ? double.nan : vals[vals.length ~/ 2];
    stdout.writeln('  ${t.id}: ${median.toStringAsFixed(1)}°');
  }
}
