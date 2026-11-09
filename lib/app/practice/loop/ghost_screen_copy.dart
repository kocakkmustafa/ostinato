import '../../ui_copy.dart';

/// OST-P0-07 copy (ghost screen: guides fade as measured practice repeats).
/// Warm and never a verdict: no "wrong", no "mistake", no "error", no "fail";
/// `test/ghost_screen_test.dart` scans these. Message ids are in
/// `lib/app/app_message_ids.dart`, the 14 catalogs carry the translations.
abstract final class GhostScreenCopy {
  static const UiCopy toggle = (
    'Fade the guides as I learn',
    'Öğrendikçe rehberleri azalt',
  );
  static const UiCopy status = ('Guide level: {v0}', 'Rehber düzeyi: {v0}');
  static const UiCopy learn = (
    'Learn: all guides shown',
    'Öğren: tüm rehberler açık',
  );
  static const UiCopy reinforce = (
    'Reinforce: fewer guides',
    'Pekiştir: daha az rehber',
  );
  static const UiCopy recall = (
    'Recall: only the beat is shown',
    'Hatırla: yalnız vuruş görünür',
  );
  static const UiCopy independent = (
    'On your own: no guides',
    'Kendi başına: rehber yok',
  );
  static const UiCopy showGuides = ('Show guides', 'Rehberi göster');
  static const UiCopy hideAgain = ('Hide guides again', 'Rehberi yine gizle');
  static const UiCopy moreGuides = (
    'Back to more guides',
    'Daha çok rehbere dön',
  );
  static const UiCopy hiddenLine = (
    'The written line is hidden at this level. Show the guides to see it again.',
    'Yazılı dizi bu düzeyde gizli. Yeniden görmek için rehberi göster.',
  );
  static const UiCopy independentDone = (
    'You played this run without guides; it matched the line well.',
    'Bu turu rehbersiz çaldın; yazılanla iyi örtüştü.',
  );

  static const List<UiCopy> all = [
    toggle,
    status,
    learn,
    reinforce,
    recall,
    independent,
    showGuides,
    hideAgain,
    moreGuides,
    hiddenLine,
    independentDone,
  ];
}
