import '../ui_copy.dart';

/// OST-UX-05g: the help ("Yardım") surface texts. Nothing here judges the
/// player or claims a skill; an unreliable run is only "not measured".
abstract final class GhostLevelCopy {
  static const UiCopy title = ('Help level', 'Yardım düzeyi');
  static const UiCopy learn = ('Learning', 'Öğrenme');
  static const UiCopy reinforce = ('Reinforcing', 'Pekiştirme');
  static const UiCopy recall = ('Recalling', 'Hatırlama');
  static const UiCopy independent = ('Independent', 'Bağımsız');

  static const UiCopy notation = ('Notation', 'Nota');
  static const UiCopy tab = ('Tab', 'Tab');
  static const UiCopy beat = ('Beat line', 'Vuruş çizgisi');
  static const UiCopy label = ('Label', 'Etiket');
  static const UiCopy preStartPreview = (
    'Notation for 3 seconds before you start',
    'Başlamadan 3 sn nota',
  );

  static const UiCopy noExtraHelp = (
    'No extra help at this level',
    'Bu basamakta ek yardım yok',
  );

  static const UiCopy suggestion = (
    'You can try one step up',
    'Bir basamak yukarı denenebilir',
  );
  static const UiCopy notMeasured = (
    'The last run was not measured; it did not count toward the step',
    'Son koşu ölçülmedi; basamağa sayılmadı',
  );
  static const UiCopy shown = (
    'Help items for this level',
    'Bu basamağın yardımları',
  );

  static const List<UiCopy> all = <UiCopy>[
    title,
    learn,
    reinforce,
    recall,
    independent,
    notation,
    tab,
    beat,
    label,
    preStartPreview,
    suggestion,
    notMeasured,
    shown,
    noExtraHelp,
  ];
}
