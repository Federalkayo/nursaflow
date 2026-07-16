const admin = require("firebase-admin");
admin.initializeApp();

const { analyzeDocument } = require("./src/analyzeDocument");
const { askTutor } = require("./src/askTutor");
const { fetchResources } = require("./src/resources");

exports.analyzeDocument = analyzeDocument;
exports.askTutor = askTutor;
exports.fetchResources = fetchResources;