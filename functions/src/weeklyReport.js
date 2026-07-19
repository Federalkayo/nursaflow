const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { sendEmail, weeklyReportEmailHtml, resendApiKey } = require("./email");
const { hhmmInZone, dateKeyInZone, weekdayInZone, isDue } = require("./timeUtils");

// Runs hourly rather than every 15 min like reminders.js — a weekly email
// doesn't need tight timing, and this keeps invocation volume down.
const SCHEDULE = "every 60 minutes";
const REPORT_WEEKDAY = "Mon";
const REPORT_TIME = "09:00"; // in each user's own local timezone

/**
 * Runs on SCHEDULE and, once a week (Monday ~9am local time, per user
 * timezone), emails anyone with emailNotificationsEnabled a summary of
 * their last 7 days: total study minutes, days studied, documents
 * analyzed. Reuses the same `timezone` field the daily reminder relies on
 * — see functions/src/reminders.js — so a user who has never opened the
 * app (no timezone saved yet) is silently skipped rather than guessed at.
 *
 * `lastWeeklyReportSentDate` is bookkeeping this function owns, separate
 * from `lastReminderSentDate` so the two features can't interfere with
 * each other's dedupe state.
 */
const sendWeeklyReports = onSchedule({ schedule: SCHEDULE, secrets: [resendApiKey] }, async () => {
  const db = admin.firestore();
  const now = new Date();

  // emailNotificationsEnabled is opt-OUT (undefined/missing means enabled),
  // but Firestore's `!=` operator excludes documents where the field is
  // missing entirely — which is every user who's never touched the toggle.
  // A `!= false` query would silently skip almost everyone. Filtering
  // in-memory is the only correct option here; this scans the full users
  // collection once an hour, which is acceptable for this app's scale but
  // worth revisiting (e.g. a maintained `emailOptOut: true`-only index) if
  // the user base grows large enough for the read cost to matter.
  const usersSnap = await db.collection("users").get();

  await Promise.all(
    usersSnap.docs.map(async (userDoc) => {
      const userData = userDoc.data();
      const { timezone, email, lastWeeklyReportSentDate } = userData;
      if (!timezone || !email) return;
      if (userData.emailNotificationsEnabled === false) return;

      let nowHHmm, todayKey, weekday;
      try {
        nowHHmm = hhmmInZone(now, timezone);
        todayKey = dateKeyInZone(now, timezone);
        weekday = weekdayInZone(now, timezone);
      } catch (err) {
        logger.warn(`Invalid timezone "${timezone}" for user ${userDoc.id}`, err);
        return;
      }

      if (weekday !== REPORT_WEEKDAY) return;
      if (lastWeeklyReportSentDate === todayKey) return; // already sent this week
      if (!isDue(nowHHmm, REPORT_TIME, 30)) return; // wider tolerance — hourly schedule, no urgency

      try {
        const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
          new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000),
        );
        const logSnap = await userDoc.ref
          .collection("studyLog")
          .where("loggedAt", ">=", sevenDaysAgo)
          .get();

        const totalMinutes = logSnap.docs.reduce((sum, d) => sum + (d.data().minutes || 0), 0);
        const daysStudied = new Set(
          logSnap.docs
            .map((d) => d.data().loggedAt?.toDate?.())
            .filter(Boolean)
            .map((date) => dateKeyInZone(date, timezone)),
        ).size;

        const docsSnap = await userDoc.ref
          .collection("documents")
          .where("createdAt", ">=", sevenDaysAgo)
          .get()
          .catch(() => null); // documents subcollection's createdAt field name isn't guaranteed here — degrade to 0 rather than fail the whole report
        const documentsAnalyzed = docsSnap?.size ?? 0;

        // Skip emailing users with zero activity — a report full of zeros
        // isn't useful and reads as spam.
        if (totalMinutes > 0 || documentsAnalyzed > 0) {
          await sendEmail({
            to: email,
            subject: "Your NursaFlow week in review",
            html: weeklyReportEmailHtml({
              name: userData.name,
              totalMinutes,
              daysStudied,
              documentsAnalyzed,
            }),
          });
        }

        await userDoc.ref.set({ lastWeeklyReportSentDate: todayKey }, { merge: true });
      } catch (err) {
        logger.error(`Weekly report failed for user ${userDoc.id}`, err);
      }
    }),
  );
});

module.exports = { sendWeeklyReports };
