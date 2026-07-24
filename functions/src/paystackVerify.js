const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { paystackSecretKey } = require("./paystack");
const { resendApiKey } = require("./email");
const { activateSubscription, CYCLE_DAYS } = require("./subscriptionActivation");

/**
 * Client-side fast path: called by the Flutter WebView the instant
 * Paystack redirects to the callback_url after a successful charge (see
 * initializePaystackTransaction's callback_url in paystack.js, and the
 * NavigationDelegate in _PaystackCheckoutPageState in
 * subscription_screen.dart).
 *
 * This hits Paystack's own /transaction/verify endpoint directly rather
 * than trusting the redirect alone, so a WebView simply navigating to a
 * right-looking URL can't fake a payment — Paystack's servers are the
 * actual source of truth here, same as the webhook.
 *
 * paystackWebhook.js remains the primary/durable activation path and will
 * still fire independently; this exists purely to close the gap between
 * "payment completed" and "webhook delivered", which is what was causing
 * the WebView to sit there after payment. activateSubscription() is
 * written to be safe if both this and the webhook process the same
 * reference.
 */
const verifyPaystackTransaction = onCall(
  { secrets: [paystackSecretKey, resendApiKey] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Must be signed in to verify a payment.");
    }

    const reference = request.data?.reference;
    if (!reference || typeof reference !== "string") {
      throw new HttpsError("invalid-argument", "A transaction reference is required.");
    }

    const res = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
      { headers: { Authorization: `Bearer ${paystackSecretKey.value()}` } },
    );
    const json = await res.json();

    if (!res.ok || json?.data?.status !== "success") {
      logger.warn(`verifyPaystackTransaction: reference ${reference} not successful`, json?.data?.status);
      throw new HttpsError("failed-precondition", "Payment has not completed successfully yet.");
    }

    const { uid: metaUid, cycle } = json.data.metadata || {};

    // The reference must belong to the calling user — never trust
    // metadata without this check, or one user could replay a reference
    // they observed elsewhere and activate someone else's payment onto
    // their own account.
    if (metaUid !== uid) {
      logger.error(`verifyPaystackTransaction: uid mismatch — caller ${uid}, metadata ${metaUid}`);
      throw new HttpsError("permission-denied", "This transaction does not belong to you.");
    }

    if (!CYCLE_DAYS[cycle]) {
      logger.error("verifyPaystackTransaction: verified charge missing valid cycle", json.data.metadata);
      throw new HttpsError("internal", "Payment verified but plan details are missing.");
    }

    const { planName, renewsAt } = await activateSubscription({
      uid,
      cycle,
      reference,
      amount: json.data.amount,
    });

    return { activated: true, planName, renewsAt: renewsAt.toISOString() };
  },
);

module.exports = { verifyPaystackTransaction };
