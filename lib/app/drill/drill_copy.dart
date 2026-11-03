import '../ui_copy.dart';

/// F2.6 drill copy. Mirrored in `content/ui/drill.json`; see
/// `test/ui_copy_catalog_test.dart`. A differing answer is shown as "your
/// answer / expected", never as "wrong" (lesson guide §3).
abstract final class DrillCopy {
  static const UiCopy noteAtFret = (
    'Which note is at fret {v0} on string {v1}?',
    '{v1}. telin {v0}. perdesindeki nota hangisi?',
  );
  static const UiCopy fretOfNote = (
    'On string {v1}, which fret plays {v0}?',
    '{v1}. telde {v0} hangi perdede?',
  );
  static const UiCopy enharmonic = (
    'What is the other name of {v0}?',
    '{v0} notasının diğer adı nedir?',
  );
  static const UiCopy scaleStep = (
    'Which step of the {v0} major scale is the marked note?',
    'İşaretli nota {v0} majör dizisinin kaçıncı derecesi?',
  );
  static const UiCopy pentatonicNote = (
    'Which note of the {v0} minor pentatonic is marked?',
    '{v0} minör pentatonikte işaretli nota hangisi?',
  );
  static const UiCopy chordTones = (
    'Which notes make {v0}?',
    '{v0} akorunu hangi notalar oluşturur?',
  );
  static const UiCopy romanNumeral = (
    'In {v0} major, which chord is {v1}?',
    '{v0} majörde {v1} hangi akordur?',
  );
  static const UiCopy bluesLine = (
    'Which is line {v0} of the 12-bar blues?',
    '12 ölçülük blues’un {v0}. satırı hangisi?',
  );
  static const UiCopy bluesBar = (
    'Which chord is in bar {v0} of the 12-bar blues?',
    '12 ölçülük blues’ta {v0}. ölçüdeki akor hangisi?',
  );
  static const UiCopy fretOption = ('Fret {v0}', '{v0}. perde');
  static const UiCopy stepOption = ('Step {v0}', '{v0}. derece');
  static const UiCopy progress = ('Question {v0} of {v1}', 'Soru {v0} / {v1}');
  static const UiCopy review = (
    'Once more: you mixed this one up earlier.',
    'Bir kez daha: bunu az önce karıştırdın.',
  );
  static const UiCopy matches = ('Matches.', 'Eşleşti.');
  static const UiCopy differs = (
    'Your answer: {v0} · Expected: {v1}',
    'Senin cevabın: {v0} · Beklenen: {v1}',
  );
  static const UiCopy next = ('Next', 'Sonraki');
  static const UiCopy seeResult = ('See the result', 'Sonucu gör');
  static const UiCopy resultTitle = ('Drill result', 'Alıştırma sonucu');
  static const UiCopy resultScore = (
    '{v0} of {v1} matched on the first try. Passing needs {v2}.',
    'İlk denemede {v1} sorudan {v0} tanesi eşleşti. Geçmek için {v2} gerekir.',
  );
  static const UiCopy passed = (
    'Passed. The lesson is saved as done; its playing part is not measured.',
    'Geçtin. Ders yapıldı olarak kaydedildi; çalma bölümü ölçülmedi.',
  );
  static const UiCopy notYet = (
    'Not yet. A new set of questions is ready.',
    'Henüz değil. Yeni bir soru seti hazır.',
  );
  static const UiCopy newSet = ('New set', 'Yeni set');
  static const UiCopy backToLesson = ('Back to the lesson', 'Derse dön');
  static const UiCopy section = ('On-screen drill', 'Ekran alıştırması');
  static const UiCopy start = (
    'Start the drill ({v0} questions)',
    'Alıştırmayı başlat ({v0} soru)',
  );
  static const UiCopy statusPassed = (
    'DONE · DRILL PASSED',
    'YAPILDI · ALIŞTIRMA GEÇİLDİ',
  );
  static const UiCopy bannerReady = (
    'This lesson has an on-screen drill. Passing it saves the lesson as done; the playing part is not measured yet.',
    'Bu dersin ekran alıştırması var. Geçince ders yapıldı olarak kaydedilir; çalma bölümü henüz ölçülmüyor.',
  );

  static const List<UiCopy> all = [
    noteAtFret,
    fretOfNote,
    enharmonic,
    scaleStep,
    pentatonicNote,
    chordTones,
    romanNumeral,
    bluesLine,
    bluesBar,
    fretOption,
    stepOption,
    progress,
    review,
    matches,
    differs,
    next,
    seeResult,
    resultTitle,
    resultScore,
    passed,
    notYet,
    newSet,
    backToLesson,
    section,
    start,
    statusPassed,
    bannerReady,
  ];
}
