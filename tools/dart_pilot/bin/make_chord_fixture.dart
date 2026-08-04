import 'dart:convert';
import 'dart:io';

import 'package:ostinato_audio/ostinato_audio.dart';

/// Ham-örnekli akor fixture'ı üretir — koordinatör talimatı (M-F-116):
/// "kurucunun gitar kaydı geldiği an hazır boru hattına düşsün: kayıt→
/// doğrulama→chord_correctness live→'Open chords' dersi açılır, ara
/// mühendislik SIFIR."
///
/// `make_audio_fixtures.dart` ile AYNI desen: sinyal SENTEZLENİR, GERÇEK
/// motordan (`ChordDetector`, kromagram) geçirilir, motorun ÖLÇTÜĞÜ
/// yazılır — değerler uydurulmaz. Fark: `verify_end_to_end_session.py`de
/// M-O-35'in ZATEN kanıtlanmış (ama kalıcı fixture'a hiç YAZILMAMIŞ)
/// sonucunu YENİDEN, bu kez PERSISTE EDİLECEK bir dosyaya, koşuyor —
/// böylece uçtan-uca senaryo artık "M-O-35'ten alıntı" değil "bu
/// fixture'ı oku" diyebilir. Gerçek gitar kaydı gelince aynı iskelet
/// (`--real <wav>` bayrağı) o kaydı da aynı yoldan geçirecek — kod
/// değişmez, girdi değişir.
void main(List<String> args) {
  final outDir = Directory(args.isEmpty ? '../../fixtures/audio' : args.first)
    ..createSync(recursive: true);

  const sampleRate = 44100;
  // M-O-37: akor tanıma onset-tetiklemeli olmalı, ~200ms pencere kabul
  // edilebilir (akor tutulduğu sürece bedeli karşılanır). Burada sabit
  // pencere+hop kullanılıyor (fixture — canlı-akış değil), süre M-O-37
  // ile TUTARLI.
  const windowSamples = 8820; // 200 ms @ 44.1kHz
  const hopSamples = 4410; // 100 ms

  const openChordSpecs = <String, (int, ChordQuality)>{
    'E': (4, ChordQuality.major),
    'A': (9, ChordQuality.major),
    'D': (2, ChordQuality.major),
    'G': (7, ChordQuality.major),
    'C': (0, ChordQuality.major),
    'Am': (9, ChordQuality.minor),
    'Em': (4, ChordQuality.minor),
    'Dm': (2, ChordQuality.minor),
  };
  // AÇIK KÜME (M-O-67, 2026-08-04): aday = 24 şablonun TAMAMI, kabul = dersin
  // 8 akoru. Önceki sürüm aday kümesini 8'e daraltıyordu ve o daraltma
  // sözlük-dışı her akoru en yakın komşusuna GÜVENLE etiketletiyordu
  // (ölçüldü: Bb 28/29 pencerede "Dm"). Fixture, ürünün GERÇEKTEN koştuğu
  // yapılandırmayla üretilmeli — yoksa fixture ürünü değil, eski bir kusuru
  // belgeler.
  final detector = ChordDetector(
      templates: ChordTemplate.all(), acceptedNames: openChordSpecs.keys.toSet());

  // Bugünün kapsamı: E majör — verify_end_to_end_session.py'nin bugüne dek
  // M-O-35'ten ALINTILADIĞI değerin YERİNE geçecek fixture. Diğer 7 akor
  // aynı iskeletle (specs listesine eklemek) ucuzdur, ayrı bir tur.
  final chordId = 'E';
  final midiNotes = SyntheticTone.openGuitarChords[chordId]!;
  final signal = SyntheticTone.chord(
    midiNotes: midiNotes, sampleRate: sampleRate, seconds: 3.0,
    strumSpreadSeconds: 0.025,
  );

  final windows = <Map<String, dynamic>>[];
  var judged = 0;
  for (var i = 0; i + windowSamples <= signal.length; i += hopSamples) {
    final tUs = (i * 1000000 / sampleRate).round();
    final r = detector.detect(signal.sublist(i, i + windowSamples), sampleRate: sampleRate);
    final ok = r != null && r.chord.name == chordId;
    if (ok) judged++;
    windows.add({
      'tStartUs': tUs,
      'tEndUs': tUs + (windowSamples * 1000000 / sampleRate).round(),
      'chordName': r?.chord.name,
      'score': r == null ? null : double.parse(r.score.toStringAsFixed(4)),
      'runnerUp': r?.runnerUp.name,
      'runnerUpMargin': r == null ? null : double.parse(r.runnerUpMargin.toStringAsFixed(4)),
      'correct': r == null ? false : ok,
    });
  }

  final judgedFraction = windows.isEmpty ? 0.0 : judged / windows.length;
  const minJudgedFraction = 0.9; // strumSpread sonrası ilk ~25ms hariç hepsi çalınıyor olmalı
  final ok = judgedFraction >= minJudgedFraction;

  final fixtureId = 'AF-007-open-chord-$chordId-major';
  File('${outDir.path}/$fixtureId.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
    'schemaVersion': 'ostinato-audiofix-chord-1',
    'fixtureId': fixtureId,
    'kind': 'synthetic',
    r'$what': 'Open $chordId major chord (strummed, harmonic-rich partials, '
        'realistic voicing — SyntheticTone.chord). Real engine (ChordDetector/'
        'kromagram) measured, not authored. Placeholder for the founder\'s '
        'real guitar recording (M-O-35 kurucu-bekleyen) — same pipeline, '
        'different input.',
    'recordingMeta': {
      'source': 'generated',
      'sampleRate': sampleRate,
      'windowSamples': windowSamples,
      'hopSamples': hopSamples,
      'license': 'generated',
      r'$note': 'Synthetic — ground truth exact by construction. NOT proof '
          'on a real instrument (string buzz, dead strings, ringing '
          'neighbours are absent, M-O-35 caveat unchanged).',
    },
    'engineVersions': {
      'chord': 'ChordDetector (ostinato_audio, kromagram/template — M-O-35)',
    },
    'expected': {
      'chord': chordId,
      'midiNotes': midiNotes,
      'shouldJudge': true,
      'minJudgedFraction': minJudgedFraction,
    },
    'measured': {
      'windows': windows,
      'judgedWindows': judged,
      'judgedFraction': double.parse(judgedFraction.toStringAsFixed(3)),
    },
  }));

  stdout.writeln('${ok ? "✅" : "❌"} $fixtureId: ${windows.length} pencere · '
      'judged ${(judgedFraction * 100).round()}% (min ${(minJudgedFraction * 100).round()}%)');
  exit(ok ? 0 : 1);
}
