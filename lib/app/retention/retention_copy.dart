import '../ui_copy.dart';

/// User copy of the weekly goal card (F5.2). Every pair is also listed in
/// `content/ui/retention.json` for the message-id table and translators;
/// `test/ui_copy_catalog_test.dart` keeps the two in step.
abstract final class RetentionCopy {
  static const UiCopy kicker = ('THIS WEEK', 'BU HAFTA');
  static const UiCopy progress = (
    '{v0} of {v1} sessions',
    '{v1} oturumdan {v0}',
  );
  static const UiCopy met = (
    "This week's goal is done.",
    'Bu haftanın hedefi tamam.',
  );
  static const UiCopy daysLeft = (
    'Days left this week: {v0}',
    'Bu hafta kalan gün: {v0}',
  );
  static const UiCopy streak = ('Weekly streak: {v0}', 'Haftalık seri: {v0}');
  static const UiCopy freezes = ('Freezes: {v0}', 'Dondurma hakkı: {v0}');
  static const UiCopy startStreak = (
    "Meet this week's goal to start a weekly streak.",
    'Haftalık seriyi başlatmak için bu haftanın hedefini tamamla.',
  );
  static const UiCopy rules = (
    'Each day you practise counts as one session. A freeze covers a short week automatically; every 5 goal weeks add one. This stays on this device.',
    'Çalıştığın her gün bir oturum sayılır. Dondurma hakkı eksik kalan haftayı kendiliğinden korur; hedefi tutan her 5 hafta bir hak ekler. Bu bilgi cihazında kalır.',
  );
  static const UiCopy offApp = (
    'I played outside the app',
    'Uygulama dışında çaldım',
  );
  static const UiCopy offAppSaved = (
    'Saved for today.',
    'Bugün için kaydedildi.',
  );
  static const UiCopy goalButton = ('Weekly goal', 'Haftalık hedef');
  static const UiCopy goalTitle = ('Sessions per week', 'Haftada oturum');
  static const UiCopy goalNote = (
    'A new goal applies from this week.',
    'Yeni hedef bu haftadan itibaren geçerli.',
  );
  static const UiCopy voiceRest = (
    'Voice rest day today',
    'Bugün ses dinlenme günü',
  );
  static const UiCopy voiceRestNote = (
    'Voice course: a rest day never breaks the streak. It counts toward the goal, but one session a week is still needed.',
    'Ses kursu: dinlenme günü seriyi bozmaz. Hedefe sayılır, ama haftada en az bir oturum yine gerekir.',
  );
  static const UiCopy saveFailed = (
    'Could not save. Try again.',
    'Kaydedilemedi. Yeniden dene.',
  );

  static const List<UiCopy> all = [
    kicker,
    progress,
    met,
    daysLeft,
    streak,
    freezes,
    startStreak,
    rules,
    offApp,
    offAppSaved,
    goalButton,
    goalTitle,
    goalNote,
    voiceRest,
    voiceRestNote,
    saveFailed,
  ];
}
