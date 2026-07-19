const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const { sendEmail, welcomeEmailHtml, resendApiKey } = require("./email");

/**
 * Fires once per new user. Both signup paths in sign_up_screen.dart
 * (email/password and Google) write users/{uid} with `name` + `email`
 * immediately after account creation, so this Firestore trigger — rather
 * than an Auth-level identity trigger — is the simplest single hook that
 * covers both.
 */
const onUserCreated = onDocumentCreated(
  { document: "users/{uid}", secrets: [resendApiKey] },
  async (event) => {
    const data = event.data?.data();
    if (!data?.email) {
      logger.warn(`New user doc ${event.params.uid} has no email — skipping welcome email`);
      return;
    }

    try {
      await sendEmail({
        to: data.email,
        subject: "Welcome to NursaFlow 👋",
        html: welcomeEmailHtml({ name: data.name }),
      });
    } catch (err) {
      // Don't throw — a failed welcome email shouldn't be retried forever
      // by Cloud Functions' automatic retry-on-error for event triggers,
      // and it's not worth blocking anything else on.
      logger.error(`Welcome email failed for user ${event.params.uid}`, err);
    }
  },
);

module.exports = { onUserCreated };
