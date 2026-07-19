const admin = require("firebase-admin");

/**
 * Writes a notification doc to users/{userId}/notifications, then sends a
 * push if the user has a saved FCM token. The Admin SDK bypasses Firestore
 * rules entirely, matching the comment in firestore.rules that says these
 * docs are only ever written server-side.
 *
 * type must match one of the NotificationType enum values in
 * lib/features/notifications/models/app_notification.dart (documentReady,
 * tutorReply, streak, subscription, dailyReminder, announcement, generic) —
 * anything else falls back to the generic bell icon client-side, so it's
 * safe but keep them in sync when adding a new one.
 */
async function createNotification(userId, { type, title, body, refId }) {
  const db = admin.firestore();

  await db.collection("users").doc(userId).collection("notifications").add({
    type: type || "generic",
    title,
    body,
    refId: refId || null,
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        data: { type: type || "generic", refId: refId || "" },
      });
    }
  } catch (err) {
    // A dead/expired token shouldn't fail the calling function — the
    // Firestore notification above already landed, and the client will
    // pick it up next time it reads the list.
    console.warn(`Push send failed for user ${userId}`, err);
  }
}

/**
 * STUB — not called from anywhere yet. askTutor() (functions/src/askTutor.js)
 * is a synchronous onCall: its reply is already in the response by the time
 * the client sees it, so there's nothing to notify about today. Wire this
 * in if the AI Tutor ever gets an async/background flow (e.g. a queued
 * document Q&A job) where the reply can arrive after the request returns.
 */
async function notifyTutorReplyReady(userId, { documentId } = {}) {
  return createNotification(userId, {
    type: "tutorReply",
    title: "Your tutor replied",
    body: "Tap to see the answer.",
    refId: documentId || null,
  });
}

/**
 * Called from paystackWebhook.js on a successful charge — see that file for
 * the "status"/"planName" values it passes.
 */
async function notifyPaymentUpdate(userId, { status, planName } = {}) {
  return createNotification(userId, {
    type: "subscription",
    title: "Subscription update",
    body: planName
      ? `Your ${planName} plan is now ${status}.`
      : `Your subscription is now ${status}.`,
  });
}

module.exports = { createNotification, notifyTutorReplyReady, notifyPaymentUpdate };
