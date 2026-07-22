/**
 * Free-plan usage limits. Both enforcement points (analyzeDocument.js,
 * askTutor.js) import from here so the two numbers only ever live in one
 * place — see subscription_screen.dart's PlanCatalog.freeFeatures for the
 * matching user-facing copy, which is NOT auto-synced with these and needs
 * updating by hand if these change.
 */
const FREE_DOCUMENT_LIMIT = 3; // lifetime, not per-month
const FREE_AI_TUTOR_MONTHLY_LIMIT = 10; // resets every calendar month (UTC)

/**
 * True if the user currently has an active, unexpired premium
 * subscription. Mirrors the same status+renewsAt check the subscription
 * screen itself uses (lib/features/subscription/subscription_screen.dart)
 * so "premium" means the same thing everywhere.
 */
function isPremiumActive(userData) {
  const sub = userData?.subscription;
  if (!sub || sub.status !== "active") return false;
  const renewsAt = sub.renewsAt?.toDate?.();
  return !!renewsAt && renewsAt > new Date();
}

/** "YYYY-MM" in UTC — used as the dedupe/reset key for the AI Tutor's monthly counter. */
function currentMonthKey(date = new Date()) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

module.exports = {
  FREE_DOCUMENT_LIMIT,
  FREE_AI_TUTOR_MONTHLY_LIMIT,
  isPremiumActive,
  currentMonthKey,
};
