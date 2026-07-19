const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

// Set with: firebase functions:secrets:set PAYSTACK_SECRET_KEY
const paystackSecretKey = defineSecret("PAYSTACK_SECRET_KEY");

// Kept in sync with lib/features/subscription/subscription_screen.dart's
// PlanCatalog — amounts are in kobo (NGN × 100), which is what Paystack's
// API expects.
const PLAN_AMOUNTS_KOBO = {
  monthly: 2000 * 100,
  annual: 16000 * 100,
};
/**
 * This is a one-time-charge model, NOT a Paystack recurring Subscription —
 * there's no Plan object created on the Paystack dashboard, so there's no
 * auto-renewal. paystackWebhook.js grants access for 30 (monthly) or 365
 * (annual) days from the charge date; the user re-opens the subscription
 * screen and pays again when it lapses. This matches the MVP-simplicity
 * comment already on PlanCatalog in subscription_screen.dart. If real
 * auto-renewing subscriptions are wanted later, that needs a Plan created
 * via the Paystack dashboard/API and a switch to the Subscription API here
 * instead of /transaction/initialize.
 */
const initializePaystackTransaction = onCall(
  { secrets: [paystackSecretKey] },
  async (request) => {
    const uid = request.auth?.uid;
    const email = request.auth?.token?.email;
    if (!uid || !email) {
      throw new HttpsError("unauthenticated", "Must be signed in with an email to subscribe.");
    }

    const cycle = request.data?.cycle;
    const amount = PLAN_AMOUNTS_KOBO[cycle];
    if (!amount) {
      throw new HttpsError("invalid-argument", 'cycle must be "monthly" or "annual".');
    }

    const res = await fetch("https://api.paystack.co/transaction/initialize", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${paystackSecretKey.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email,
        amount,
        // Read back in paystackWebhook.js to know who to credit and which
        // plan/cycle they paid for — Paystack echoes metadata verbatim on
        // the webhook payload.
        metadata: { uid, cycle },
      }),
    });

    const json = await res.json();
    if (!res.ok || !json?.data?.authorization_url) {
      throw new HttpsError("internal", `Paystack initialize failed: ${json?.message || res.status}`);
    }

    return {
      authorizationUrl: json.data.authorization_url,
      reference: json.data.reference,
    };
  },
);

module.exports = { initializePaystackTransaction, paystackSecretKey };
