import '../ui_copy.dart';

/// Test-flow copy (checkpoints run part by part). Mirrored in
/// `content/ui/test-flow.json`; see `test/ui_copy_catalog_test.dart`.
abstract final class TestFlowCopy {
  static const UiCopy title = ('Test, part by part', 'Test, bölüm bölüm');
  static const UiCopy intro = (
    'Each part is checked on its own. If a part does not pass, repeat only that part; your progress is kept on this phone.',
    'Her bölüm ayrı değerlendirilir. Bir bölüm geçmezse yalnız o bölümü tekrarla; ilerlemen bu telefonda saklanır.',
  );
  static const UiCopy banner = (
    'This test runs part by part. Clapping and on-screen parts are measured; singing parts are a self-check and do not decide the result.',
    'Bu test bölüm bölüm ilerler. Alkış ve ekran bölümleri ölçülür; şarkı bölümleri öz-kontroldür ve sonucu belirlemez.',
  );
  static const UiCopy open = (
    'Take the test part by part',
    'Testi bölüm bölüm yap',
  );
  static const UiCopy continueWith = ('Continue: {v0}', 'Devam et: {v0}');
  static const UiCopy partPassed = ('PASSED', 'GEÇTİ');
  static const UiCopy partNotYet = (
    'NOT YET · REPEAT THIS PART',
    'HENÜZ DEĞİL · BU BÖLÜMÜ TEKRARLA',
  );
  static const UiCopy partToDo = ('TO DO', 'YAPILACAK');
  static const UiCopy partSelfCheck = (
    'SELF-CHECK · NOT MEASURED',
    'ÖZ-KONTROL · ÖLÇÜLMEDİ',
  );
  static const UiCopy partSelfDone = (
    'SELF-CHECK DONE · NOT MEASURED',
    'ÖZ-KONTROL YAPILDI · ÖLÇÜLMEDİ',
  );
  static const UiCopy selfCheckDone = (
    'Done: I checked this myself',
    'Yaptım: kendim kontrol ettim',
  );
  static const UiCopy resultPassed = (
    'Test passed: every measured part passed.',
    'Test geçildi: ölçülen bölümlerin hepsi geçti.',
  );
  static const UiCopy resultProgress = (
    '{v0} of {v1} measured parts passed.',
    '{v1} ölçülen bölümden {v0} tanesi geçti.',
  );
  static const UiCopy statusPassed = (
    'DONE · TEST PASSED',
    'YAPILDI · TEST GEÇİLDİ',
  );

  static const List<UiCopy> all = [
    title,
    intro,
    banner,
    open,
    continueWith,
    partPassed,
    partNotYet,
    partToDo,
    partSelfCheck,
    partSelfDone,
    selfCheckDone,
    resultPassed,
    resultProgress,
    statusPassed,
  ];
}
