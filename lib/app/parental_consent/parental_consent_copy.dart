import '../ui_copy.dart';

/// ADR-008 parent-approval screen copy that Core's account strings do not
/// cover. EN and TR source pairs only; the other twelve languages fall back
/// to English until the reviewed translations are added (the screen sits
/// behind `ostinatoParentalConsentEnabled`, closed). Everything else on the
/// screen reuses Core's fourteen-language `MotionAccountString` copy.
/// Neutral wording: no "wrong", no "soon", no blame.
abstract final class ParentalConsentCopy {
  static const UiCopy checkApproval = ('Check approval', 'Onayı kontrol et');
  static const UiCopy dailyLimit = (
    'Too many requests were sent today. Please try again tomorrow.',
    'Bugün çok fazla istek gönderildi. Lütfen yarın tekrar dene.',
  );
  static const UiCopy unavailable = (
    'We could not reach Yula Lab just now. Nothing was changed. Please try again later.',
    'Şu anda Yula Lab’a ulaşılamadı. Hiçbir şey değişmedi. Lütfen daha sonra tekrar dene.',
  );
  static const UiCopy approved = (
    'Your parent or guardian approved. You can create your account now.',
    'Velin onayladı. Artık hesabını oluşturabilirsin.',
  );
  static const UiCopy denied = (
    'A decision was recorded for this request. An account can’t be created on this device.',
    'Bu istek için bir karar kaydedildi. Bu cihazda hesap oluşturulamıyor.',
  );

  static const List<UiCopy> all = [
    checkApproval,
    dailyLimit,
    unavailable,
    approved,
    denied,
  ];
}
