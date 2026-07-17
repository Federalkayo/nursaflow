const admin = require("firebase-admin");

/**
 * Writes a notification doc to users/{userId}/notifications, then sends a
 * push if the user has a saved FCM token. The Admin SDK bypasses Firestore
 * rules entirely, matching the comment in firestore.rules that says these
 * docs are only ever written server-side.
 *
 * type must match one of the NotificationType enum values in
 * lib/features/notifications/models/app_notification.dart (documentReady,
 * tutorReply, streak, subscription, announcement, generic) — anything else
 * falls back to the generic bell icon client-side, so it's safe but keep
 * them in sync when adding a new one.
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

module.exports = { createNotification };
