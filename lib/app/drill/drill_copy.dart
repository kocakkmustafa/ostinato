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
  static const UiCopy bannerSingingAlternative = (
    'Singing is not measured in this build; check your singing yourself. The on-screen version below is measured: passing it saves the lesson as done.',
    'Şarkı söyleme bu sürümde ölçülmüyor; şarkını kendin kontrol et. Aşağıdaki ekran sürümü ölçülür: geçince ders yapıldı olarak kaydedilir.',
  );
  static const UiCopy statusPassed = (
    'DONE · DRILL PASSED',
    'YAPILDI · ALIŞTIRMA GEÇİLDİ',
  );
  static const UiCopy bannerReady = (
    'This lesson has an on-screen drill. Passing it saves the lesson as done; the playing part is not measured yet.',
    'Bu dersin ekran alıştırması var. Geçince ders yapıldı olarak kaydedilir; çalma bölümü henüz ölçülmüyor.',
  );

  // ---- F2.6b heard drills ----
  static const UiCopy tempoCompare = (
    'Listen to both parts. Was the second one faster, slower or the same?',
    'İki bölümü dinle. İkincisi daha hızlı mı, daha yavaş mı, aynı mı?',
  );
  static const UiCopy pitchDirection = (
    'Listen. Was the second note higher or lower?',
    'Dinle. İkinci nota daha tiz mi, daha pes mi?',
  );
  static const UiCopy pitchContour = (
    'Listen. How did the three notes move?',
    'Dinle. Üç nota nasıl hareket etti?',
  );
  static const UiCopy sameDifferent = (
    'Listen. Were the two notes the same or different?',
    'Dinle. İki nota aynı mıydı, farklı mı?',
  );
  static const UiCopy intervalUp = (
    'Listen. Which rising interval was it?',
    'Dinle. Hangi yükselen aralıktı?',
  );
  static const UiCopy intervalDown = (
    'Listen. Which falling interval was it?',
    'Dinle. Hangi inen aralıktı?',
  );
  static const UiCopy chordQuality = (
    'Listen. Which chord quality was it?',
    'Dinle. Akorun rengi hangisiydi?',
  );
  static const UiCopy faster = ('Faster', 'Daha hızlı');
  static const UiCopy slower = ('Slower', 'Daha yavaş');
  static const UiCopy same = ('The same', 'Aynı');
  static const UiCopy higher = ('Higher', 'Daha tiz');
  static const UiCopy lower = ('Lower', 'Daha pes');
  static const UiCopy different = ('Different', 'Farklı');
  static const UiCopy moveUp = ('up', 'yukarı');
  static const UiCopy moveDown = ('down', 'aşağı');
  static const UiCopy moveSame = ('same', 'aynı');
  static const UiCopy minor2 = ('minor 2nd', 'küçük 2’li');
  static const UiCopy major2 = ('major 2nd', 'büyük 2’li');
  static const UiCopy minor3 = ('minor 3rd', 'küçük 3’lü');
  static const UiCopy major3 = ('major 3rd', 'büyük 3’lü');
  static const UiCopy perfect4 = ('perfect 4th', 'tam 4’lü');
  static const UiCopy tritone = ('tritone', 'artık 4’lü');
  static const UiCopy perfect5 = ('perfect 5th', 'tam 5’li');
  static const UiCopy minor6 = ('minor 6th', 'küçük 6’lı');
  static const UiCopy major6 = ('major 6th', 'büyük 6’lı');
  static const UiCopy minor7 = ('minor 7th', 'küçük 7’li');
  static const UiCopy major7 = ('major 7th', 'büyük 7’li');
  static const UiCopy octave = ('octave', 'oktav');
  static const UiCopy qualityMajor = ('major', 'majör');
  static const UiCopy qualityMinor = ('minor', 'minör');
  static const UiCopy qualityDominant7 = ('dominant 7th', 'dominant 7’li');
  static const UiCopy play = ('Play', 'Çal');
  static const UiCopy playAgain = ('Play again', 'Yeniden çal');
  static const UiCopy playMine = ('Play my answer', 'Cevabımı çal');
  static const UiCopy playExpected = (
    'Play the expected',
    'Beklenen cevabı çal',
  );

  // ---- F2.6c read on the staff, tonic after a cadence ----
  static const UiCopy staffNote = ('Which note is this?', 'Bu nota hangisi?');
  static const UiCopy keySignature = (
    'Which major key has this key signature?',
    'Bu donanım hangi majör tonun?',
  );
  static const UiCopy staffInterval = (
    'Which interval is this?',
    'Bu aralık kaçlı?',
  );
  static const UiCopy tonicOrNot = (
    'Listen to the cadence, then the note. Is the note the tonic of {v0} major?',
    'Kadansı, sonra notayı dinle. Nota {v0} majörün durağı mı?',
  );
  static const UiCopy keyOption = ('{v0} major', '{v0} majör');
  static const UiCopy number2 = ('2nd', '2’li');
  static const UiCopy number3 = ('3rd', '3’lü');
  static const UiCopy number4 = ('4th', '4’lü');
  static const UiCopy number5 = ('5th', '5’li');
  static const UiCopy number6 = ('6th', '6’lı');
  static const UiCopy number7 = ('7th', '7’li');
  static const UiCopy number8 = ('8th (octave)', '8’li (oktav)');
  static const UiCopy tonicYes = ('Yes, the tonic', 'Evet, durak');
  static const UiCopy tonicNo = ('No, another note', 'Hayır, başka bir nota');
  static const UiCopy trebleClef = ('Treble clef', 'Sol anahtarı');
  static const UiCopy bassClef = ('Bass clef', 'Fa anahtarı');

  // ---- F2.6d dictation ----
  static const UiCopy rhythmDictation = (
    'Listen, then write the rhythm you heard ({v0} bar(s) of 4/4).',
    'Dinle, sonra duyduğun ritmi yaz ({v0} ölçü, 4/4).',
  );
  static const UiCopy melodicDictationGiven = (
    'Listen after the cadence, then write the {v0} notes in {v1} major. The first note is given.',
    'Kadanstan sonra dinle ve {v1} majördeki {v0} notayı yaz. İlk nota verildi.',
  );
  static const UiCopy melodicDictation = (
    'Listen after the cadence, then write the {v0} notes in {v1} major.',
    'Kadanstan sonra dinle ve {v1} majördeki {v0} notayı yaz.',
  );
  static const UiCopy valueWhole = ('whole note', 'birlik');
  static const UiCopy valueHalf = ('half note', 'ikilik');
  static const UiCopy valueDottedQuarter = (
    'dotted quarter',
    'noktalı dörtlük',
  );
  static const UiCopy valueQuarter = ('quarter note', 'dörtlük');
  static const UiCopy valueEighthPair = ('two eighths', 'iki sekizlik');
  static const UiCopy valueEighth = ('eighth note', 'sekizlik');
  static const UiCopy valueQuarterRest = ('quarter rest', 'dörtlük sus');
  static const UiCopy valueHalfRest = ('half rest', 'ikilik sus');
  static const UiCopy valueTie = ('tie', 'bağ');
  static const UiCopy undo = ('Undo', 'Geri al');
  static const UiCopy clear = ('Clear', 'Temizle');
  static const UiCopy check = ('Check', 'Kontrol et');
  static const UiCopy beatsWritten = (
    '{v0} of {v1} beats written',
    '{v1} vuruşun {v0} tanesi yazıldı',
  );
  static const UiCopy notesWritten = (
    '{v0} of {v1} notes written',
    '{v1} notanın {v0} tanesi yazıldı',
  );

  // ---- remaining drills: keyboard steps, staff places, bar symbols ----
  static const UiCopy stepSize = (
    'The two marked keys are neighbours in the {v0} major scale. Whole step or half step?',
    'İşaretli iki tuş {v0} majör dizisinde komşu. Tam ses mi, yarım ses mi?',
  );
  static const UiCopy staffPlace = (
    'Where is the note: on which line or in which space? Count from the bottom.',
    'Nota nerede: hangi çizgide ya da hangi aralıkta? Aşağıdan say.',
  );
  static const UiCopy staffSymbol = (
    'What is the highlighted sign?',
    'İşaretli simge nedir?',
  );
  static const UiCopy beatsInBar = (
    'How many beats are in each bar of 4/4?',
    '4/4’lük her ölçüde kaç vuruş var?',
  );
  static const UiCopy wholeStep = ('Whole step', 'Tam ses');
  static const UiCopy halfStep = ('Half step', 'Yarım ses');
  static const UiCopy lineN = ('Line {v0}', '{v0}. çizgi');
  static const UiCopy spaceN = ('Space {v0}', '{v0}. aralık');
  static const UiCopy barLine = ('Bar line', 'Ölçü çizgisi');
  static const UiCopy doubleBarLine = (
    'Double bar line (the end)',
    'Çift ölçü çizgisi (bitiş)',
  );
  static const UiCopy timeSignature44 = (
    'Time signature 4/4',
    '4/4 ölçü sayısı',
  );
  static const UiCopy beatsOption = ('{v0} beats', '{v0} vuruş');

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
    bannerSingingAlternative,
    bannerReady,
    stepSize,
    staffPlace,
    staffSymbol,
    beatsInBar,
    wholeStep,
    halfStep,
    lineN,
    spaceN,
    barLine,
    doubleBarLine,
    timeSignature44,
    beatsOption,
    tempoCompare,
    pitchDirection,
    pitchContour,
    sameDifferent,
    intervalUp,
    intervalDown,
    chordQuality,
    faster,
    slower,
    same,
    higher,
    lower,
    different,
    moveUp,
    moveDown,
    moveSame,
    minor2,
    major2,
    minor3,
    major3,
    perfect4,
    tritone,
    perfect5,
    minor6,
    major6,
    minor7,
    major7,
    octave,
    qualityMajor,
    qualityMinor,
    qualityDominant7,
    play,
    playAgain,
    playMine,
    playExpected,
    staffNote,
    keySignature,
    staffInterval,
    tonicOrNot,
    keyOption,
    number2,
    number3,
    number4,
    number5,
    number6,
    number7,
    number8,
    tonicYes,
    tonicNo,
    trebleClef,
    bassClef,
    rhythmDictation,
    melodicDictationGiven,
    melodicDictation,
    valueWhole,
    valueHalf,
    valueDottedQuarter,
    valueQuarter,
    valueEighthPair,
    valueEighth,
    valueQuarterRest,
    valueHalfRest,
    valueTie,
    undo,
    clear,
    check,
    beatsWritten,
    notesWritten,
  ];
}
