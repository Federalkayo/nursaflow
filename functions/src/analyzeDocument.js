const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { getStorage } = require("firebase-admin/storage");

const { generateJson, GROQ_API_KEY } = require("./groq");
const { extractText } = require("./pdfText");
const { buildAnalysisPrompt } = require("./prompts");
const { fallbackAnalysis } = require("./fallback");
const { generateIllustration } = require("./imageGen");
const { createNotification } = require("./notifications");

/**
 * Fires whenever a new document is created at
 *   users/{userId}/documents/{documentId}
 * (this is guaranteed to happen on every upload — Storage upload in the
 * Flutter client is wrapped in try/catch and can silently fail, so we
 * trigger off Firestore instead of Cloud Storage for reliability).
 *
 * Looks for the uploaded source file in Storage at
 *   users/{userId}/documents/{documentId}/<original filename>
 * If found and it's a PDF, extracts real text and grounds Groq in it.
 * Otherwise, falls back to generating course-appropriate content from the
 * title/course alone.
 */
const analyzeDocument = onDocumentCreated(
  {
    document: "users/{userId}/documents/{documentId}",
    secrets: [GROQ_API_KEY],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (event) => {
    const { userId, documentId } = event.params;
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    if (data.status !== "processing") {
      // Already handled, or created in some other state — don't reprocess.
      return;
    }

    const title = data.title || "Untitled Document";
    const course = data.course || "General Nursing";
    const docRef = snapshot.ref;

    logger.info(`Analyzing document ${documentId} for user ${userId}`, { title, course });

    // 1. Try to locate and read the uploaded source file from Storage.
    let sourceText = "";
    let hasSourceText = false;
    let pageCount = data.pageCount || 0;

    try {
      const bucket = getStorage().bucket();
      const [files] = await bucket.getFiles({
        prefix: `users/${userId}/documents/${documentId}/`,
      });

      if (files.length > 0) {
        const file = files[0];
        const [buffer] = await file.download();
        const extracted = await extractText(buffer, file.name);
        if (extracted.supported && extracted.text.trim().length > 0) {
          sourceText = extracted.text;
          hasSourceText = true;
          if (extracted.pageCount) pageCount = extracted.pageCount;
        }
      }
    } catch (err) {
      logger.warn(`Could not read source file for ${documentId}, falling back to course-based generation`, err);
    }

    // 2. Call Groq.
    let analysis;
    try {
      const prompt = buildAnalysisPrompt({ title, course, sourceText, hasSourceText });
      analysis = await generateJson(prompt);
    } catch (err) {
      logger.error(`Groq analysis failed for ${documentId}, using fallback content`, err);
      analysis = fallbackAnalysis(title, course);
    }

    // 3. Generate an illustrative image — but only if Groq decided this
    // topic is better suited to an image than a diagram (see the "mermaid"
    // rules in the prompt: process/mechanism topics get a diagram instead,
    // which is cheaper, faster, and more accurate than an AI image for
    // that kind of content). Best-effort either way — never blocks the
    // rest of the document from being marked ready if this fails.
    let illustrationPath = null;
    const hasMermaid = typeof analysis.mermaid === "string" && analysis.mermaid.trim().length > 0;

    if (!hasMermaid) {
      try {
        const imageBuffer = await generateIllustration({
          title,
          course,
          overview: analysis.clinicalOverview || `Study material for ${course}`,
          subject: analysis.illustrationSubject || "",
        });
        if (imageBuffer) {
          const bucket = getStorage().bucket();
          const path = `users/${userId}/documents/${documentId}/illustration.png`;
          const file = bucket.file(path);
          await file.save(imageBuffer, { contentType: "image/png" });
          illustrationPath = path;
        }
      } catch (err) {
        logger.warn(`Illustration generation failed for ${documentId} — continuing without it`, err);
      }
    }

    // 4. Write the summary fields back onto the document + mark ready.
    await docRef.update({
      status: "ready",
      pageCount,
      mainTopic: analysis.mainTopic || course,
      clinicalOverview: analysis.clinicalOverview || "",
      keyQuote: analysis.keyQuote || "",
      keyPrinciples: analysis.keyPrinciples || [],
      assessmentNote: analysis.assessmentNote || "",
      assessmentHierarchy: analysis.assessmentHierarchy || [],
      clinicalRedFlags: analysis.clinicalRedFlags || [],
      takeaways: analysis.takeaways || [],
      mermaid: analysis.mermaid || '',
      ...(illustrationPath ? { illustrationPath } : {}),
      analyzedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. Write flashcards + quiz as subcollections (batched for one round trip).
    const batch = admin.firestore().batch();

    for (const card of analysis.flashcards || []) {
      const ref = docRef.collection("flashcards").doc();
      batch.set(ref, {
        question: card.question || "",
        answer: card.answer || "",
        explanation: card.explanation || "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    for (const q of analysis.quiz || []) {
      const ref = docRef.collection("quizzes").doc();
      batch.set(ref, {
        tag: q.tag || course.toUpperCase(),
        question: q.question || "",
        options: q.options || [],
        correctIndex: q.correctIndex ?? 0,
        explanation: q.explanation || "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    await createNotification(userId, {
      type: "documentReady",
      title: "Analysis complete",
      body: `"${title}" is ready — summary, flashcards, and quiz are in.`,
      refId: documentId,
    });

    logger.info(`Finished analyzing document ${documentId}`);
  }
);

module.exports = { analyzeDocument };