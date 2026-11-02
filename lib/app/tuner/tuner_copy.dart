import '../ui_copy.dart';

/// User copy of the tuner screen and session tuning gate (F4.1, FK7).
/// Mirrored in `content/ui/tuner.json`; see `test/ui_copy_catalog_test.dart`.
abstract final class TunerCopy {
  static const UiCopy title = ('Tuner', 'Akort');
  static const UiCopy back = ('Back', 'Geri');
  static const UiCopy guitar = ('Guitar', 'Gitar');
  static const UiCopy bass = ('Bass', 'Bas');
  static const UiCopy ukulele = ('Ukulele', 'Ukulele');

  static const UiCopy presetStandard = ('Standard', 'Standart');
  static const UiCopy presetDropD = ('Drop D', 'Drop D');
  static const UiCopy presetHalfStepDown = (
    'Half step down',
    'Yarım ses aşağı',
  );
  static const UiCopy presetDadgad = ('DADGAD', 'DADGAD');
  static const UiCopy presetOpenG = ('Open G', 'Open G');
  static const UiCopy presetBass4 = ('4-string', '4 telli');
  static const UiCopy presetBass5 = ('5-string', '5 telli');
  static const UiCopy presetUkuleleHighG = (
    'Standard (high G)',
    'Standart (yüksek Sol)',
  );
  static const UiCopy presetUkuleleLowG = ('Low G', 'Alçak Sol');

  static const UiCopy modeAuto = ('Auto', 'Otomatik');
  static const UiCopy modeManual = ('Manual', 'Elle');
  static const UiCopy modeChromatic = ('Chromatic', 'Kromatik');
  static const UiCopy modeAutoHint = (
    'Play any open string; the tuner guesses which one.',
    'Herhangi bir açık teli çal; akort hangisi olduğunu tahmin eder.',
  );
  static const UiCopy modeManualHint = (
    'Tap the string you will tune, then play only that string.',
    'Akort edeceğin tele dokun, sonra yalnız o teli çal.',
  );
  static const UiCopy modeChromaticHint = (
    'Shows the nearest note of any sound, without a string target.',
    'Tel hedefi olmadan, her sesin en yakın notasını gösterir.',
  );

  static const UiCopy stringLabel = ('String {v0} · {v1}', '{v0}. tel · {v1}');
  static const UiCopy stringInTune = ('in tune', 'akortlu');
  static const UiCopy stringWaiting = ('waiting', 'bekliyor');
  static const UiCopy stringLow = ('below', 'altında');
  static const UiCopy stringHigh = ('above', 'üstünde');

  static const UiCopy centsUnit = ('cents', 'cent');
  static const UiCopy band = (
    'In-tune band: ±{v0} cents (A4 = {v1} Hz)',
    'Akortlu bandı: ±{v0} cent (La4 = {v1} Hz)',
  );
  static const UiCopy target = ('Target {v0}', 'Hedef {v0}');
  static const UiCopy nearest = ('Nearest note {v0}', 'En yakın nota {v0}');

  static const UiCopy listening = (
    'Listening. Pluck one string once and let it ring.',
    'Dinliyorum. Tek bir teli bir kez çal ve tınlamasını bekle.',
  );
  static const UiCopy inTune = ('In tune', 'Akortlu');
  static const UiCopy tighten = (
    'Tighten slowly',
    'Yavaşça sık',
  );
  static const UiCopy loosen = ('Loosen', 'Gevşet');
  static const UiCopy above = ('Above the note', 'Notanın üstünde');
  static const UiCopy below = ('Below the note', 'Notanın altında');
  static const UiCopy tooHigh = ('Too high — loosen', 'Çok yüksek — gevşet');
  static const UiCopy tooHighHint = (
    'More than a semitone above the target. Loosen first; never tighten from here.',
    'Hedefin bir yarım sesten fazla üstünde. Önce gevşet; buradan asla sıkma.',
  );
  static const UiCopy chooseString = (
    'Which string are you playing?',
    'Hangi teli çalıyorsun?',
  );
  static const UiCopy chooseStringHint = (
    'The sound is more than 4 semitones from every string, so no string is locked. Tap the string you are playing.',
    'Ses her telden 4 yarım sesten fazla uzak; bu yüzden tel kilitlenmedi. Çaldığın tele dokun.',
  );
  static const UiCopy farFromSelected = (
    'The sound is more than 4 semitones from the selected string. Check that you are playing that string.',
    'Ses seçili telden 4 yarım sesten fazla uzak. O teli çaldığından emin ol.',
  );
  static const UiCopy octaveUnclear = (
    'Could not measure — play the string once more, softly.',
    'Ölçemedim — teli bir kez daha, yumuşak çal.',
  );
  static const UiCopy octaveUnclearHint = (
    'The octave was unclear, so no direction is shown.',
    'Oktav belirsizdi; bu yüzden yön gösterilmiyor.',
  );
  static const UiCopy playAgain = (
    'Play again',
    'Tekrar çal',
  );
  static const UiCopy playAgainHint = (
    'The reading was not steady enough to show a number. Pluck once and let the string ring.',
    'Okuma sayı gösterecek kadar kararlı değildi. Bir kez çal ve telin tınlamasını bekle.',
  );
  static const UiCopy couldNotMeasure = ('Could not measure', 'Ölçemedim');
  static const UiCopy tooQuiet = (
    'Too quiet: move the phone closer to the instrument.',
    'Çok sessiz: telefonu çalgıya yaklaştır.',
  );
  static const UiCopy unclear = (
    'Too noisy or two strings at once: damp the other strings and play one.',
    'Çok gürültülü ya da iki tel birden: diğer telleri sustur ve tek tel çal.',
  );
  static const UiCopy allInTune = (
    'All strings are in tune. You can stay here or go back.',
    'Bütün teller akortlu. Burada kalabilir ya da geri dönebilirsin.',
  );
  static const UiCopy progressCount = (
    'In tune: {v0} of {v1} strings',
    'Akortlu: {v1} telden {v0}',
  );
  static const UiCopy trace = ('Pitch trace · last 3 s', 'Perde izi · son 3 sn');

  static const UiCopy start = ('Start with permission', 'İzinle başlat');
  static const UiCopy stop = ('Stop microphone', 'Mikrofonu durdur');
  static const UiCopy openSettings = ('Open Settings', 'Ayarları aç');
  static const UiCopy phaseIdle = (
    'The tuner is stopped. Start it when you are ready to play.',
    'Akort durdu. Çalmaya hazır olduğunda başlat.',
  );
  static const UiCopy phaseStarting = (
    'Waiting for microphone permission and input…',
    'Mikrofon izni ve giriş bekleniyor…',
  );
  static const UiCopy phaseCalibrating = (
    'Keep the strings silent for a moment while the room level is measured.',
    'Oda seviyesi ölçülürken telleri bir an sessiz tut.',
  );
  static const UiCopy phaseDenied = (
    'Microphone permission was declined. Lessons work without it; retry only if you choose.',
    'Mikrofon izni verilmedi. Dersler mikrofonsuz çalışır; istersen yeniden deneyebilirsin.',
  );
  static const UiCopy phaseDeniedPermanent = (
    'Microphone access is disabled in Settings.',
    'Mikrofon erişimi Ayarlar’da kapalı.',
  );
  static const UiCopy phaseUnsupported = (
    'The tuner supports the built-in microphone only. Change the input, then start again.',
    'Akort yalnız dahili mikrofonu destekler. Girişi değiştir, sonra yeniden başlat.',
  );
  static const UiCopy phaseUnavailable = (
    'The microphone stopped or could not open. Retry when the control enables.',
    'Mikrofon durdu veya açılamadı. Düğme kullanılabilir olduğunda yeniden dene.',
  );
  static const UiCopy privacy = (
    'Audio stays in temporary memory on this device. It is never recorded or uploaded. Leaving this screen stops the microphone.',
    'Ses bu cihazda geçici bellekte kalır; kaydedilmez veya yüklenmez. Ekrandan çıkınca mikrofon durur.',
  );
  /// Shown after [DeviceAccuracyCopy.note] on the tuner.
  static const UiCopy newString = (
    'A new string stretches: check it again after a few minutes.',
    'Yeni tel esner: birkaç dakika sonra yeniden kontrol et.',
  );

  static const UiCopy gateKicker = ('TUNING', 'AKORT');
  static const UiCopy gateUnchecked = (
    'Tune before you start? A tuned instrument makes note feedback clearer.',
    'Başlamadan akort edelim mi? Akortlu çalgıda nota geri bildirimi daha net olur.',
  );
  static const UiCopy gateUntuned = (
    'Strings not yet in tune: {v0} of {v1}.',
    'Henüz akortlu olmayan tel: {v1} telden {v0}.',
  );
  static const UiCopy gateTuned = (
    'Tuned today: all strings were in tune.',
    'Bugün akort edildi: bütün teller akortluydu.',
  );
  static const UiCopy gateTune = ('Tune', 'Akort et');
  static const UiCopy gateContinue = ('Continue anyway', 'Yine de devam et');
  static const UiCopy gateContinued = (
    'Continuing without tuning. Note feedback may be less clear.',
    'Akort etmeden devam ediliyor. Nota geri bildirimi daha az net olabilir.',
  );

  static const List<UiCopy> all = [
    title,
    back,
    guitar,
    bass,
    ukulele,
    presetStandard,
    presetDropD,
    presetHalfStepDown,
    presetDadgad,
    presetOpenG,
    presetBass4,
    presetBass5,
    presetUkuleleHighG,
    presetUkuleleLowG,
    modeAuto,
    modeManual,
    modeChromatic,
    modeAutoHint,
    modeManualHint,
    modeChromaticHint,
    stringLabel,
    stringInTune,
    stringWaiting,
    stringLow,
    stringHigh,
    centsUnit,
    band,
    target,
    nearest,
    listening,
    inTune,
    tighten,
    loosen,
    above,
    below,
    tooHigh,
    tooHighHint,
    chooseString,
    chooseStringHint,
    farFromSelected,
    octaveUnclear,
    octaveUnclearHint,
    playAgain,
    playAgainHint,
    couldNotMeasure,
    tooQuiet,
    unclear,
    allInTune,
    progressCount,
    trace,
    start,
    stop,
    openSettings,
    phaseIdle,
    phaseStarting,
    phaseCalibrating,
    phaseDenied,
    phaseDeniedPermanent,
    phaseUnsupported,
    phaseUnavailable,
    privacy,
    newString,
    gateKicker,
    gateUnchecked,
    gateUntuned,
    gateTuned,
    gateTune,
    gateContinue,
    gateContinued,
  ];
}
