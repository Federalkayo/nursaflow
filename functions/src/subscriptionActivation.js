const admin = require("firebase-admin");
const { logger } = require("firebase-functions");
const { notifyPaymentUpdate } = require("./notifications");
const { sendEmail, receiptEmailHtml } = require("./email");

const CYCLE_DAYS = { monthly: 30, annual: 365 };
const CYCLE_LABEL = { monthly: "Monthly", annual: "Annual" };

/**
 * Activates a user's subscription after a successful Paystack charge.
 *
 * Called from two places:
 *  - paystackWebhook.js — the source of truth, always fires eventually
 *    per Paystack's retry policy, regardless of what the client does.
 *  - paystackVerify.js — a client-side fast path, called the instant the
 *    WebView sees Paystack's callback redirect, often seconds before the
 *    webhook arrives.
 *
 * Both can legitimately race for the same `reference`. This function is
 * written to be safe to call twice for the same reference: the Firestore
 * write is idempotent (same data either time), and the push/email
 * side-effects are skipped on the second call so the user only gets
 * notified once.
 *
 * Throws on a genuine failure (e.g. the Firestore write itself failing) —
 * callers should catch and log, not let it bubble to the user unhandled.
 */
async function activateSubscription({ uid, cycle, reference, amount }) {
  if (!uid || !CYCLE_DAYS[cycle]) {
    throw new Error(`activateSubscription: invalid uid/cycle (uid=${uid}, cycle=${cycle})`);
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);

  const before = await userRef.get();
  const alreadyProcessed = before.data()?.subscription?.lastPaymentReference === reference;

  const planName = CYCLE_LABEL[cycle];
  const renewsAt = new Date(Date.now() + CYCLE_DAYS[cycle] * 24 * 60 * 60 * 1000);

  if (!alreadyProcessed) {
    await userRef.set(
      {
        subscription: {
          status: "active",
          plan: cycle,
          lastPaymentReference: reference,
          lastPaymentAmount: amount,
          renewsAt: admin.firestore.Timestamp.fromDate(renewsAt),
        },
      },
      { merge: true },
    );
  }

  if (alreadyProcessed) {
    logger.info(`activateSubscription: reference ${reference} already processed for user ${uid} — skipping duplicate notify`);
    return { alreadyProcessed: true, planName, renewsAt };
  }

  await notifyPaymentUpdate(uid, { status: "activated", planName }).catch((err) =>
    logger.warn(`activateSubscription: push notify failed for user ${uid}`, err),
  );

  try {
    const userDoc = await userRef.get();
    const { email, name } = userDoc.data() || {};
    if (email) {
      await sendEmail({
        to: email,
        subject: "Payment received — NursaFlow Premium",
        html: receiptEmailHtml({
          name,
          amount,
          planName,
          reference,
          renewsAt: renewsAt.toDateString(),
        }),
        category: "receipt",
      });
    }
  } catch (err) {
    logger.warn(`activateSubscription: receipt email failed for user ${uid}`, err);
  }

  return { alreadyProcessed: false, planName, renewsAt };
}

module.exports = { activateSubscription, CYCLE_DAYS, CYCLE_LABEL };
