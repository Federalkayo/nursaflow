const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { createNotification } = require("./notifications");
const { sendEmail, expiryReminderEmailHtml, resendApiKey } = require("./email");

const SCHEDULE = "every 60 minutes";
const REMINDER_WINDOW_DAYS = 3;

/**
 * Runs hourly and, once per subscription cycle, nudges users whose Premium
 * plan is about to lapse. This matters because paystack.js is a ONE-TIME
 * CHARGE model, not an auto-renewing Paystack subscription (see that
 * file's header) — without this reminder, a user's access would just
 * silently drop back to Free with zero warning once `renewsAt` passes.
 *
 * Dedupe: `subscription.reminderSentForRenewsAt` records which renewsAt
 * value was last reminded about. A fresh payment sets a new renewsAt (see
 * paystackWebhook.js), which automatically makes this eligible to fire
 * again for the new cycle — no separate reset logic needed.
 */
const sendExpiryReminders = onSchedule({ schedule: SCHEDULE, secrets: [resendApiKey] }, async () => {
  const db = admin.firestore();
  const now = new Date();
  const windowEnd = new Date(now.getTime() + REMINDER_WINDOW_DAYS * 24 * 60 * 60 * 1000);

  const activeUsersSnap = await db.collection("users").where("subscription.status", "==", "active").get();

  await Promise.all(
    activeUsersSnap.docs.map(async (userDoc) => {
      const userData = userDoc.data();
      const sub = userData.subscription;
      const renewsAt = sub?.renewsAt?.toDate?.();
      if (!renewsAt) return;

      // Already expired, or still further out than the reminder window —
      // nothing to do yet either way.
      if (renewsAt <= now || renewsAt > windowEnd) return;

      const renewsAtKey = renewsAt.toISOString();
      if (sub.reminderSentForRenewsAt === renewsAtKey) return; // already reminded this cycle

      const daysLeft = Math.max(1, Math.ceil((renewsAt - now) / (24 * 60 * 60 * 1000)));
      const planName = sub.plan === "annual" ? "Annual" : "Monthly";

      try {
        await createNotification(userDoc.id, {
          type: "subscription",
          title: "Your Premium plan expires soon",
          body: `Your ${planName} plan expires in ${daysLeft} day${daysLeft === 1 ? "" : "s"} — renew to keep unlimited access.`,
        });

        if (userData.emailNotificationsEnabled !== false && userData.email) {
          await sendEmail({
            to: userData.email,
            subject: "Your NursaFlow Premium plan expires soon",
            html: expiryReminderEmailHtml({ name: userData.name, daysLeft, planName }),
            category: "reminder",
          }).catch((err) => logger.warn(`Expiry reminder email failed for user ${userDoc.id}`, err));
        }

        // Dot-notation merge — only touches this one nested field, leaves
        // status/plan/renewsAt/lastPaymentReference etc. exactly as-is.
        await userDoc.ref.set(
          { "subscription.reminderSentForRenewsAt": renewsAtKey },
          { merge: true },
        );
      } catch (err) {
        logger.error(`Expiry reminder failed for user ${userDoc.id}`, err);
      }
    }),
  );
});

module.exports = { sendExpiryReminders };
