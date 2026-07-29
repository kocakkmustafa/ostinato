import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

/// Koordinatör talimatı (M-O-39 yanıtı, DEFTER M-F-70): ölçüm hijyeni önce.
///
/// `pilot.dart` kendi hesabına ("en durağan 90 kare"yi arayıp, kendi
/// `resolveMirroring`/`build` çağrısını yapıyordu) — tam da M-O-39'da
/// yakaladığım desenin bir başka örneği: kanonik fonksiyon DIŞINDA bir kopya.
/// Bu araç pilot'un YERİNE `ReferenceCli.buildArtifact` çağırır — filtreleme,
/// cycle-segmentation (0.8.0/L-139), agreement gate hepsi TEK yerden.
///
/// Ön-kontrol (koordinatörün istediği): fixture'lar `.full.json` — TAM VİDEO
/// (6-8 dakika, binlerce kare), rig'in bir hareket-izolasyon penceresi
/// YOK. `ReferenceCli.prepareTake` bunu FİLTRELEMİYOR, yalnız güven-kapısını
/// uyguluyor; segmentasyon yalnız PERİYODİK malzemede devreye girer. Bizim
/// `posture_setup` statik-duruş malzemesi olduğundan segmentasyon muhtemelen
/// `notApplied` diyecek ve TÜM video karesi tek "take" olarak ölçüme girecek
/// — bu VARSAYIM değil, çıktıda `cycleSegmentation.state` alanından okunacak.
void main(List<String> args) async {
  final want = args.isEmpty ? null : args.first;
  if (want == null) {
    stderr.writeln('kullanım: dart run bin/canonical_reference.dart <voice|guitar|piano>');
    exit(64);
  }

  final lib = Directory('${Platform.environment['HOME']}/motion-harvest/ostinato/landmarks');
  final instFile = File('${Directory.current.path}/../../config/fixture-instrument-map.json');
  final instMap = (jsonDecode(instFile.readAsStringSync()) as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, v as String));

  final files = lib.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final fixturesById = <String, Fixture>{};
  for (final f in files) {
    final id = f.uri.pathSegments.last.split('.').first;
    if (instMap[id] != want) continue;
    final doc = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    fixturesById[id] = Fixture.fromJson(doc);
  }
  stdout.writeln('ÇALGI: $want — kaynak havuzu: ${fixturesById.length}');
  for (final e in fixturesById.entries) {
    final fc = e.value.frames.length;
    stdout.writeln('  ${e.key}  frames=$fc  eligible=${ReferenceCli.eligibilityOf(e.value)}');
  }

  const cli = ReferenceCli(specs: StandardJoints.upperBody);

  // Koordinatör ön-kontrolü (M-F-70): fixture'lar `.full.json` — tam video,
  // rig'in hareket-izolasyon penceresi yok. 0.8.0'ın cycle-segmentation'ı
  // yalnız PERİYODİK malzemede devreye girer; bizim statik-duruş
  // malzememizde `notApplied` olması BEKLENİYOR ama VARSAYILMIYOR — burada
  // her uygun kaynak için doğrudan ölçülüyor, buildArtifact'ın içine
  // gömülü kalmasın diye ayrıca yazdırılıyor.
  const periodEstimator = CyclePeriodEstimator();
  stdout.writeln('\n=== periyot ölçümü (uygun kaynaklar — cycle-segmentation notApplied mı ölçüldü) ===');
  for (final e in fixturesById.entries) {
    if (ReferenceCli.eligibilityOf(e.value) != TakeEligibility.attested) continue;
    final prepared = cli.prepareTake(e.key, e.value);
    final p = periodEstimator.estimate(prepared.take.frames);
    stdout.writeln('  ${e.key}: measured=${p.measured} '
        '${p.measured ? "periodFrames=${p.periodFrames} periodicity=${p.periodicity.toStringAsFixed(3)}" : "reason=${p.reason}"}');
  }

  Map<String, dynamic> artifact;
  try {
    artifact = cli.buildArtifact(technique: want, fixturesById: fixturesById);
  } on ArgumentError catch (e) {
    stdout.writeln('\n⛔ buildArtifact REDDETTİ (havuz kapı-altı):');
    stdout.writeln('   $e');
    exit(2);
  } on ReferenceAgreementError catch (e) {
    stdout.writeln('\n⛔ buildArtifact REDDETTİ (M-F-47 anlaşma kapısı):');
    stdout.writeln('   $e');
    exit(2);
  }

  stdout.writeln('\n=== cycleSegmentation (L-139 / 0.8.0) ===');
  final seg = artifact['cycleSegmentation'] as Map<String, dynamic>;
  stdout.writeln('  state : ${seg['state']}');
  stdout.writeln('  reason: ${seg['reason']}');
  if ((seg['excludedUnalignable'] as Map).isNotEmpty) {
    stdout.writeln('  excludedUnalignable: ${seg['excludedUnalignable']}');
  }

  stdout.writeln('\n=== takes raporu (per-fixture, kanonik prepareTake) ===');
  for (final t in artifact['takes'] as List) {
    final m = t as Map<String, dynamic>;
    stdout.writeln('  ${m['id']}  frames=${m['frames']} gateDropped=${m['gateDroppedFrames']} '
        'undetected=${m['undetectedFrames']} isotropic=${m['isotropicCorrected']} '
        '${m.containsKey('periodFrames') ? 'periodFrames=${m['periodFrames']} periodicity=${m['periodicity']}' : ''}'
        '${m.containsKey('periodUnmeasured') ? 'periodUnmeasured=${m['periodUnmeasured']}' : ''}'
        '${m.containsKey('excluded') ? '  ⛔ excluded=${m['excluded']}' : ''}');
  }

  final result = artifact['result'] as Map<String, dynamic>;
  stdout.writeln('\n=== result ===');
  stdout.writeln('  measurementProvenance : ${artifact['measurementProvenance']}');
  stdout.writeln('  contributingTakes     : ${result['contributingTakes']}');
  stdout.writeln('  distinctSources       : ${result['distinctSources']}');
  stdout.writeln('  mirrorConfident       : ${result['mirrorConfident']} '
      '(gapMeasured: ${result['mirrorGapMeasured']})');
  stdout.writeln('  excludedIneligibleIds : ${result['excludedIneligibleIds']}');
  stdout.writeln('  excludedUnattestedIds : ${result['excludedUnattestedIds']}');
  stdout.writeln('  excludedNoFrameIds    : ${result['excludedNoMeasurableFrameIds']}');
  stdout.writeln('  excludedOutlierIds    : ${result['excludedOutlierIds']}');
  stdout.writeln('  unreliableJoints      : ${result['unreliableJoints']}');
  stdout.writeln('  meanAgreement         : ${result['meanAgreement']}');

  stdout.writeln('\n=== eklem başına dispersiyon (deg, medyan — toleransın kaynağı) ===');
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
