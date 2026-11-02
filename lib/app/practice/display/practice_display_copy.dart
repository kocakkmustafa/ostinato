import 'package:flutter/widgets.dart';

import '../../ui_copy.dart';
import '../loop/practice_marks.dart';

/// FK4 copy (left-handed mode, colour-blind palette, spoken mark states).
/// Mirrored in `content/ui/practice-display.json`; see
/// `test/ui_copy_catalog_test.dart`. Never "wrong".
abstract final class PracticeDisplayCopy {
  static const UiCopy leftHandedTitle = ('Left-handed', 'Solak');
  static const UiCopy leftHandedBody = (
    'Mirrors the TAB strip: notes come in from the left and meet the playing line on the right. Strings keep the written order, string 1 on top. Listening and measuring do not change.',
    'TAB şeridini aynalar: notalar soldan gelir ve sağdaki çalma çizgisinde buluşur. Teller yazılı sırasını korur, 1. tel üstte. Dinleme ve ölçüm değişmez.',
  );
  static const UiCopy colorBlindTitle = (
    'Colour-blind friendly colours',
    'Renk körlüğüne uygun renkler',
  );
  static const UiCopy colorBlindBody = (
    'Blue and orange instead of teal and amber. Every note state also keeps its own shape and symbol: ✓ correct, ◆ different note, ? couldn\'t hear.',
    'Camgöbeği ve kehribar yerine mavi ve turuncu. Her nota durumu kendi şeklini ve simgesini de korur: ✓ doğru, ◆ farklı nota, ? duyamadım.',
  );

  // Spoken mark states (VoiceOver / TalkBack). The first three reuse the
  // practice screen's reviewed pairs.
  static const UiCopy markCorrect = ('Correct', 'Doğru');
  static const UiCopy markDifferent = ('Different note', 'Farklı nota');
  static const UiCopy markUnheard = ("Couldn't hear", 'Duyamadım');
  static const UiCopy markPending = ('Not played yet', 'Henüz çalınmadı');
  static const UiCopy lastNote = ('Last note: {v0}', 'Son nota: {v0}');

  static const List<UiCopy> all = [
    leftHandedTitle,
    leftHandedBody,
    colorBlindTitle,
    colorBlindBody,
    markCorrect,
    markDifferent,
    markUnheard,
    markPending,
    lastNote,
  ];

  static UiCopy mark(PracticeMark mark) => switch (mark) {
    PracticeMark.pending => markPending,
    PracticeMark.correct => markCorrect,
    PracticeMark.differentNote => markDifferent,
    PracticeMark.couldNotHear => markUnheard,
  };
}

/// What a screen reader says for one mark: "Correct", "Different note",
/// "Couldn't hear" or "Not played yet". Never "wrong".
String practiceMarkLabel(BuildContext context, PracticeMark mark) =>
    uiText(context, PracticeDisplayCopy.mark(mark));
