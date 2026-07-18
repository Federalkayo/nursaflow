const admin = require("firebase-admin");
admin.initializeApp();

const { analyzeDocument } = require("./src/analyzeDocument");
const { askTutor } = require("./src/askTutor");
const { fetchResources } = require("./src/resources");
const { sendDueReminders } = require("./src/reminders");

exports.analyzeDocument = analyzeDocument;
exports.askTutor = askTutor;
exports.fetchResources = fetchResources;
exports.sendDueReminders = sendDueReminders;

// functions/src/paystackWebhook.js is intentionally NOT exported here yet —
// see that file's header for what's required before it's safe to deploy.