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

  /// Pairs that need a new message id (not yet in the table).
  static const List<UiCopy> newPairs = <UiCopy>[
    justStarting,
    tools,
    metronome,
    loop,
    help,
    pinMetronome,
    runNotCompleted,
  ];

  static const List<UiCopy> all = <UiCopy>[
    play,
    handleOther,
    handlePath,
    handleSetup,
    continueLine,
    reference,
    tryAgain,
    ...newPairs,
  ];
}
