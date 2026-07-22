const { defineSecret } = require("firebase-functions/params");

// Set with: firebase functions:secrets:set RESEND_API_KEY
const resendApiKey = defineSecret("RESEND_API_KEY");

// TODO: once you verify a real sending domain in Resend (Domains → Add
// Domain), swap "onboarding@resend.dev" in each of these for your real
// addresses, e.g. "notifications@yourdomain.com" — any local part works
// automatically once the domain itself is verified, no per-address setup.
// Until the domain's verified, onboarding@resend.dev works with zero setup
// but can only deliver to the email on your own Resend account.
const FROM_ADDRESSES = {
  welcome: "NursaFlow <onboarding@resend.dev>",
  receipt: "NursaFlow Billing <onboarding@resend.dev>",
  reminder: "NursaFlow <onboarding@resend.dev>",
  report: "NursaFlow <onboarding@resend.dev>",
  account: "NursaFlow <onboarding@resend.dev>",
};

const ACCENT = "#0F766E"; // matches the teal used for primary buttons in-app

/**
 * `category` picks the sender from FROM_ADDRESSES above — pass one of
 * "welcome" | "receipt" | "reminder" | "report" | "account". Every function
 * that calls sendEmail() must also declare `secrets: [resendApiKey]` in its
 * onCall/onSchedule/onDocumentCreated options, or resendApiKey.value()
 * below throws at runtime — 2nd-gen Cloud Functions only inject a secret
 * into the functions that ask for it.
 */
async function sendEmail({ to, subject, html, category = "account" }) {
  const from = FROM_ADDRESSES[category] || FROM_ADDRESSES.account;
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey.value()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from, to, subject, html }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Resend send failed (${res.status}): ${text}`);
  }
  return res.json();
}

/** Shared wrapper so all 5 templates get the same basic layout/branding. */
function layout(bodyHtml) {
  return `
    <div style="font-family: -apple-system, Helvetica, Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px 24px; color: #1a1a1a;">
      <div style="font-size: 20px; font-weight: 700; color: ${ACCENT}; margin-bottom: 24px;">NursaFlow</div>
      ${bodyHtml}
      <div style="margin-top: 40px; padding-top: 16px; border-top: 1px solid #e5e5e5; font-size: 12px; color: #888;">
        You're receiving this because you have a NursaFlow account. Manage email preferences in Profile → Notifications.
      </div>
    </div>
  `;
}

function welcomeEmailHtml({ name }) {
  return layout(`
    <h1 style="font-size: 22px; margin: 0 0 12px;">Welcome${name ? `, ${name}` : ""} 👋</h1>
    <p style="font-size: 15px; line-height: 1.6;">
      NursaFlow turns your lecture notes and past questions into summaries, flashcards,
      and quizzes — built for nursing students studying for exams that actually matter.
    </p>
    <p style="font-size: 15px; line-height: 1.6;">
      Upload your first document to get started, or set a daily study reminder from the Planner tab.
    </p>
  `);
}

function receiptEmailHtml({ name, amount, planName, reference, renewsAt }) {
  const naira = (amount / 100).toLocaleString("en-NG");
  return layout(`
    <h1 style="font-size: 22px; margin: 0 0 12px;">Payment received ✅</h1>
    <p style="font-size: 15px; line-height: 1.6;">
      Thanks${name ? `, ${name}` : ""} — your NursaFlow ${planName} plan is now active.
    </p>
    <table style="width: 100%; font-size: 14px; border-collapse: collapse; margin: 20px 0;">
      <tr><td style="padding: 6px 0; color: #666;">Amount</td><td style="padding: 6px 0; text-align: right;">₦${naira}</td></tr>
      <tr><td style="padding: 6px 0; color: #666;">Plan</td><td style="padding: 6px 0; text-align: right;">${planName}</td></tr>
      <tr><td style="padding: 6px 0; color: #666;">Reference</td><td style="padding: 6px 0; text-align: right;">${reference}</td></tr>
      ${renewsAt ? `<tr><td style="padding: 6px 0; color: #666;">Renews</td><td style="padding: 6px 0; text-align: right;">${renewsAt}</td></tr>` : ""}
    </table>
    <p style="font-size: 13px; color: #666;">Keep this email as your receipt.</p>
  `);
}

function dailyReminderEmailHtml({ name, kind }) {
  const isStreak = kind === "streak";
  return layout(`
    <h1 style="font-size: 22px; margin: 0 0 12px;">${isStreak ? "🔥 Keep your streak alive" : "Time to revise 📚"}</h1>
    <p style="font-size: 15px; line-height: 1.6;">
      ${isStreak
        ? `Hi${name ? ` ${name}` : ""} — you haven't studied yet today. A few minutes now keeps your streak going.`
        : `Hi${name ? ` ${name}` : ""} — a few focused minutes now beats a cram session later.`}
    </p>
  `);
}

function weeklyReportEmailHtml({ name, totalMinutes, daysStudied, documentsAnalyzed }) {
  const hours = (totalMinutes / 60).toFixed(1);
  return layout(`
    <h1 style="font-size: 22px; margin: 0 0 12px;">Your week in review</h1>
    <p style="font-size: 15px; line-height: 1.6;">Hi${name ? ` ${name}` : ""}, here's how the last 7 days went:</p>
    <table style="width: 100%; font-size: 14px; border-collapse: collapse; margin: 20px 0;">
      <tr><td style="padding: 6px 0; color: #666;">Study time</td><td style="padding: 6px 0; text-align: right;">${hours} hrs</td></tr>
      <tr><td style="padding: 6px 0; color: #666;">Days studied</td><td style="padding: 6px 0; text-align: right;">${daysStudied} / 7</td></tr>
      <tr><td style="padding: 6px 0; color: #666;">Documents analyzed</td><td style="padding: 6px 0; text-align: right;">${documentsAnalyzed}</td></tr>
    </table>
    <p style="font-size: 15px; line-height: 1.6;">Open the app to plan next week's sessions.</p>
  `);
}

function expiryReminderEmailHtml({ name, daysLeft, planName }) {
  return layout(`
    <h1 style="font-size: 22px; margin: 0 0 12px;">Your plan expires soon</h1>
    <p style="font-size: 15px; line-height: 1.6;">
      Hi${name ? ` ${name}` : ""}, your NursaFlow ${planName} plan expires in
      ${daysLeft} day${daysLeft === 1 ? "" : "s"}. Renew now to keep unlimited uploads,
      flashcards, quizzes, and AI Tutor access.
    </p>
  `);
}

/**
 * Generic wrapper for one-off account-related emails (password changed,
 * plan cancelled, etc.) — not tied to a specific trigger yet since none of
 * those flows exist in this codebase. Call sendEmail() directly with a
 * purpose-built template once a real trigger needs one; this exists so
 * there's a documented, consistent shape to follow when that happens.
 */
function accountNotificationEmailHtml({ name, heading, message }) {
  return layout(`
    <h1 style="font-size: 22px; margin: 0 0 12px;">${heading}</h1>
    <p style="font-size: 15px; line-height: 1.6;">Hi${name ? ` ${name}` : ""}, ${message}</p>
  `);
}

module.exports = {
  resendApiKey,
  sendEmail,
  welcomeEmailHtml,
  receiptEmailHtml,
  dailyReminderEmailHtml,
  weeklyReportEmailHtml,
  expiryReminderEmailHtml,
  accountNotificationEmailHtml,
};
