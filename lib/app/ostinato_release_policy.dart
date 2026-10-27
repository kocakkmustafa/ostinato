import 'package:motion_account/motion_account.dart';

/// Founder decision 2026-10-23: subscriptions are sold in the first release
/// (the app's own subscription and the shared Motion+ plan). Core keeps its own
/// default closed; Ostinato opts in here, in one place, for the account page,
/// the paid-access gate and the membership page it opens.
const bool ostinatoPaidFeaturesAvailable = true;

/// Live camera practice stays closed in this release (unchanged).
const bool ostinatoCameraPracticeAvailable = false;

/// Founder decision 2026-10-25 (OST-K1): a 13–17 account still waiting for
/// parental consent sees the subscription offers, and the purchase itself is
/// left to the store's family controls (Ask to Buy / Google Play parental
/// approval). Core R4 keeps its own default closed; Ostinato opts in here for
/// the account page, the paid-access gate and the camera gate. Account
/// features stay closed until consent and under-13 accounts cannot buy.
const MotionTeenPurchasePolicy ostinatoTeenPurchasePolicy =
    MotionTeenPurchasePolicy.storeFamilyControls;
