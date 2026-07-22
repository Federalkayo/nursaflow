const admin = require("firebase-admin");
admin.initializeApp();

const { analyzeDocument } = require("./src/analyzeDocument");
const { askTutor } = require("./src/askTutor");
const { fetchResources } = require("./src/resources");
const { sendDueReminders } = require("./src/reminders");
const { sendWeeklyReports } = require("./src/weeklyReport");
const { sendExpiryReminders } = require("./src/expiryReminder");
const { onUserCreated } = require("./src/onUserCreated");
const { initializePaystackTransaction } = require("./src/paystack");
const { paystackWebhook } = require("./src/paystackWebhook");

exports.analyzeDocument = analyzeDocument;
exports.askTutor = askTutor;
exports.fetchResources = fetchResources;
exports.sendDueReminders = sendDueReminders;
exports.sendWeeklyReports = sendWeeklyReports;
exports.sendExpiryReminders = sendExpiryReminders;
exports.onUserCreated = onUserCreated;
exports.initializePaystackTransaction = initializePaystackTransaction;
exports.paystackWebhook = paystackWebhook;