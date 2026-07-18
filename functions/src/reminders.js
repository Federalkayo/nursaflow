const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { createNotification } = require("./notifications");

// How often this function runs — kept as a named constant since the
// "due" window below (isDue's toleranceMinutes) is derived from it.
const SCHEDULE = "every 15 minutes";

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

/**
 * True if `nowHHmm` is within `toleranceMinutes` of `targetHHmm`, wrapping
 * around midnight. Cloud Scheduler's actual fire time can drift a little
 * from the nominal cron slot, and a user's chosen reminderTime won't
 * generally land exactly on a 15-minute boundary anyway — a ~7 minute
 * tolerance (half the schedule interval) means every reminderTime gets
 * caught by exactly one run per day without double-firing.
 */
function isDue(nowHHmm, targetHHmm, toleranceMinutes = 7) {
  const toMinutes = (hhmm) => {
    const [h, m] = hhmm.split(":").map(Number);
    return h * 60 + m;
  };
  const diff = Math.abs(toMinutes(nowHHmm) - toMinutes(targetHHmm));
  return Math.min(diff, 1440 - diff) <= toleranceMinutes;
}

/**
 * Runs on SCHEDULE and, for each user with reminders enabled whose local
 * time currently matches their chosen reminderTime, sends exactly one push
 * for the day — a "protect your streak" nudge if they logged study time
 * yesterday but not yet today, otherwise the plain daily reminder.
 *
 * Requires `timezone` (IANA string, e.g. "Africa/Lagos") and `reminderTime`
 * ("HH:mm") on users/{uid}; both are written client-side —
 * see PushNotificationsService for timezone and
 * setReminderSettings() in study_stats.dart for reminderTime.
 * `lastReminderSentDate` is bookkeeping this function owns; nothing else
 * should write to it.
 */
const sendDueReminders = onSchedule(SCHEDULE, async () => {
  const db = admin.firestore();
  const now = new Date();

  const dueUsers = await db.collection("users").where("reminderEnabled", "==", true).get();

  await Promise.all(
    dueUsers.docs.map(async (userDoc) => {
      const { timezone, reminderTime, lastReminderSentDate } = userDoc.data();
      if (!timezone || !reminderTime) return;

      let nowHHmm, todayKey;
      try {
        nowHHmm = hhmmInZone(now, timezone);
        todayKey = dateKeyInZone(now, timezone);
      } catch (err) {
        logger.warn(`Invalid timezone "${timezone}" for user ${userDoc.id}`, err);
        return;
      }

      if (lastReminderSentDate === todayKey) return; // already handled today
      if (!isDue(nowHHmm, reminderTime)) return;

      try {
        const lastLogSnap = await userDoc.ref
          .collection("studyLog")
          .orderBy("loggedAt", "desc")
          .limit(1)
          .get();

        const lastLoggedAt = lastLogSnap.docs[0]?.data()?.loggedAt?.toDate?.();
        const lastLoggedKey = lastLoggedAt ? dateKeyInZone(lastLoggedAt, timezone) : null;

        if (lastLoggedKey !== todayKey) {
          const yesterdayKey = dateKeyInZone(
            new Date(now.getTime() - 24 * 60 * 60 * 1000),
            timezone,
          );
          const hasActiveStreak = lastLoggedKey === yesterdayKey;

          if (hasActiveStreak) {
            await createNotification(userDoc.id, {
              type: "streak",
              title: "🔥 Keep your streak alive",
              body: "You haven't studied yet today — a few minutes now keeps your streak going.",
            });
          } else {
            await createNotification(userDoc.id, {
              type: "dailyReminder",
              title: "Time to revise 📚",
              body: "A few focused minutes now beats a cram session later.",
            });
          }
        }
        // else: already studied today — no nudge needed, just mark as handled below.

        await userDoc.ref.set({ lastReminderSentDate: todayKey }, { merge: true });
      } catch (err) {
        logger.error(`Reminder check failed for user ${userDoc.id}`, err);
      }
    }),
  );
});

module.exports = { sendDueReminders };
