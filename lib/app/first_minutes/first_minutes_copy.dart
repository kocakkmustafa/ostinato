import '../ui_copy.dart';

/// OST-P0-05 first three minutes: every user sentence is a reviewed EN/TR
/// pair with a message id (`tool/build_message_ids.py`). Nothing here says
/// "wrong", and nothing claims a recording is kept: the app stores no sound.
abstract final class FirstMinutesCopy {
  static const UiCopy choiceTitle = (
    'How do you want to start?',
    'Nasıl başlamak istersin?',
  );
  static const UiCopy choiceHint = (
    'Pick one. You can use any of them later.',
    'Birini seç. Diğerlerini sonra da kullanabilirsin.',
  );
  static const UiCopy tapTitle = ('Tap the rhythm', 'Ritme dokun');
  static const UiCopy tapBody = (
    'Tap along with a beat. It works with touch alone.',
    'Bir ritme eşlik ederek dokun. Yalnızca dokunuşla çalışır.',
  );
  static const UiCopy voiceTitle = (
    'Clap lessons with the microphone',
    'Mikrofonla alkış dersleri',
  );
  static const UiCopy voiceBody = (
    'The clapping lessons in Ear training listen through the microphone. We ask first.',
    'Kulak eğitimindeki alkış dersleri mikrofonla dinler. Önce sorarız.',
  );
  static const UiCopy instrumentTitle = (
    'I have an instrument',
    'Enstrümanım var',
  );
  static const UiCopy instrumentBody = (
    'Go straight to the library and the lessons.',
    'Doğrudan kütüphaneye ve derslere git.',
  );
  static const UiCopy skip = ('Skip to the library', 'Kütüphaneye geç');

  static const UiCopy rhythmTitle = ('Tap along', 'Eşlik et');
  static const UiCopy rhythmIntro = (
    'Listen to one bar, then tap four beats with the beat.',
    'Bir ölçü dinle, sonra ritimle birlikte dört kez dokun.',
  );
  static const UiCopy startBeat = ('Start the beat', 'Ritmi başlat');
  static const UiCopy tapPad = ('Tap', 'Dokun');
  static const UiCopy tapPadLabel = (
    'Tap pad. Tap once for each beat.',
    'Dokunma alanı. Her vuruş için bir kez dokun.',
  );
  static const UiCopy tapCount = ('{v0} of {v1} taps', '{v0} / {v1} dokunuş');
  static const UiCopy gridLegend = (
    'Dots are the beat. Marks are your taps.',
    'Noktalar ritim. İşaretler senin dokunuşların.',
  );
  static const UiCopy gridLabel = (
    'Beat grid with your taps',
    'Dokunuşlarınla birlikte ritim ızgarası',
  );
  static const UiCopy humanNote = (
    'Every hand lands a little differently. That is normal.',
    'Her el biraz farklı vurur. Bu normal.',
  );
  static const UiCopy beatUnavailable = (
    'The beat cannot play right now, so I cannot follow your taps.',
    'Ritim şu an çalamıyor, bu yüzden dokunuşlarını takip edemiyorum.',
  );
  static const UiCopy tryAgain = ('Try again', 'Tekrar dene');

  static const UiCopy variationTitle = (
    'One small change',
    'Küçük bir değişiklik',
  );
  static const UiCopy variationBody = (
    'Same beat. This time leave the third beat empty: tap on 1, 2 and 4.',
    "Aynı ritim. Bu kez üçüncü vuruşu boş bırak: 1, 2 ve 4'e dokun.",
  );
  static const UiCopy variationGo = ('Try it', 'Dene');

  static const UiCopy summaryTitle = ('You made this', 'Bunu sen yaptın');
  static const UiCopy summarySteady = (
    'Your taps were consistent from one beat to the next.',
    'Dokunuşların vuruştan vuruşa tutarlıydı.',
  );
  static const UiCopy summaryLoose = (
    'Your taps varied a little from beat to beat. Every hand does.',
    'Dokunuşların vuruştan vuruşa biraz değişti. Her elde böyle olur.',
  );
  static const UiCopy summaryNotMeasured = (
    'I could not measure this one. Try again whenever you like.',
    'Bunu ölçemedim. İstediğin zaman tekrar deneyebilirsin.',
  );
  static const UiCopy compareCloser = (
    'Your second try was a bit more consistent.',
    'İkinci denemen biraz daha tutarlıydı.',
  );
  static const UiCopy compareSimilar = (
    'Both tries were about equally consistent.',
    'İki deneme yaklaşık aynı ölçüde tutarlıydı.',
  );
  static const UiCopy compareLooser = (
    'Your second try varied more, which is natural with a new pattern.',
    'İkinci denemen daha çok değişti; yeni bir kalıpta bu doğal.',
  );
  static const UiCopy compareNone = (
    'I could not compare the two tries this time.',
    'Bu sefer iki denemeyi karşılaştıramadım.',
  );
  static const UiCopy listenTry1 = ('Listen to try 1', '1. denemeyi dinle');
  static const UiCopy listenTry2 = ('Listen to try 2', '2. denemeyi dinle');
  static const UiCopy stopListen = ('Stop', 'Durdur');
  static const UiCopy playbackNote = (
    "Played from this session's memory only. Nothing is saved.",
    'Yalnız bu oturumun belleğinden çalınır. Hiçbir şey saklanmaz.',
  );
  static const UiCopy nextTitle = ('Next five minutes', 'Sonraki beş dakika');
  static const UiCopy nextBody = (
    'Open the library and try the starter lesson. It takes about five minutes.',
    'Kütüphaneyi aç ve başlangıç dersini dene. Yaklaşık beş dakika sürer.',
  );
  static const UiCopy openLibrary = ('Open the library', 'Kütüphaneyi aç');

  static const UiCopy voiceExplain = (
    'The clapping lessons in Ear training listen to your claps through the microphone. The app asks your device for permission first. Audio is processed on this device and is not sent.',
    'Kulak eğitimindeki alkış dersleri alkışlarını mikrofonla dinler. Uygulama önce cihazından izin ister. Ses bu cihazda işlenir ve gönderilmez.',
  );
  static const UiCopy voiceAllow = (
    'Allow the microphone',
    'Mikrofona izin ver',
  );
  static const UiCopy voiceGranted = (
    'Microphone permission granted. The clapping lessons in Ear training use it; open the library to find them.',
    'Mikrofon izni verildi. Kulak eğitimindeki alkış dersleri onu kullanır; bulmak için kütüphaneyi aç.',
  );
  static const UiCopy voiceDenied = (
    'No problem. The microphone stays off and you can do all of this by tapping.',
    'Sorun değil. Mikrofon kapalı kalır, bunların hepsini dokunarak yapabilirsin.',
  );
  static const UiCopy voicePermanent = (
    'The microphone is off for this app. On some devices a first refusal stays until you change it in your device settings. Tapping works without it.',
    'Mikrofon bu uygulama için kapalı. Bazı cihazlarda ilk ret, cihaz ayarlarından değiştirene kadar kalır. Dokunmak için mikrofon gerekmez.',
  );
  static const UiCopy continueTapping = (
    'Continue by tapping',
    'Dokunarak devam et',
  );
  static const UiCopy back = ('Back', 'Geri');

  static const List<UiCopy> all = <UiCopy>[
    choiceTitle,
    choiceHint,
    tapTitle,
    tapBody,
    voiceTitle,
    voiceBody,
    instrumentTitle,
    instrumentBody,
    skip,
    rhythmTitle,
    rhythmIntro,
    startBeat,
    tapPad,
    tapPadLabel,
    tapCount,
    gridLegend,
    gridLabel,
    humanNote,
    beatUnavailable,
    tryAgain,
    variationTitle,
    variationBody,
    variationGo,
    summaryTitle,
    summarySteady,
    summaryLoose,
    summaryNotMeasured,
    compareCloser,
    compareSimilar,
    compareLooser,
    compareNone,
    listenTry1,
    listenTry2,
    stopListen,
    playbackNote,
    nextTitle,
    nextBody,
    openLibrary,
    voiceExplain,
    voiceAllow,
    voiceGranted,
    voiceDenied,
    voicePermanent,
    continueTapping,
    back,
  ];
}
