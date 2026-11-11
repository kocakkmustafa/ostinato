import '../ui_copy.dart';

/// OST-UX-05b stage copy. Pairs marked "shared" are identical to pairs that
/// already carry a message id (OST-UX-04, the practice screen), so they reuse
/// those ids and translations; the rest are new reviewed pairs with ids in
/// all 14 catalogs. Nothing here promises a future feature or says "wrong".
abstract final class StageCopy {
  // shared
  static const UiCopy play = ('Play', 'Çal');
  static const UiCopy handleOther = ('Another practice', 'Başka çalış');
  static const UiCopy handlePath = ('My path', 'Yolum');
  static const UiCopy handleSetup = ('Setup', 'Ayar');
  static const UiCopy continueLine = (
    'Continue: level {v0}, module {v1}',
    'Devam: {v0}. seviye, {v1}. modül',
  );
  static const UiCopy reference = ('Reference', 'Referans');
  static const UiCopy tryAgain = ('Try again', 'Tekrar dene');
  static const UiCopy guitar = ('Guitar', 'Gitar');
  static const UiCopy historyTitle = ('History', 'Geçmiş');

  // new
  static const UiCopy justStarting = ('Just starting', 'Yeni başlıyorsun');
  static const UiCopy tools = ('Tools', 'Araçlar');
  static const UiCopy metronome = ('Metronome', 'Metronom');
  static const UiCopy loop = ('Loop', 'Döngü');
  static const UiCopy help = ('Help', 'Yardım');
  static const UiCopy pinMetronome = (
    'Keep the metronome in view',
    'Metronomu görünür tut',
  );
  static const UiCopy runNotCompleted = (
    'Run not completed: not measured, no gate recorded.',
    'Koşu tamamlanmadı: ölçülmedi, geçit kaydı yok.',
  );

  // new (05d, ek A: Play could not verify the membership; not a refusal)
  static const UiCopy startNotVerified = (
    'The membership could not be checked just now. Tap Play to try again.',
    'Üyelik şu an doğrulanamadı. Çal\'a dokunup tekrar dene.',
  );

  // new (05d: "My path" drawer)
  static const UiCopy historyEmpty = (
    'Play once; your run shows up here.',
    'Bir kez çal; koşun burada görünür.',
  );
  static const UiCopy pathReadFailed = (
    'Your path could not be read.',
    'Yolun okunamadı.',
  );
  static const UiCopy whyFirstModule = (
    'Why this one: it is the first module of the course.',
    'Neden bu: kursun ilk modülü.',
  );
  static const UiCopy whyGateMeasured = (
    'Why this one: the checkpoint before it was passed by measurement.',
    'Neden bu: ondan önceki geçiş dersi ölçümle geçildi.',
  );
  static const UiCopy whyGateNotMeasured = (
    'Why this one: the checkpoint before it was done as a self-check, not measured.',
    'Neden bu: ondan önceki geçiş dersi öz-kontrolle yapıldı, ölçülmedi.',
  );
  static const UiCopy whyEarlierProgress = (
    'Why this one: you already have progress in this module.',
    'Neden bu: bu modülde zaten ilerlemen var.',
  );
  static const UiCopy earLine = (
    '{v0} lessons played, {v1} runs',
    '{v0} ders çalındı, {v1} koşu',
  );
  static const UiCopy bestTempo = ('Best tempo ♩={v0}', 'En iyi tempo ♩={v0}');
  static const UiCopy weeklyLine = (
    'Weekly goal: {v0} of {v1} days this week',
    'Haftalık hedef: bu hafta {v1} günden {v0}',
  );
  static const UiCopy heardLabel = ('Heard', 'Duyulma');
  static const UiCopy accuracyLabel = ('Accuracy', 'Doğruluk');

  // new (05c: the "Another practice" layer's suggestion line)
  static const UiCopy suggestPickUp = (
    'Pick up where you stopped.',
    'Kaldığın yerden devam et.',
  );
  static const UiCopy suggestMoveCloser = (
    'Some notes were not heard. Move closer to the microphone and play again.',
    'Bazı notalar duyulmadı. Mikrofona yaklaşıp yeniden çal.',
  );
  static const UiCopy suggestListenFirst = (
    'Some notes sounded different. Listen to the reference first, then play.',
    'Bazı notalar farklı çıktı. Önce referansı dinle, sonra çal.',
  );
  static const UiCopy suggestSlowDown = (
    'The timing drifted. Lower the tempo a little.',
    'Zamanlama kaydı. Tempoyu biraz düşür.',
  );

  // shared (05f: the same pairs the settings screens already carry)
  static const UiCopy settings = ('Settings', 'Ayarlar');
  static const UiCopy account = ('Account', 'Hesap');
  static const UiCopy membership = ('Membership', 'Üyelik');
  static const UiCopy microphone = ('Microphone', 'Mikrofon');

  // new (05f: microphone refusal mode and the setup / device layer). Plain
  // statements of what is and is not measured; no blame, no future promise.
  static const UiCopy listeningOff = ('Listening is off', 'Dinleme kapalı');
  static const UiCopy listeningOffWhy = (
    'The microphone is not allowed, so nothing is measured. The metronome and the reference work; the tuner needs the microphone.',
    'Mikrofon izni verilmediği için ölçüm yapılmıyor. Metronom ve referans çalışır; akortçu mikrofon ister.',
  );
  static const UiCopy counterOff = (
    'Counter: not measured',
    'Sayaç: ölçülmüyor',
  );
  static const UiCopy goToSettings = ('Go to Settings', 'Ayarlara git');
  static const UiCopy muteHint = ('Hide', 'Gizle');
  static const UiCopy deviceTitle = ('Setup and device', 'Ayar ve cihaz');
  static const UiCopy micAllowed = ('Microphone: allowed', 'Mikrofon: verildi');
  static const UiCopy micDenied = (
    'Microphone: no permission',
    'Mikrofon: izin yok',
  );
  static const UiCopy micBlocked = (
    'Microphone: permission off',
    'Mikrofon: izin kapalı',
  );
  static const UiCopy micRestricted = (
    'Microphone: restricted',
    'Mikrofon: kısıtlı',
  );
  static const UiCopy latencyCalibration = (
    'Latency calibration',
    'Gecikme kalibrasyonu',
  );
  static const UiCopy noiseUnknown = (
    'Room noise: not measured',
    'Ortam gürültüsü: ölçülmedi',
  );
  static const UiCopy noiseQuiet = (
    'Room noise: quiet',
    'Ortam gürültüsü: sessiz',
  );
  static const UiCopy noiseSome = (
    'Room noise: a little noisy',
    'Ortam gürültüsü: biraz gürültülü',
  );
  static const UiCopy noiseLoud = (
    'Room noise: very noisy',
    'Ortam gürültüsü: çok gürültülü',
  );

  /// Pairs that need a new message id (not yet in the table).
  static const List<UiCopy> newPairs = <UiCopy>[
    justStarting,
    tools,
    metronome,
    loop,
    help,
    pinMetronome,
    runNotCompleted,
    suggestPickUp,
    suggestMoveCloser,
    suggestListenFirst,
    suggestSlowDown,
    startNotVerified,
    historyEmpty,
    pathReadFailed,
    whyFirstModule,
    whyGateMeasured,
    whyGateNotMeasured,
    whyEarlierProgress,
    earLine,
    bestTempo,
    weeklyLine,
    listeningOff,
    listeningOffWhy,
    counterOff,
    goToSettings,
    muteHint,
    deviceTitle,
    micAllowed,
    micDenied,
    micBlocked,
    micRestricted,
    latencyCalibration,
    noiseUnknown,
    noiseQuiet,
    noiseSome,
    noiseLoud,
  ];

  static const List<UiCopy> all = <UiCopy>[
    play,
    handleOther,
    handlePath,
    handleSetup,
    continueLine,
    reference,
    tryAgain,
    guitar,
    historyTitle,
    heardLabel,
    accuracyLabel,
    settings,
    account,
    membership,
    microphone,
    ...newPairs,
  ];
}
