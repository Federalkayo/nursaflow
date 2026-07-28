const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { getStorage } = require("firebase-admin/storage");

const { generateText, GROQ_API_KEY } = require("./groq");
const { buildTutorPrompt } = require("./prompts");
const { generateImageFromPrompt } = require("./imageGen");
const {
  isPremiumActive,
  FREE_AI_TUTOR_MONTHLY_LIMIT,
  currentMonthKey,
} = require("./planLimits");

// Broad on purpose — false positives here just mean an occasional bonus
// picture, which is harmless for a study app. False negatives mean a
// student's explicit image request silently gets a text answer instead,
// which is the worse failure mode. So: "draw"/"illustrate"/"sketch" as a
// bare verb anywhere is enough, no need for a nearby trigger noun.
const IMAGE_REQUEST_PATTERN =
  /\b(draw|illustrate|sketch)\b|\b(picture|image)\s+of\b|\bshow\s+me\s+(a|an)?\s*(picture|image|diagram|illustration)\b|\bgenerate\s+(an?\s+)?(picture|image|diagram|illustration)\b/i;

// Matches an explicit chapter reference in the student's message, e.g.
// "chapter 4", "Chapter 12", "ch 4". Deliberately numeric-only for now —
// word-number references ("chapter four") aren't handled yet, same
// limitation as before this feature existed (no chapter lookup at all).
const CHAPTER_REFERENCE_PATTERN = /\bch(?:apter)?\.?\s*(\d+)\b/i;

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
 * Builds the documentContext string passed into buildTutorPrompt. Reads the
 * whole-document summary fields as before, and additionally — when the
 * student's message names a specific chapter number and that document has
 * persisted chapter chunks (written by analyzeDocument.js at upload time,
 * only present for long, multi-chapter reference documents) — pulls in the
 * actual extracted text for that chapter. This is what lets the Tutor
 * answer chapter-specific questions accurately instead of guessing from the
 * whole-document summary alone, which is too coarse for that.
 *
 * If the student asks about a chapter number but no matching chunk exists
 * (e.g. older documents uploaded before this feature, or a short
 * single-topic document with no chapter structure), we explicitly tell the
 * model that in the context block, so it says "I don't have that section"
 * rather than fabricating an answer — see the corresponding instruction
 * added to buildTutorPrompt in prompts.js.
 */
async function buildDocumentContext(docRef, userMessage) {
  const docSnap = await docRef.get();
  if (!docSnap.exists) return null;

  const d = docSnap.data();
  const parts = [];
  if (d.title) parts.push(`Title: ${d.title}`);
  if (d.course) parts.push(`Course: ${d.course}`);
  if (d.clinicalOverview) parts.push(`Overview: ${d.clinicalOverview}`);
  if (Array.isArray(d.takeaways) && d.takeaways.length) {
    parts.push(`Key takeaways: ${d.takeaways.join("; ")}`);
  }

  const chapterMatch = userMessage.match(CHAPTER_REFERENCE_PATTERN);
  if (chapterMatch) {
    const chapterNumber = parseInt(chapterMatch[1], 10);

    if (d.hasChapterContent) {
      const chapterSnap = await docRef
        .collection("chapters")
        .where("chapterNumber", "==", chapterNumber)
        .limit(1)
        .get();

      if (!chapterSnap.empty) {
        const chapterData = chapterSnap.docs[0].data();
        const headingSuffix = chapterData.heading ? ` (${chapterData.heading})` : "";
        parts.push(
          `Actual extracted content of Chapter ${chapterNumber}${headingSuffix} from the source document — base any answer about this specific chapter strictly on this text, do not add facts beyond it:\n"""\n${chapterData.text || ""}\n"""`,
        );
      } else {
        parts.push(
          `Note: the student is asking about Chapter ${chapterNumber}, but this document does not have that many chapters, or the chapter numbering doesn't match. Do not guess at its contents — tell the student you don't have that specific chapter and ask them to check the number.`,
        );
      }
    } else {
      parts.push(
        `Note: the student is asking about Chapter ${chapterNumber}, but detailed per-chapter content isn't available for this document (it may be a short document with no chapter structure, or was uploaded before chapter-level lookup was added). Do not guess at what that chapter might contain — answer from the Overview/Key takeaways above only, and be upfront that you don't have that section's specific details.`,
      );
    }
  }

  return parts.join("\n");
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

    // Free-plan enforcement: gate BEFORE calling Groq at all, since this is
    // the only path to an AI Tutor reply — unlike document uploads, there's
    // no separate client-side action to intercept, so this check is the
    // real enforcement (not just a backstop). monthKey/currentCount are
    // reused below, after a successful reply, to write the incremented
    // counter without a second read.
    const userSnap = await userRef.get();
    const userData = userSnap.data() || {};
    const isPremium = isPremiumActive(userData);
    const monthKey = currentMonthKey();
    const storedMonthKey = userData.aiTutorMessageMonthKey;
    const currentCount = storedMonthKey === monthKey ? (userData.aiTutorMessageCount || 0) : 0;

    if (!isPremium && currentCount >= FREE_AI_TUTOR_MONTHLY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        `You've used all ${FREE_AI_TUTOR_MONTHLY_LIMIT} AI Tutor messages included in the free plan this month. Upgrade to Premium for unlimited access.`,
      );
    }

    const chatCollection = documentId
      ? userRef.collection("documents").doc(documentId).collection("messages")
      : userRef.collection("general_messages");

    // 1. Pull document context, if this chat is scoped to a document. See
    // buildDocumentContext() above for the chapter-lookup behavior.
    let documentContext = null;
    if (documentId) {
      documentContext = await buildDocumentContext(
        userRef.collection("documents").doc(documentId),
        userMessage,
      );
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

    // Only free users need this tracked at all — skip the extra write for
    // premium accounts, whose usage is unlimited regardless.
    if (!isPremium) {
      await userRef.set(
        storedMonthKey === monthKey
          ? {
              aiTutorMessageCount: admin.firestore.FieldValue.increment(1),
              aiTutorMessageMonthKey: monthKey,
            }
          : { aiTutorMessageCount: 1, aiTutorMessageMonthKey: monthKey },
        { merge: true },
      );
    }

    return { success: true };
  }
);

module.exports = { askTutor };
