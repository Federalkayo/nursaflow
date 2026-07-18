const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { notifyPaymentUpdate } = require("./notifications");

/**
 * STUB — deliberately NOT exported from index.js yet. Paystack integration
 * doesn't exist anywhere else in this codebase yet either (subscription_screen.dart
 * just has a "Paystack checkout would open here" placeholder), so this has
 * nothing real to verify against.
 *
 * Before wiring this in:
 *   1. Verify the `x-paystack-signature` header — HMAC-SHA512 of the raw
 *      request body using your Paystack secret key — and reject on mismatch.
 *      Skipping this means anyone can POST a fake "payment succeeded" event.
 *   2. Map the event to a Firebase uid. Easiest: set `metadata.uid` when you
 *      initialize the Paystack transaction, then read it back here from
 *      `event.data.metadata.uid`.
 *   3. Update users/{uid}.subscription (status, plan, renewsAt — whatever
 *      shape subscription_screen.dart ends up reading) in Firestore.
 *   4. Call notifyPaymentUpdate(uid, { status, planName }) — already wired
 *      to send an FCM push, see functions/src/notifications.js.
 * Then add `exports.paystackWebhook = paystackWebhook;` to index.js and
 * point the Paystack dashboard's webhook URL at the deployed function.
 */
const paystackWebhook = onRequest(async (req, res) => {
  logger.warn("paystackWebhook was called but is not implemented — see file header before wiring this up");
  res.status(501).send("Not implemented");

  // Once signature verification + uid mapping above are done, something like:
  //
  // const event = req.body;
  // const uid = event?.data?.metadata?.uid;
  // if (uid) {
  //   await notifyPaymentUpdate(uid, {
  //     status: event.event === "charge.success" ? "activated" : "updated",
  //     planName: event.data?.plan?.name,
  //   });
  // }
});

module.exports = { paystackWebhook };
