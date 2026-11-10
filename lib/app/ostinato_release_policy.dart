import 'package:motion_account/motion_account.dart';

/// Founder decision 2026-10-23: subscriptions are sold in the first release.
/// Core keeps its own default closed; Ostinato opts in here, in one place, for
/// the account page, the paid-access gate and the membership page it opens.
const bool ostinatoPaidFeaturesAvailable = true;

/// Founder decision 2026-11-02: the v1 store submission sells only the two
/// Ostinato plans (monthly, yearly); Motion+ is neither offered nor mentioned.
/// While false the app opens its own `OstinatoMembershipPage` (Ostinato
/// products only) instead of Core's page, which always shows a Motion+
/// section. A Motion+ right the server already verified still unlocks paid
/// lessons: entitlement checks are unchanged.
const bool ostinatoMotionPlusOffered = false;

/// v1 store scope (founder, 2026-11-02): the guitar course (v1, 240 lessons)
/// is open; voice and piano show "Coming soon". The pre-v1 written courses
/// (60-lesson guitar journey, ukulele 24, bass 24, voice 22, piano 25) and
/// the written recall page that links to them are not reachable from the
/// home, library or guitar page. Their code and stored progress stay; this
/// flag only removes the entry points.
const bool ostinatoLegacyWrittenCoursesVisible = false;

/// v1 store scope (founder, 2026-11-02; store review screens 38–42): only
/// these instruments open their course in this release. Any other
/// instrument page (voice, piano) is a simple "Coming soon" page that says
/// what the course will cover and opens no lessons; the earlier posture
/// reference "Foundations" courses are not reachable from it.
const Set<String> ostinatoOpenInstruments = {'guitar'};

/// Founder decision 2026-11-03 ("first microphone measurement, then open"):
/// the v1 ear training course (50 lessons) opens once its drills, clapping
/// lines and part-by-part tests are measured. Ear training is a course, not
/// an instrument: it has its own home card. Free scope: level 1
/// (`ostinatoV1FreeStages`).
const bool ostinatoEarTrainingOpen = true;

/// Store review 2026-11-02 (screens 06–08): the instrument page carried long
/// engineering notes (posture-reference catalogue, teacher agreement, engine
/// history, "what we do not judge", "not here and why"). They stay in the
/// code and content for development builds; while false the page shows one
/// short line instead.
const bool ostinatoEngineeringNotesVisible = false;

/// Live camera practice stays closed in this release (unchanged).
const bool ostinatoCameraPracticeAvailable = false;

/// K8 (founder 2026-11-01, scope approved 2026-11-04): the camera part of
/// the v1 camera lessons (`camera_lesson.dart`). Opens in 1.0.3; false
/// keeps 1.0.2 exactly as before (checklist only). Independent of Core's
/// `motionCameraCoachingAvailable` and of the live camera practice above.
const bool ostinatoCameraLessonsOpen = false;

/// OST-P0-06 (founder, 2026-11-08, "Dört ürün ana talimatı" §7.1–§7.4):
/// the "listen → try → fix → repeat" loop inside the existing measured
/// lessons. When true the practice result shows ONE measured correction (or
/// "I could not tell this sound apart with confidence" when the signal is
/// weak), a stepped tempo repeat and a next exercise taken from the kind of
/// difference. Nothing is judged "wrong"; nothing is recorded or sent.
/// While false the practice screen and its result are exactly as in 1.0.2.
/// Rollback: leave this false (or revert the PR); no data depends on it.
const bool ostinatoListenTryFixRepeatOpen = false;

/// OST-P0-07 (founder, 2026-11-08, "Dört ürün ana talimatı" §7.4): the
/// "ghost screen" on the existing practice screen. When true a small switch
/// lets the player fade the guides (written line, "Listen first", visual
/// beat) as measured practice repeats; "Show guides" brings them back at any
/// time and start/stop stay reachable. Nothing is stored beyond the session
/// and no skill is claimed. While false the practice screen is exactly as
/// before. Rollback: leave this false (or revert the PR); no data depends on it.
const bool ostinatoGhostScreenOpen = false;

/// OST-P0-08: recording-retention surface (audience gate for the own-take
/// recorder, background discard, "delete all"). False keeps today's FK2
/// behaviour exactly. Even when true nothing is ever stored persistently:
/// encrypted storage and export are a separate ticket (OST-P0-08B).
const bool ostinatoRecordingRetentionOpen = false;

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

/// OST-P0-05 (founder master instruction 2026-11-08, section 7.4): the "first
/// three minutes" flow, shown once after the welcome pages: tap the rhythm
/// (no microphone permission), use your voice (permission asked at the moment
/// of use, with a blameless return to tapping) or go straight to the library.
/// Closed by default: while false the first launch is exactly the welcome
/// pages followed by the library. Rollback: set this to false (or revert the
/// PR); nothing is stored by the flow, so there is nothing to migrate.
const bool ostinatoFirstThreeMinutesOpen = false;

/// OST-UX-04 (founder master instruction 2026-11-09, "Dört ürün ana
/// talimatı" §7 stage 6): an interactive PROTOTYPE of the seven core
/// journeys on the "one stage" design (ADR-UX-001). It lives apart in
/// `lib/app/ux_prototype/`, uses sample data labelled "Prototype", records
/// nothing, listens to nothing and never touches the camera. While false
/// (default) there is no entry to it anywhere and the app is exactly as
/// before. The single entry is a button in Settings. Rollback: leave this
/// false (or revert the PR); no data depends on it.
const bool ostinatoUxPrototypeOpen = false;
