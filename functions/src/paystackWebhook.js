const crypto = require("crypto");
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { paystackSecretKey } = require("./paystack");
const { resendApiKey } = require("./email");
const { activateSubscription, CYCLE_DAYS } = require("./subscriptionActivation");

/**
 * Point Paystack's dashboard webhook URL at this function's deployed URL
 * once it's live. This is a ONE-TIME-CHARGE model (see paystack.js) —
 * `charge.success` is the only event that matters; there's no
 * `subscription.*` event to handle since nothing here uses Paystack's
 * Subscription/Plan API.
 *
 * This is the source-of-truth activation path: it always fires
 * (eventually, per Paystack's retry policy) regardless of what the client
 * does. There's also a faster client-side path — paystackVerify.js,
 * called by the WebView the instant it sees Paystack's callback redirect —
 * that races this one for the same reference. See
 * subscriptionActivation.js for how both are kept safe to fire together.
 */
const paystackWebhook = onRequest(
  { secrets: [paystackSecretKey, resendApiKey] },
  async (req, res) => {
    // req.rawBody (raw, unparsed bytes) is what Paystack's signature was
    // computed over — verifying against req.body (already JSON-parsed)
    // would fail even for genuine requests, since re-serializing JSON
    // isn't guaranteed to reproduce the exact original bytes.
    const signature = req.get("x-paystack-signature");
    const expected = crypto
      .createHmac("sha512", paystackSecretKey.value())
      .update(req.rawBody)
      .digest("hex");

    if (!signature || signature !== expected) {
      logger.warn("paystackWebhook: signature mismatch — rejecting");
      res.status(401).send("Invalid signature");
      return;
    }

    // Acknowledge immediately — Paystack expects a fast 200 and will retry
    // on timeout, which could otherwise double-process this event.
    res.status(200).send("OK");

    const event = req.body;
    if (event?.event !== "charge.success") {
      logger.info(`paystackWebhook: ignoring event type "${event?.event}"`);
      return;
    }

    const { uid, cycle } = event.data?.metadata || {};
    if (!uid || !CYCLE_DAYS[cycle]) {
      // Expected for Paystack's "Send Test Event" dashboard button, which
      // fires a generic charge.success with no metadata attached — real
      // payments always carry { uid, cycle } from initializePaystackTransaction.
      logger.error("paystackWebhook: charge.success missing uid/cycle in metadata", event.data?.metadata);
      return;
    }

    try {
      await activateSubscription({
        uid,
        cycle,
        reference: event.data.reference,
        amount: event.data.amount,
      });
    } catch (err) {
      logger.error(`paystackWebhook: activation failed for user ${uid}`, err);
    }
  },
);

module.exports = { paystackWebhook };
