import '../ui_copy.dart';

/// OST-UX-04 prototype copy: every sentence is a reviewed EN/TR pair with a
/// message id in all 14 catalogs (`tool/build_message_ids.py`). Generated
/// once from the reviewed sources; nothing here says "wrong".
abstract final class UxPrototypeCopy {
  static const UiCopy protoBadge = ('Prototype', 'Prototip');
  static const UiCopy protoNote = (
    'Prototype with sample data. Nothing is recorded or measured.',
    'Örnek verili prototip. Hiçbir şey kaydedilmez ya da ölçülmez.',
  );
  static const UiCopy entryLabel = (
    'Open the prototype stage',
    'Prototip sahneyi aç',
  );
  static const UiCopy stageHeading = (
    'Notes on the sixth string',
    'Altıncı telde notalar',
  );
  static const UiCopy continueLine = (
    'Continue: level {v0}, module {v1}',
    'Devam: {v0}. seviye, {v1}. modül',
  );
  static const UiCopy sectionLine = ('Section: bar {v0}', 'Bölüm: {v0}. ölçü');
  static const UiCopy tempoLine = ('Tempo {v0} bpm', 'Tempo {v0} bpm');
  static const UiCopy play = ('Play', 'Çal');
  static const UiCopy stop = ('Stop', 'Dur');
  static const UiCopy playSelf = (
    'Play and check yourself',
    'Çal ve kendin değerlendir',
  );
  static const UiCopy handleOther = ('Another practice', 'Başka çalış');
  static const UiCopy handlePath = ('My path', 'Yolum');
  static const UiCopy handleSetup = ('Setup', 'Ayar');
  static const UiCopy micReady = ('Microphone ready', 'Mikrofon hazır');
  static const UiCopy micListening = ('Listening', 'Dinliyor');
  static const UiCopy micOff = (
    'Listening is off · not measured',
    'Dinleme kapalı · ölçülmüyor',
  );
  static const UiCopy micOffBody = (
    'You can still play along and check yourself, or practise by ear.',
    'Yine de çalabilir, kendini değerlendirebilir ya da kulakla çalışabilirsin.',
  );
  static const UiCopy markCorrect = ('correct', 'doğru');
  static const UiCopy markDifferent = ('different note', 'farklı nota');
  static const UiCopy markCouldNot = ('could not hear', 'duyamadım');
  static const UiCopy counterLabel = (
    '{v0} correct, {v1} different note, {v2} could not hear',
    '{v0} doğru, {v1} farklı nota, {v2} duyamadım',
  );
  static const UiCopy loopNotice = (
    'Loop on: the next run is not measured.',
    'Döngü açık: sonraki koşu ölçülmez.',
  );
  static const UiCopy earFirst = ('Ear practice first', 'Önce kulak çalışması');
  static const UiCopy goSetup = ('Go to setup', 'Ayara git');
  static const UiCopy close = ('Close', 'Kapat');
  static const UiCopy backToStage = ('Back to the stage', 'Sahneye dön');
  static const UiCopy otherSuggestion = (
    'Suggestion: repeat bar {v0} slowly',
    'Öneri: {v0}. ölçüyü yavaş tekrar et',
  );
  static const UiCopy sameExercise = ('Same exercise', 'Aynı alıştırma');
  static const UiCopy earNoInstrument = (
    'Ear, no instrument',
    'Kulak, enstrümansız',
  );
  static const UiCopy latestRun = ('Latest run', 'Son koşu');
  static const UiCopy earTitle = (
    'Ear · no instrument',
    'Kulak · enstrümansız',
  );
  static const UiCopy earFormat = ('On-screen answer', 'Ekranda cevap');
  static const UiCopy earPrompt = (
    'Listen to two notes. Is the second one higher or lower?',
    'İki nota dinle. İkincisi daha yüksek mi, daha alçak mı?',
  );
  static const UiCopy earListen = ('Listen', 'Dinle');
  static const UiCopy earDrawn = (
    'Prototype: the two notes are drawn, not played.',
    'Prototip: iki nota çizilir, çalınmaz.',
  );
  static const UiCopy earHigher = ('Higher', 'Daha yüksek');
  static const UiCopy earLower = ('Lower', 'Daha alçak');
  static const UiCopy earWas = (
    'The second note was higher.',
    'İkinci nota daha yüksekti.',
  );
  static const UiCopy earNotCounted = (
    'Ear practice does not count toward instrument progress.',
    'Kulak çalışması enstrüman ilerlemesine sayılmaz.',
  );
  static const UiCopy tabPath = ('Path', 'Yol');
  static const UiCopy tabHistory = ('History', 'Geçmiş');
  static const UiCopy levelLabel = ('Level {v0}', '{v0}. seviye');
  static const UiCopy moduleRow = (
    'Module {v0} · lessons: {v1}',
    '{v0}. modül · ders: {v1}',
  );
  static const UiCopy nextBadge = ('Up next', 'Sıradaki');
  static const UiCopy nextWhy = (
    'Why this one: it is the next module in order.',
    'Neden bu: sırada bir sonraki modül.',
  );
  static const UiCopy historyHead = (
    'Last runs, side by side',
    'Son koşular, yan yana',
  );
  static const UiCopy dayYesterday = ('Yesterday', 'Dün');
  static const UiCopy dayToday = ('Today', 'Bugün');
  static const UiCopy heardPct = ('Heard {v0}%', 'Duyulan %{v0}');
  static const UiCopy notMeasured = ('Not measured', 'Ölçülmedi');
  static const UiCopy historyEmpty = (
    'No runs yet. Play once; it shows up here.',
    'Henüz koşu yok. Bir kez çal; burada görünür.',
  );
  static const UiCopy earListedApart = (
    'Ear practice is listed separately.',
    'Kulak çalışması ayrı listelenir.',
  );
  static const UiCopy resultTitle = ('This run', 'Bu koşu');
  static const UiCopy accuracyLine = (
    'Accuracy on the notes I heard: {v0}%',
    'Duyduğum notalarda doğruluk: %{v0}',
  );
  static const UiCopy whereLine = ('Where: bar {v0}', 'Nerede: {v0}. ölçü');
  static const UiCopy couldNotLine = (
    'Could not hear: {v0} note · reason: {v1}',
    'Duyamadım: {v0} nota · sebep: {v1}',
  );
  static const UiCopy reasonQuiet = ('too quiet', 'kısık');
  static const UiCopy correctionLine = (
    'One thing to try: play bar {v0} slower, one note per beat.',
    'Bir deneme: {v0}. ölçüyü daha yavaş, vuruş başına bir nota çal.',
  );
  static const UiCopy unmeasuredBody = (
    'This run was stopped early, looped or waited on, so it is not measured and opens no gate.',
    'Bu koşu erken durdu, döngülendi ya da beklemeli yapıldı; ölçülmedi ve geçit açmaz.',
  );
  static const UiCopy selfCheckBody = (
    'Nothing was listened to, so nothing is measured.',
    'Dinleme olmadığı için bir şey ölçülmedi.',
  );
  static const UiCopy unreliableBody = (
    'I could not hear this run clearly enough to measure it. Check the microphone and the room, then try again.',
    'Bu koşuyu ölçecek kadar net duyamadım. Mikrofonu ve odayı kontrol et, sonra yeniden dene.',
  );
  static const UiCopy tryAgain = ('Try again', 'Tekrar dene');
  static const UiCopy nextButton = ('Next', 'Sonraki');
  static const UiCopy loopBar = ('Loop this bar', 'Bu ölçüyü döngüle');
  static const UiCopy deviceTitle = ('Device', 'Cihaz');
  static const UiCopy protoMicState = (
    'Prototype: microphone state',
    'Prototip: mikrofon durumu',
  );
  static const UiCopy stateReady = ('Ready', 'Hazır');
  static const UiCopy stateDenied = ('Denied', 'Reddedildi');
  static const UiCopy stateUnclear = ('Unclear', 'Net değil');

  /// Every pair above, for the catalog-coverage test.
  static const List<UiCopy> all = <UiCopy>[
    protoBadge,
    protoNote,
    entryLabel,
    stageHeading,
    continueLine,
    sectionLine,
    tempoLine,
    play,
    stop,
    playSelf,
    handleOther,
    handlePath,
    handleSetup,
    micReady,
    micListening,
    micOff,
    micOffBody,
    markCorrect,
    markDifferent,
    markCouldNot,
    counterLabel,
    loopNotice,
    earFirst,
    goSetup,
    close,
    backToStage,
    otherSuggestion,
    sameExercise,
    earNoInstrument,
    latestRun,
    earTitle,
    earFormat,
    earPrompt,
    earListen,
    earDrawn,
    earHigher,
    earLower,
    earWas,
    earNotCounted,
    tabPath,
    tabHistory,
    levelLabel,
    moduleRow,
    nextBadge,
    nextWhy,
    historyHead,
    dayYesterday,
    dayToday,
    heardPct,
    notMeasured,
    historyEmpty,
    earListedApart,
    resultTitle,
    accuracyLine,
    whereLine,
    couldNotLine,
    reasonQuiet,
    correctionLine,
    unmeasuredBody,
    selfCheckBody,
    unreliableBody,
    tryAgain,
    nextButton,
    loopBar,
    deviceTitle,
    protoMicState,
    stateReady,
    stateDenied,
    stateUnclear,
  ];
}
