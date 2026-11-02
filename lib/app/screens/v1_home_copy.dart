import '../ui_copy.dart';

/// v1 copy of the onboarding, home and guitar pages (approved by the founder
/// on 2026-11-01). Mirrored in `content/ui/v1-home.json`; see
/// `test/ui_copy_catalog_test.dart`.
abstract final class V1HomeCopy {
  static const UiCopy welcomeTitle = (
    'Learn guitar by playing.',
    'Gitarı çalarak öğren.',
  );
  static const UiCopy welcomeBody = (
    'Play along with a click and a scrolling tab; the app listens to each note and marks it correct, different note or couldn’t hear. The v1 programme has 690 lessons across guitar, voice, piano and ear training. Guitar is open in this release; the other courses follow.',
    'Klik ve akan tabla çal; uygulama çaldığın her notayı dinler ve doğru, farklı nota ya da duyamadım diye işaretler. v1 programı 690 ders: gitar, ses, piyano ve kulak eğitimi. Bu sürümde gitar açık; diğer kurslar sırayla eklenecek.',
  );
  static const UiCopy welcomeNote = (
    'To pass a lesson, at least 80% of its notes need to be correct; then the next lesson opens. The first lessons of each course are free; later lessons need an Ostinato or Motion+ subscription.',
    'Bir dersi geçmek için notaların en az %80’i doğru olmalı; o zaman sıradaki ders açılır. Her kursun ilk dersleri ücretsizdir; sonraki dersler Ostinato veya Motion+ aboneliği gerektirir.',
  );
  static const UiCopy scopeTitle = ('What’s inside', 'Neler var?');
  static const UiCopy scopePractice = (
    'Measured practice — click, scrolling tab, feedback on every note.',
    'Ölçülü pratik — klik, akan tab, nota başına geri bildirim.',
  );
  static const UiCopy scopeSetup = (
    'Setup wizard — latency check, room noise, tuning.',
    'Kurulum sihirbazı — gecikme ölçümü, oda sesi, akort.',
  );
  static const UiCopy scopeStreak = (
    'Streak and weekly goal — every measured practice counts.',
    'Seri ve haftalık hedef — her ölçülü pratik sayılır.',
  );
  static const UiCopy scopeWritten = (
    'Written lessons — the earlier 60-lesson path to read and work through at your own pace.',
    'Yazılı dersler — kendi hızında okuyup çalışabileceğin 60 derslik eski yol.',
  );
  static const UiCopy micTitle = ('Microphone', 'Mikrofon');
  static const UiCopy micBody = (
    'In measured practice the microphone listens to the notes you play. Audio is processed on this device and is not sent. What you play is not recorded; if you like, you can turn on listening back to your own recording — it stays on your device and is deleted at the end of the session. We ask for permission at your first measured lesson. Without it you can still read the lessons and use the self-checks.',
    'Ölçülü pratikte mikrofon çaldığın notaları dinler. Ses bu cihazda işlenir; gönderilmez. Çaldığın kaydedilmez; istersen kendi kaydını dinleme seçeneğini açabilirsin, kayıt cihazında kalır ve oturum sonunda silinir. İzni ilk ölçülü derste isteriz. Vermezsen dersleri okuyup öz-kontrolle çalışabilirsin.',
  );
  static const UiCopy cameraTitle = ('Camera', 'Kamera');
  static const UiCopy cameraBody = (
    'The camera is used only in a few setup lessons, to look at hand and wrist posture. We ask for permission in that lesson. Video is processed on this device; it is not recorded or sent. All other lessons work without the camera.',
    'Kamera yalnız birkaç kurulum dersinde, el ve bilek duruşuna bakmak için kullanılır. İzni o derste isteriz. Görüntü cihazda işlenir; kaydedilmez, gönderilmez. Diğer dersler kamerasız çalışır.',
  );
  static const UiCopy progressTitle = ('Your progress', 'İlerlemen');
  static const UiCopy progressBody = (
    'Your lesson results, streak and weekly goal are kept on this device. If you sign in to a Motion account and agree, they sync to your account so you can continue on another device.',
    'Ders sonuçların, serin ve haftalık hedefin bu cihazda tutulur. Motion hesabına giriş yapıp onay verirsen hesabına eşitlenir ve başka cihazda devam edebilirsin.',
  );

  /// [progressBody] while `ostinatoProgressSyncAvailable` is false: this
  /// release keeps progress on the device (store review 2026-11-02).
  static const UiCopy progressBodyLocal = (
    'Your lesson results, streak and weekly goal stay on this device; this release does not sync them to an account. Your account is used for your membership.',
    'Ders sonuçların, serin ve haftalık hedefin bu cihazda kalır; bu sürüm bunları hesaba eşitlemez. Hesabın üyeliğin için kullanılır.',
  );
  static const UiCopy homeSubtitle = (
    'Measured practice. Tuner. Weekly goal.',
    'Ölçülü pratik. Akort. Haftalık hedef.',
  );
  static const UiCopy homeIntro = (
    'Play your next lesson with a click and a scrolling tab; we show what we heard on every note. Voice and piano courses open in turn.',
    'Sıradaki dersini klik ve akan tabla çal; her notada ne duyduğumuzu gösteririz. Ses ve piyano kursları sırayla açılacak.',
  );
  static const UiCopy guitarCardOpen = (
    'Measured practice open',
    'Ölçülü pratik açık',
  );
  static const UiCopy guitarCardNext = (
    'Measured practice open · next lesson: {v0}',
    'Ölçülü pratik açık · sıradaki ders: {v0}',
  );
  static const UiCopy comingSoon = (
    'Coming soon · This course opens in a later update.',
    'Yakında · Bu kurs sonraki güncellemelerle açılacak.',
  );
  static const UiCopy measuredTitle = ('Measured practice', 'Ölçülü pratik');
  static const UiCopy measuredBody = (
    'Play with a click and a scrolling tab; every note is marked correct, different note or couldn’t hear. With 80% of notes correct, the next lesson opens.',
    'Klik ve akan tabla çal; her nota doğru, farklı nota ya da duyamadım diye işaretlenir. Notaların %80’i doğruysa sıradaki ders açılır.',
  );
  static const UiCopy startNext = ('Start next lesson', 'Sıradaki derse başla');
  static const UiCopy writtenLabel = (
    'WRITTEN LESSONS · 60 LESSONS',
    'YAZILI DERSLER · 60 DERS',
  );
  static const UiCopy writtenBody = (
    'A path from setup to two final performances that you read and work through at your own pace. In these lessons you mark completion yourself.',
    'Kurulumdan iki bitirme performansına kadar okuyup kendi hızında çalışabileceğin yol. Bu derslerde tamamlamayı sen işaretlersin.',
  );
  static const UiCopy heroBody = (
    'Settle the basic notes and rhythm with measured practice first; widen reading, chords, melody and fingerstyle with the written lessons.',
    'Önce ölçülü pratikle temel notaları ve ritmi otur; yazılı derslerle okuma, akor, melodi ve parmak stilini genişlet.',
  );
  static const UiCopy noteToolBody = (
    'Check the pitch of a single note with the microphone. It doesn’t count toward a lesson.',
    'Mikrofonla tek bir notanın perdesine bak. Ders sonucu saymaz.',
  );

  static const List<UiCopy> all = [
    welcomeTitle,
    welcomeBody,
    welcomeNote,
    scopeTitle,
    scopePractice,
    scopeSetup,
    scopeStreak,
    scopeWritten,
    micTitle,
    micBody,
    cameraTitle,
    cameraBody,
    progressTitle,
    progressBody,
    progressBodyLocal,
    homeSubtitle,
    homeIntro,
    guitarCardOpen,
    guitarCardNext,
    comingSoon,
    measuredTitle,
    measuredBody,
    startNext,
    writtenLabel,
    writtenBody,
    heroBody,
    noteToolBody,
  ];
}
