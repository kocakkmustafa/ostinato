/// Founder decision 2026-10-23: subscriptions are sold in the first release
/// (the app's own subscription and the shared Motion+ plan). Core keeps its own
/// default closed; Ostinato opts in here, in one place, for the account page,
/// the paid-access gate and the membership page it opens.
const bool ostinatoPaidFeaturesAvailable = true;

/// Live camera practice stays closed in this release (unchanged).
const bool ostinatoCameraPracticeAvailable = false;
