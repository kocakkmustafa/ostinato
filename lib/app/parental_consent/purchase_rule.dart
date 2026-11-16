import 'package:motion_account/motion_account.dart';

/// Purchase decision of one signed-in account (ADR-008 §6-3).
///
/// With [parentalConsentOpen] false the answer is exactly today's rule
/// (`ostinatoTeenPurchasePolicy`, under 13 never buys). With it true an
/// under-13 account may reach the purchase only when its parent consent is
/// `approved`, and the payment itself stays with the store's family controls
/// (Ask to Buy / Google Play parental approval). Any other state, including
/// `withdrawn`, closes it.
({bool restricted, bool storeDecides}) ostinatoPurchaseDecision(
  MotionAgeStatus? age,
  DateTime today,
  MotionTeenPurchasePolicy policy, {
  required bool parentalConsentOpen,
}) {
  if (age == null) return (restricted: false, storeDecides: false);
  final restricted = age.purchaseRestrictedOn(
    today,
    policy,
    underThirteenConsent: parentalConsentOpen,
  );
  var storeDecides = age.storeDecidesPurchaseOn(
    today,
    policy,
    underThirteenConsent: parentalConsentOpen,
  );
  if (parentalConsentOpen &&
      !restricted &&
      age.bandOn(today, underThirteenConsent: true) ==
          MotionAgeBand.underThirteenConsentRequired) {
    storeDecides = true;
  }
  return (restricted: restricted, storeDecides: storeDecides);
}
