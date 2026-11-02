import 'package:motion_account/motion_account.dart';

/// Founder decision 2026-10-23: subscriptions are sold in the first release
/// (the app's own subscription and the shared Motion+ plan). Core keeps its own
/// default closed; Ostinato opts in here, in one place, for the account page,
/// the paid-access gate and the membership page it opens.
const bool ostinatoPaidFeaturesAvailable = true;

/// v1 store scope (founder, 2026-11-02): the guitar course (v1, 240 lessons)
/// is open; voice and piano show "Coming soon". The pre-v1 written courses
/// (60-lesson guitar journey, ukulele 24, bass 24, voice 22, piano 25) and
/// the written recall page that links to them are not reachable from the
/// home, library or guitar page. Their code and stored progress stay; this
/// flag only removes the entry points.
const bool ostinatoLegacyWrittenCoursesVisible = false;

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

/// K16 progress sync (founder decision 2026-11-01: in v1, local-first). Closed
/// until the schema, identity and store-label changes are approved; nothing
/// reads `lib/app/sync/` yet and no network call exists for it.
const bool ostinatoProgressSyncAvailable = false;
