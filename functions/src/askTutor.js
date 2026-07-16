const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { getStorage } = require("firebase-admin/storage");

const { generateText, GROQ_API_KEY } = require("./groq");
const { buildTutorPrompt } = require("./prompts");
const { generateImageFromPrompt } = require("./imageGen");

// Broad on purpose — false positives here just mean an occasional bonus
// picture, which is harmless for a study app. False negatives mean a
// student's explicit image request silently gets a text answer instead,
// which is the worse failure mode. So: "draw"/"illustrate"/"sketch" as a
// bare verb anywhere is enough, no need for a nearby trigger noun.
const IMAGE_REQUEST_PATTERN =
  /\b(draw|illustrate|sketch)\b|\b(picture|image)\s+of\b|\bshow\s+me\s+(a|an)?\s*(picture|image|diagram|illustration)\b|\bgenerate\s+(an?\s+)?(picture|image|diagram|illustration)\b/i;

function extractImagePrompt(message) {
  // Strip the common trigger phrasing so the leftover is a cleaner subject
  // for the image prompt, e.g. "draw me a diagram of the nephron" -> "the nephron".
  return message
    .replace(/\b(please|can you|could you)\b/gi, "")
    .replace(/\b(draw|generate|show|create|illustrate)\b(\s+me)?\s*(an?|the)?\s*(image|picture|diagram|illustration|photo|drawing)?\s*(of)?/gi, "")
    .trim() || message;
}

// A handful of filler words that survive extractImagePrompt() on messy
// phrasing like "Must you draw Diagram give me full long explanation" —
// stripping the trigger verb+noun there leaves "Must you give me full long
// explanation", which is NOT a usable image subject even though it's
// non-empty. This checks for that case so we know when to fall back.
const VAGUE_LEFTOVER_WORDS = new Set([
  "must", "you", "give", "me", "full", "long", "short", "quick",
  "explanation", "please", "can", "could", "would", "should", "it", "that",
  "this", "one", "again", "now",
]);

function looksVague(subject) {
  const words = subject.toLowerCase().split(/\s+/).filter(Boolean);
  if (words.length === 0) return true;
  const meaningfulWords = words.filter((w) => !VAGUE_LEFTOVER_WORDS.has(w));
  return meaningfulWords.length === 0;
}

/**
 * Decides what to actually ask Pollinations for. Prefers a specific subject
 * extracted from the student's own message (e.g. "draw the nephron"), but
 * falls back to the tutor's own explanation + document title when the
 * message doesn't name a real topic on its own (e.g. "give me full long
 * explanation" following up on an earlier question) — otherwise Pollinations
 * gets sent something meaningless and returns a generic stock-style image.
 */
function deriveImageSubject({ userMessage, replyText, documentContext }) {
  const strippedMsg = extractImagePrompt(userMessage);
  if (!looksVague(strippedMsg)) return strippedMsg;

  const cleanReply = replyText.replace(/```mermaid[\s\S]*?```/g, "").trim();
  const firstSentence = cleanReply.split(/(?<=[.!?])\s+/)[0] || "";
  const titleMatch = documentContext?.match(/^Title:\s*(.+)$/m);
  const topic = titleMatch?.[1];

  return [topic, firstSentence].filter(Boolean).join(" — ") || userMessage;
}

/**
 * Callable function: askTutor({ documentId?: string, message: string })
 *
 * Matches the exact chat schema used in
 * lib/features/tutor/models/chat_message.dart and ai_tutor_screen.dart:
 *   - path: users/{uid}/documents/{documentId}/messages  (if documentId given)
 *           users/{uid}/general_messages                  (otherwise)
 *   - fields: { sender: 'user'|'ai', text, timestamp }
 *
 * The Flutter client still writes the user's own message directly (unchanged
 * from Antigravity's implementation) — this function only reads context,
 * calls Groq, and writes the AI's reply back to the same collection. The
 * client's existing Firestore stream listener picks up the new message
 * automatically, no extra wiring needed on the Flutter side beyond calling
 * this function instead of the old _mockResponseFor() fake.
 */
const askTutor = onCall(
  {
    secrets: [GROQ_API_KEY],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in to use the AI Tutor.");
    }

    const uid = request.auth.uid;
    const documentId = request.data?.documentId || null;
    const userMessage = (request.data?.message || "").trim();

    if (!userMessage) {
      throw new HttpsError("invalid-argument", "message is required.");
    }

    const userRef = admin.firestore().collection("users").doc(uid);
    const chatCollection = documentId
      ? userRef.collection("documents").doc(documentId).collection("messages")
      : userRef.collection("general_messages");

    // 1. Pull document context, if this chat is scoped to a document.
    let documentContext = null;
    if (documentId) {
      const docSnap = await userRef.collection("documents").doc(documentId).get();
      if (docSnap.exists) {
        const d = docSnap.data();
        const parts = [];
        if (d.title) parts.push(`Title: ${d.title}`);
        if (d.course) parts.push(`Course: ${d.course}`);
        if (d.clinicalOverview) parts.push(`Overview: ${d.clinicalOverview}`);
        if (Array.isArray(d.takeaways) && d.takeaways.length) {
          parts.push(`Key takeaways: ${d.takeaways.join("; ")}`);
        }
        documentContext = parts.join("\n");
      }
    }

    // 2. Pull recent chat history for conversational context (last 10 turns).
    const historySnap = await chatCollection.orderBy("timestamp", "desc").limit(10).get();
    const history = historySnap.docs
      .map((d) => d.data())
      .reverse()
      .map((d) => ({ sender: d.sender, text: d.text }));

    // 2b. Call Groq for the actual explanation FIRST, always — even when an
    // image was also requested. Previously the image branch ran before Groq
    // and returned early, so an explicit "draw X and explain it" request
    // silently dropped the explanation entirely. Groq's prompt (see
    // buildTutorPrompt) already knows to include a ```mermaid fence for
    // process/mechanism topics, which is a better visual than a generic
    // photo for things like blood circulation — so we only reach for
    // Pollinations below if that didn't happen.
    let replyText;
    try {
      const prompt = buildTutorPrompt({ userMessage, documentContext, history });
      replyText = await generateText(prompt, { temperature: 0.7 });
    } catch (err) {
      logger.error("askTutor Groq call failed", err);
      replyText =
        "Sorry, I'm having trouble reaching my AI backend right now. Please try again in a moment.";
    }

    const hasMermaidDiagram = /```mermaid[\s\S]*?```/.test(replyText);

    // 3. Only generate a Pollinations image if the student explicitly asked
    // for one AND Groq didn't already answer with a Mermaid diagram (which
    // means it judged this a process/mechanism topic better shown as a
    // flowchart than an illustration). The image subject is derived from
    // Groq's actual explanation + document title when the raw user message
    // is too vague to extract a real subject from (e.g. "give me full long
    // explanation" contains no usable topic on its own).
    let imagePath = null;
    if (IMAGE_REQUEST_PATTERN.test(userMessage) && !hasMermaidDiagram) {
      try {
        const subject = deriveImageSubject({ userMessage, replyText, documentContext });
        const imageBuffer = await generateImageFromPrompt(subject);
        if (imageBuffer) {
          imagePath = `users/${uid}/chat_images/${Date.now()}.png`;
          await getStorage().bucket().file(imagePath).save(imageBuffer, {
            contentType: "image/png",
          });
        }
      } catch (err) {
        logger.error("askTutor image generation failed, sending text-only reply", err);
        // fall through — replyText still gets sent below
      }
    }

    // 4. Write the AI's reply (and image, if generated) to Firestore — the
    // client's existing stream listener will render it automatically.
    await chatCollection.add({
      sender: "ai",
      text: replyText,
      ...(imagePath ? { imagePath } : {}),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  }
);

module.exports = { askTutor };