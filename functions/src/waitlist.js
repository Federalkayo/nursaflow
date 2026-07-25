const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { sendEmail, resendApiKey } = require("./email");

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const VALID_TYPES = new Set(["ios", "playstore"]);

const TYPE_COPY = {
  ios: {
    subject: "You're on the NursaFlow iOS waitlist",
    heading: "You're on the list 🎉",
    message:
      "we'll email you the moment NursaFlow is ready for iPhone. In the meantime, if you know anyone on Android, NursaFlow is free to download today.",
  },
  playstore: {
    subject: "We'll let you know when NursaFlow hits the Play Store",
    heading: "You're on the list 🎉",
    message:
      "we'll email you as soon as NursaFlow is live on the Google Play Store. You can still download it directly from our site right now if you'd rather not wait.",
  },
};

/**
 * Public, unauthenticated endpoint called from the marketing site's plain
 * fetch() — see nursaflow-site/index.html's waitlist form. No Firebase SDK
 * is loaded on that static page, so this is a plain onRequest (not onCall)
 * with manual CORS headers, rather than the callable-function pattern used
 * for authenticated in-app calls like initializePaystackTransaction.
 *
 * Deploy, then set the site's WAITLIST_ENDPOINT_URL (in index.html) to this
 * function's deployed URL, e.g.:
 *   https://us-central1-<project-id>.cloudfunctions.net/joinWaitlist
 */
const joinWaitlist = onRequest(
  { secrets: [resendApiKey], cors: true },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Use POST." });
      return;
    }

    const email = String(req.body?.email || "").trim().toLowerCase();
    const type = String(req.body?.type || "").trim();

    if (!EMAIL_RE.test(email)) {
      res.status(400).json({ error: "Enter a valid email address." });
      return;
    }
    if (!VALID_TYPES.has(type)) {
      res.status(400).json({ error: 'type must be "ios" or "playstore".' });
      return;
    }

    // Deterministic doc ID (type + email) makes repeat sign-ups idempotent
    // instead of piling up duplicate entries if someone taps the button
    // twice or resubmits.
    const docId = `${type}_${email.replace(/[^a-z0-9@._-]/g, "_")}`;

    try {
      await admin.firestore().collection("waitlist").doc(docId).set(
        {
          email,
          type,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          notifiedAt: null,
          source: "website",
        },
        { merge: true },
      );
    } catch (err) {
      logger.error("joinWaitlist: Firestore write failed", err);
      res.status(500).json({ error: "Something went wrong. Please try again." });
      return;
    }

    // Best-effort confirmation email — don't fail the signup if Resend has
    // a hiccup, since the waitlist entry itself already saved successfully.
    try {
      const copy = TYPE_COPY[type];
      await sendEmail({
        to: email,
        subject: copy.subject,
        html: `
          <div style="font-family: -apple-system, Helvetica, Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px 24px; color: #1a1a1a;">
            <div style="font-size: 20px; font-weight: 700; color: #0F766E; margin-bottom: 24px;">NursaFlow</div>
            <h1 style="font-size: 22px; margin: 0 0 12px;">${copy.heading}</h1>
            <p style="font-size: 15px; line-height: 1.6;">Thanks for your interest — ${copy.message}</p>
          </div>
        `,
      });
    } catch (err) {
      logger.warn("joinWaitlist: confirmation email failed (signup still saved)", err);
    }

    res.status(200).json({ ok: true });
  },
);

module.exports = { joinWaitlist };