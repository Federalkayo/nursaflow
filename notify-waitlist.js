/**
 * Run this from your own machine when NursaFlow is ready on iOS or the
 * Play Store — it emails everyone on that waitlist segment and marks them
 * as notified, so re-running it later (e.g. after new signups trickle in)
 * only emails people who haven't already heard from you.
 *
 * SETUP (one-time):
 * 1. Firebase Console → Project Settings → Service Accounts →
 *    "Generate new private key" → save the JSON file somewhere safe,
 *    e.g. ~/secrets/nursaflow-service-account.json
 *    (do NOT commit this file to git)
 * 2. Get your Resend API key from https://resend.com/api-keys
 * 3. From your nursaflow app folder:
 *      npm install firebase-admin --no-save
 *
 * USAGE:
 *   GOOGLE_APPLICATION_CREDENTIALS=~/secrets/nursaflow-service-account.json \
 *   RESEND_API_KEY=re_xxxxxxxx \
 *   node notify-waitlist.js ios
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=~/secrets/nursaflow-service-account.json \
 *   RESEND_API_KEY=re_xxxxxxxx \
 *   node notify-waitlist.js playstore
 */

const admin = require("firebase-admin");

const TYPE = process.argv[2];
if (TYPE !== "ios" && TYPE !== "playstore") {
  console.error('Usage: node notify-waitlist.js <ios|playstore>');
  process.exit(1);
}

const RESEND_API_KEY = process.env.RESEND_API_KEY;
if (!RESEND_API_KEY) {
  console.error("Set RESEND_API_KEY in your environment first.");
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const db = admin.firestore();

// TODO(kayode): update the copy below once you know the real download link
// (App Store link for iOS, Play Store link for playstore).
const COPY = {
  ios: {
    subject: "NursaFlow is here for iPhone 🎉",
    heading: "It's live on iOS!",
    body: "NursaFlow is now available on the App Store. Tap below to get started.",
    ctaLabel: "Download on the App Store",
    ctaUrl: "https://apps.apple.com/", // TODO(kayode): real App Store link
  },
  playstore: {
    subject: "NursaFlow is now on the Play Store 🎉",
    heading: "It's live on Google Play!",
    body: "NursaFlow is now available on the Google Play Store — no more sideloading needed.",
    ctaLabel: "Get it on Google Play",
    ctaUrl: "https://play.google.com/store", // TODO(kayode): real Play Store link
  },
};

async function sendResendEmail(to, subject, html) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    // TODO(kayode): swap this "from" address for your verified sending
    // domain once set up in Resend (see functions/src/email.js's own TODO).
    body: JSON.stringify({ from: "NursaFlow <onboarding@resend.dev>", to, subject, html }),
  });
  if (!res.ok) {
    throw new Error(`Resend failed (${res.status}): ${await res.text()}`);
  }
}

async function main() {
  const copy = COPY[TYPE];
  const snap = await db
    .collection("waitlist")
    .where("type", "==", TYPE)
    .where("notifiedAt", "==", null)
    .get();

  if (snap.empty) {
    // Firestore's == null query only matches docs where the field is
    // explicitly null — since notifiedAt is simply absent on unsent docs,
    // fall back to fetching everyone on this list and filtering in code.
    const all = await db.collection("waitlist").where("type", "==", TYPE).get();
    const pending = all.docs.filter((d) => !d.data().notifiedAt);
    await notify(pending, copy);
    return;
  }
  await notify(snap.docs, copy);
}

async function notify(docs, copy) {
  console.log(`Found ${docs.length} people to notify on the "${TYPE}" list.`);
  let sent = 0;
  for (const doc of docs) {
    const { email } = doc.data();
    const html = `
      <div style="font-family: -apple-system, Helvetica, Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px 24px; color: #1a1a1a;">
        <div style="font-size: 20px; font-weight: 700; color: #0F766E; margin-bottom: 24px;">NursaFlow</div>
        <h1 style="font-size: 22px; margin: 0 0 12px;">${copy.heading}</h1>
        <p style="font-size: 15px; line-height: 1.6;">${copy.body}</p>
        <a href="${copy.ctaUrl}" style="display:inline-block; margin-top:16px; background:#0F766E; color:#fff; text-decoration:none; padding:12px 22px; border-radius:999px; font-weight:600;">${copy.ctaLabel}</a>
      </div>
    `;
    try {
      await sendResendEmail(email, copy.subject, html);
      await doc.ref.update({ notifiedAt: admin.firestore.FieldValue.serverTimestamp() });
      sent++;
      console.log(`✓ ${email}`);
    } catch (err) {
      console.error(`✗ ${email} — ${err.message}`);
    }
  }
  console.log(`Done. Sent ${sent}/${docs.length}.`);
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});