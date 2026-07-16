const admin = require("firebase-admin");
admin.initializeApp();

const { analyzeDocument } = require("./src/analyzeDocument");
const { askTutor } = require("./src/askTutor");

exports.analyzeDocument = analyzeDocument;
exports.askTutor = askTutor;
