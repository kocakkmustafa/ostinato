import '../../ui_copy.dart';

/// Full v1 guitar course copy (course screen + lesson reader). Mirrored in
/// `content/ui/v1-course.json`; see `test/ui_copy_catalog_test.dart`.
/// "Measured" and "self-reported" are never the same word.
abstract final class V1CourseCopy {
  static const UiCopy title = ('Guitar course', 'Gitar kursu');
  static const UiCopy intro = (
    'All {v0} lessons of the guitar course, by level and module. Measured lessons listen to every note. The others are self-checks for now: you tick a checklist and the lesson is saved as self-reported, not measured. A module opens when the checkpoint of the module before is cleared; inside a module, take the lessons in any order.',
    'Gitar kursunun {v0} dersinin tamamı, seviye ve modüle göre. Ölçülü dersler her notayı dinler. Diğerleri şimdilik öz-kontroldür: kontrol listesini işaretlersin, ders ölçülmüş değil kendi beyanı olarak kaydedilir. Bir modül, önceki modülün geçiş dersi tamamlanınca açılır; modül içinde dersleri istediğin sırayla al.',
  );
  static const UiCopy levelTitle = ('Level {v0}', 'Seviye {v0}');
  static const UiCopy levelProgress = (
    '{v0} of {v1} done',
    '{v1} dersten {v0} tamam',
  );
  static const UiCopy moduleTitle = ('Module {v0}', 'Modül {v0}');
  static const UiCopy trackAcoustic = (
    'Module {v0} · Acoustic track',
    'Modül {v0} · Akustik kol',
  );
  static const UiCopy trackElectric = (
    'Module {v0} · Electric track',
    'Modül {v0} · Elektro kol',
  );
  static const UiCopy levelTest = ('Level {v0} test', 'Seviye {v0} testi');
  static const UiCopy levelTestAcoustic = (
    'Level {v0} test · Acoustic track',
    'Seviye {v0} testi · Akustik kol',
  );
  static const UiCopy levelTestElectric = (
    'Level {v0} test · Electric track',
    'Seviye {v0} testi · Elektro kol',
  );
  static const UiCopy unitLocked = (
    'Locked · clear the checkpoint before',
    'Kilitli · önceki geçiş dersini tamamla',
  );
  static const UiCopy unitOpen = (
    'Open · {v0} of {v1} done',
    'Açık · {v1} dersten {v0} tamam',
  );
  static const UiCopy unitNotMeasured = (
    'Open · not measured · {v0} of {v1} done',
    'Açık · ölçülmedi · {v1} dersten {v0} tamam',
  );
  static const UiCopy notMeasuredNote = (
    'Not measured: this module opened after a checkpoint this build cannot measure yet, which you practised as a self-check.',
    'Ölçülmedi: bu modül, bu sürümün henüz ölçemediği ve senin öz-kontrolle çalıştığın bir geçiş dersinden sonra açıldı.',
  );

  // Availability chips.
  static const UiCopy chipMeasured = ('Measured', 'Ölçülü');
  static const UiCopy chipTuner = ('Tuner', 'Akort aleti');
  static const UiCopy chipSelfCheck = (
    'Self-check · mic feedback coming soon',
    'Öz-kontrol · mikrofon geri bildirimi yakında',
  );
  static const UiCopy chipSelfCheckLesson = ('Self-check', 'Öz-kontrol');
  static const UiCopy chipCamera = (
    'Checklist · camera check coming soon',
    'Kontrol listesi · kamera kontrolü yakında',
  );
  static const UiCopy chipDrill = (
    'Reading · on-screen exercise coming soon',
    'Okuma · ekran alıştırması yakında',
  );
  static const UiCopy chipHeld = (
    'Checkpoint held · measurement coming soon',
    'Geçiş bekletiliyor · ölçüm yakında',
  );

  // The suggested next lesson ("Start next lesson" rule); nothing is locked
  // inside a module.
  static const UiCopy nextChip = ('Next', 'Sıradaki');
  static const UiCopy nextChipSemantics = (
    'Suggested next lesson',
    'Önerilen sıradaki ders',
  );

  // Lesson statuses (measured statuses reuse the practice list's copy).
  static const UiCopy statusLocked = (
    'LOCKED · CLEAR THE CHECKPOINT BEFORE',
    'KİLİTLİ · ÖNCEKİ GEÇİŞİ TAMAMLA',
  );
  static const UiCopy statusSelfReported = (
    'DONE · SELF-REPORTED',
    'YAPILDI · KENDİ BEYANI',
  );
  static const UiCopy statusTuned = (
    'TUNED · MEASURED BY THE TUNER',
    'AKORT EDİLDİ · AKORT ALETİ ÖLÇTÜ',
  );
  static const UiCopy statusHeld = (
    'HELD · CANNOT BE PASSED YET',
    'BEKLETİLİYOR · HENÜZ GEÇİLEMEZ',
  );
  static const UiCopy statusHeldSelfReported = (
    'PRACTISED · SELF-REPORTED · NOT MEASURED',
    'ÇALIŞILDI · KENDİ BEYANI · ÖLÇÜLMEDİ',
  );
  static const UiCopy statusRepeat = (
    'SELF-REPORTED · REPEAT WITH MEASUREMENT',
    'KENDİ BEYANI · ÖLÇÜMLE TEKRAR ET',
  );

  // Lesson reader.
  static const UiCopy readerGoal = ('Goal', 'Hedef');
  static const UiCopy readerExplanation = ('Explanation', 'Anlatım');
  static const UiCopy readerTask = ('Task', 'Görev');
  static const UiCopy readerTempo = (
    'Tempo ♩={v0} → ♩={v1}',
    'Tempo ♩={v0} → ♩={v1}',
  );
  static const UiCopy readerReference = ('Reference', 'Referans');
  static const UiCopy readerReferenceSoon = (
    'Reference playback to compare with is not in this build yet. Use the task and the checklist.',
    'Karşılaştırma için referans çalma bu sürümde henüz yok. Görevi ve kontrol listesini kullan.',
  );
  static const UiCopy readerTickAll = (
    'Tick every item to mark the lesson done.',
    'Dersi yapıldı olarak işaretlemek için her maddeyi işaretle.',
  );
  static const UiCopy readerMarkDone = (
    'Mark as done (self-check)',
    'Yapıldı olarak işaretle (öz-kontrol)',
  );
  static const UiCopy readerDoneSelf = (
    'Done · self-reported, not measured',
    'Yapıldı · kendi beyanı, ölçülmedi',
  );
  static const UiCopy readerHeldDone = (
    'Practised · self-reported. The checkpoint stays held; the next module is open, labelled not measured.',
    'Çalışıldı · kendi beyanı. Geçiş dersi bekletilmeye devam eder; sonraki modül "ölçülmedi" etiketiyle açık.',
  );
  static const UiCopy readerSaveFailed = (
    'Could not be saved. Try again.',
    'Kaydedilemedi. Tekrar dene.',
  );
  static const UiCopy readerNext = ('Next lesson', 'Sıradaki ders');
  static const UiCopy readerOpenTuner = ('Open the tuner', 'Akort aletini aç');
  static const UiCopy readerTuned = (
    'Tuned · all strings in tune, measured by the tuner',
    'Akort edildi · tüm teller akortlu, akort aleti ölçtü',
  );
  static const UiCopy readerNotTuned = (
    'Not every string was in tune yet. Open the tuner again.',
    'Tellerin hepsi henüz akortlu değildi. Akort aletini yeniden aç.',
  );

  // Reader banners, one per availability.
  static const UiCopy bannerSelfCheck = (
    'Microphone feedback for this lesson is coming soon. For now, check yourself with the list below; your completion is saved as self-reported, not measured.',
    'Bu derste mikrofon geri bildirimi yakında. Şimdilik aşağıdaki listeyle kendini kontrol et; tamamlaman ölçülmüş değil kendi beyanı olarak kaydedilir.',
  );
  static const UiCopy bannerSelfCheckLesson = (
    'This lesson is a self-check. Tick the list as you go; your completion is saved as self-reported.',
    'Bu ders bir öz-kontrol dersidir. Listeyi ilerledikçe işaretle; tamamlaman kendi beyanı olarak kaydedilir.',
  );
  static const UiCopy bannerCamera = (
    'The camera check for this lesson is not in this build yet. Use the checklist instead; your completion is saved as self-reported.',
    'Bu dersin kamera kontrolü bu sürümde henüz yok. Yerine kontrol listesini kullan; tamamlaman kendi beyanı olarak kaydedilir.',
  );
  static const UiCopy bannerDrill = (
    'The on-screen exercise for this lesson is coming soon. Read the lesson and check yourself; your completion is saved as self-reported.',
    'Bu dersin ekran alıştırması yakında. Dersi oku ve kendini kontrol et; tamamlaman kendi beyanı olarak kaydedilir.',
  );
  static const UiCopy bannerHeld = (
    'This checkpoint needs measurement, which is not in this build yet, so it cannot be passed now. Practise it and mark it as a self-check: the next module then opens, labelled not measured.',
    'Bu geçiş dersi ölçüm ister; ölçüm bu sürümde henüz yok, bu yüzden şimdi geçilemez. Çalış ve öz-kontrolle işaretle: sonraki modül "ölçülmedi" etiketiyle açılır.',
  );
  static const UiCopy bannerTuner = (
    'Tune with the tuner. The lesson is done when the tuner measures all six strings in tune (±{v0} cents).',
    'Akort aletiyle akort et. Akort aleti altı telin hepsini akortlu ölçünce (±{v0} cent) ders tamamlanır.',
  );

  // Why a lesson is not measured yet.
  static const UiCopy reasonChords = (
    'Listening to chords is not in this build yet.',
    'Akor dinleme bu sürümde henüz yok.',
  );
  static const UiCopy reasonPitchTrack = (
    'Tracking bends and vibrato is not in this build yet.',
    'Bend ve vibrato izleme bu sürümde henüz yok.',
  );
  static const UiCopy reasonPiano = (
    'Piano listening is not in this build yet.',
    'Piyano dinleme bu sürümde henüz yok.',
  );
  static const UiCopy reasonCamera = (
    'The camera posture check is not in this build yet.',
    'Kamerayla duruş kontrolü bu sürümde henüz yok.',
  );
  static const UiCopy reasonTechnique = (
    'Technique notation — double stops, hammer-ons, pull-offs, slides, bends — is not measured yet.',
    'Teknik yazımı — çift ses, çekiç, çekme, kaydırma, bend — henüz ölçülmüyor.',
  );
  static const UiCopy reasonNotation = (
    'The practice screen cannot follow this exercise’s line yet.',
    'Pratik ekranı bu alıştırmanın dizisini henüz izleyemiyor.',
  );

  // Checklist for lessons that carry no self-check items of their own.
  static const UiCopy genericPlayedThrough = (
    'I played the whole task from start to finish.',
    'Görevi baştan sona çaldım.',
  );
  static const UiCopy genericTempo = (
    'I played it at the target tempo, ♩={v0}.',
    'Hedef tempoda, ♩={v0} ile çaldım.',
  );
  static const UiCopy genericSteady = (
    'I kept a steady, comfortable tempo.',
    'Sabit ve rahat bir tempoda çaldım.',
  );
  static const UiCopy genericClear = (
    'The notes rang clearly, without buzzing.',
    'Notalar cızırtısız ve net çınladı.',
  );
  static const UiCopy genericTaskDone = (
    'I worked through the task with the guitar in front of me.',
    'Görevi gitar önümdeyken baştan sona yaptım.',
  );
  static const UiCopy genericExplain = (
    'I can show each point of the explanation on the guitar.',
    'Anlatımdaki her maddeyi gitar üzerinde gösterebiliyorum.',
  );

  static const List<UiCopy> all = [
    title,
    intro,
    levelTitle,
    levelProgress,
    moduleTitle,
    trackAcoustic,
    trackElectric,
    levelTest,
    levelTestAcoustic,
    levelTestElectric,
    unitLocked,
    unitOpen,
    unitNotMeasured,
    notMeasuredNote,
    chipMeasured,
    chipTuner,
    chipSelfCheck,
    chipSelfCheckLesson,
    chipCamera,
    chipDrill,
    chipHeld,
    statusLocked,
    statusSelfReported,
    statusTuned,
    statusHeld,
    statusHeldSelfReported,
    statusRepeat,
    readerGoal,
    readerExplanation,
    readerTask,
    readerTempo,
    readerReference,
    readerReferenceSoon,
    readerTickAll,
    readerMarkDone,
    readerDoneSelf,
    readerHeldDone,
    readerSaveFailed,
    readerNext,
    readerOpenTuner,
    readerTuned,
    readerNotTuned,
    bannerSelfCheck,
    bannerSelfCheckLesson,
    bannerCamera,
    bannerDrill,
    bannerHeld,
    bannerTuner,
    reasonChords,
    reasonPitchTrack,
    reasonPiano,
    reasonCamera,
    reasonTechnique,
    reasonNotation,
    genericPlayedThrough,
    genericTempo,
    genericSteady,
    genericClear,
    genericTaskDone,
    genericExplain,
    nextChip,
    nextChipSemantics,
  ];
}
