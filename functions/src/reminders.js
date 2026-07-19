const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { createNotification } = require("./notifications");
const { sendEmail, dailyReminderEmailHtml, resendApiKey } = require("./email");
const { hhmmInZone, dateKeyInZone, isDue } = require("./timeUtils");

// How often this function runs — kept as a named constant since the
// "due" window below (isDue's toleranceMinutes) is derived from it.
const SCHEDULE = "every 15 minutes";

/**
 * Runs on SCHEDULE and, for each user with reminders enabled whose local
 * time currently matches their chosen reminderTime, sends exactly one push
 * (and, unless they've opted out, one email) for the day — a "protect your
 * streak" nudge if they logged study time yesterday but not yet today,
 * otherwise the plain daily reminder.
 *
 * Requires `timezone` (IANA string, e.g. "Africa/Lagos") and `reminderTime`
 * ("HH:mm") on users/{uid}; both are written client-side —
 * see PushNotificationsService for timezone and
 * setReminderSettings() in study_stats.dart for reminderTime.
 * `lastReminderSentDate` is bookkeeping this function owns; nothing else
 * should write to it. Email delivery additionally requires `email` (already
 * saved at signup) and respects `emailNotificationsEnabled` (default true —
 * see the "Also email me" toggle in study_planner_screen.dart).
 */
const sendDueReminders = onSchedule({ schedule: SCHEDULE, secrets: [resendApiKey] }, async () => {
  const db = admin.firestore();
  const now = new Date();

  const dueUsers = await db.collection("users").where("reminderEnabled", "==", true).get();

  await Promise.all(
    dueUsers.docs.map(async (userDoc) => {
      const userData = userDoc.data();
      const { timezone, reminderTime, lastReminderSentDate } = userData;
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
          const kind = hasActiveStreak ? "streak" : "dailyReminder";

          const title = hasActiveStreak
            ? "🔥 Keep your streak alive"
            : "Time to revise 📚";
          const body = hasActiveStreak
            ? "You haven't studied yet today — a few minutes now keeps your streak going."
            : "A few focused minutes now beats a cram session later.";

          await createNotification(userDoc.id, { type: kind, title, body });

          if (userData.emailNotificationsEnabled !== false && userData.email) {
            try {
              await sendEmail({
                to: userData.email,
                subject: title,
                html: dailyReminderEmailHtml({ name: userData.name, kind }),
              });
            } catch (err) {
              // Same principle as the push send in createNotification: an
              // email failure shouldn't stop the push above from having
              // already gone out, or block marking the day as handled.
              logger.warn(`Reminder email failed for user ${userDoc.id}`, err);
            }
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
