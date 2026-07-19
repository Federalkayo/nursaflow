const crypto = require("crypto");
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { paystackSecretKey } = require("./paystack");
const { notifyPaymentUpdate } = require("./notifications");
const { sendEmail, receiptEmailHtml, resendApiKey } = require("./email");

const CYCLE_DAYS = { monthly: 30, annual: 365 };
const CYCLE_LABEL = { monthly: "Monthly", annual: "Annual" };

/**
 * Point Paystack's dashboard webhook URL at this function's deployed URL
 * once it's live. This is a ONE-TIME-CHARGE model (see paystack.js) —
 * `charge.success` is the only event that matters; there's no
 * `subscription.*` event to handle since nothing here uses Paystack's
 * Subscription/Plan API.
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
      logger.error("paystackWebhook: charge.success missing uid/cycle in metadata", event.data?.metadata);
      return;
    }

    const amount = event.data.amount; // kobo
    const reference = event.data.reference;
    const planName = CYCLE_LABEL[cycle];
    const renewsAt = new Date(Date.now() + CYCLE_DAYS[cycle] * 24 * 60 * 60 * 1000);

    const db = admin.firestore();
    try {
      await db.collection("users").doc(uid).set(
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
    } catch (err) {
      logger.error(`paystackWebhook: Firestore update failed for user ${uid}`, err);
      return; // don't send a receipt for a subscription that didn't actually save
    }

    await notifyPaymentUpdate(uid, { status: "activated", planName }).catch((err) =>
      logger.warn(`paystackWebhook: push notify failed for user ${uid}`, err),
    );

    try {
      const userDoc = await db.collection("users").doc(uid).get();
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
      logger.warn(`paystackWebhook: receipt email failed for user ${uid}`, err);
    }
  },
);

module.exports = { paystackWebhook };
