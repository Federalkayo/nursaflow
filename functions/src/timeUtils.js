/**
 * Shared helpers for the per-user, timezone-aware scheduled functions
 * (functions/src/reminders.js, functions/src/weeklyReport.js). Both compare
 * "now" against a time the user picked in their own local timezone, so the
 * comparison logic lives here once instead of twice.
 */

/** "HH:mm" (24h) for `date` in the given IANA zone, e.g. "Africa/Lagos". */
function hhmmInZone(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const hour = parts.find((p) => p.type === "hour")?.value;
  const minute = parts.find((p) => p.type === "minute")?.value;
  return `${hour}:${minute}`;
}

/** "YYYY-MM-DD" for `date` in the given IANA zone — used as a per-day dedupe key. */
function dateKeyInZone(date, timeZone) {
  return new Intl.DateTimeFormat("en-CA", { timeZone }).format(date);
}

/** Short weekday ("Mon", "Tue", ...) for `date` in the given IANA zone. */
function weekdayInZone(date, timeZone) {
  return new Intl.DateTimeFormat("en-US", { timeZone, weekday: "short" }).format(date);
}

/**
 * True if `nowHHmm` is within `toleranceMinutes` of `targetHHmm`, wrapping
 * around midnight. Cloud Scheduler's actual fire time can drift a little
 * from the nominal cron slot, and a user's chosen time won't generally land
 * exactly on a schedule boundary anyway — a tolerance of roughly half the
 * calling function's schedule interval means the target time gets caught by
 * exactly one run per day without double-firing.
 */
function isDue(nowHHmm, targetHHmm, toleranceMinutes = 7) {
  const toMinutes = (hhmm) => {
    const [h, m] = hhmm.split(":").map(Number);
    return h * 60 + m;
  };
  const diff = Math.abs(toMinutes(nowHHmm) - toMinutes(targetHHmm));
  return Math.min(diff, 1440 - diff) <= toleranceMinutes;
}

module.exports = { hhmmInZone, dateKeyInZone, weekdayInZone, isDue };
