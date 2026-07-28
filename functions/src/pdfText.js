const pdfParse = require("pdf-parse");
const mammoth = require("mammoth");
const { transcribeImage } = require("./imageOcr");

const IMAGE_MIME_TYPES = { jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png" };

// Cap applied to the text actually sent into the analysis prompt (Groq
// call in analyzeDocument.js). Kept the same as before this change so the
// cost/behavior of the existing analysis prompt is unaffected. The FULL,
// untruncated text is still returned separately (see `fullText` below) so
// callers that need the whole document — e.g. chunking it into chapters
// for the AI Tutor to reference later — aren't limited by this cap.
const ANALYSIS_PROMPT_CHAR_LIMIT = 60000;

/**
 * Extracts text from a downloaded file buffer, based on its extension.
 * Returns { text, fullText, pageCount, supported }.
 *   - text: truncated to ANALYSIS_PROMPT_CHAR_LIMIT, safe to drop straight
 *     into the analysis prompt exactly as before this change.
 *   - fullText: the complete extracted text, untruncated. Used by
 *     analyzeDocument.js to persist per-chapter content for the AI Tutor.
 * For formats we can't parse yet (pptx), returns supported: false so the
 * caller can fall back to a course-based prompt instead of failing outright.
 * @param {Buffer} buffer
 * @param {string} fileName
 */
async function extractText(buffer, fileName) {
  const ext = (fileName.split(".").pop() || "").toLowerCase();

  if (ext === "pdf") {
    const data = await pdfParse(buffer);
    const fullText = data.text;
    return {
      text: fullText.slice(0, ANALYSIS_PROMPT_CHAR_LIMIT),
      fullText,
      pageCount: data.numpages || 0,
      supported: true,
    };
  }

  if (ext === "docx") {
    // mammoth reads the real paragraph/heading text out of a .docx and
    // ignores styling/images, which is exactly what we want here (we
    // don't need the Word formatting, just the words). .doc (old binary
    // format) is NOT handled by mammoth — that still falls through to
    // `supported: false` below, same as pptx.
    const { value: extractedText } = await mammoth.extractRawText({ buffer });
    const fullText = extractedText || "";
    // A rough page-count estimate for docx (mammoth doesn't report one) —
    // ~500 words per page is a reasonable average for a text-heavy Word
    // document. Only used for display purposes, not for any logic below.
    const wordCount = fullText.trim() ? fullText.trim().split(/\s+/).length : 0;
    const estimatedPageCount = wordCount ? Math.max(1, Math.round(wordCount / 500)) : 0;
    return {
      text: fullText.slice(0, ANALYSIS_PROMPT_CHAR_LIMIT),
      fullText,
      pageCount: estimatedPageCount,
      supported: fullText.trim().length > 0,
    };
  }

  if (IMAGE_MIME_TYPES[ext]) {
    // Camera Scan uploads land here — transcribed via Groq's vision model
    // (imageOcr.js) rather than a traditional OCR engine, since it holds
    // up far better on handwriting and clinical shorthand.
    const text = await transcribeImage(buffer, IMAGE_MIME_TYPES[ext]);
    return {
      text: text.slice(0, ANALYSIS_PROMPT_CHAR_LIMIT),
      fullText: text,
      pageCount: text ? 1 : 0,
      supported: text.length > 0,
    };
  }

  // TODO: add pptx extraction (e.g. via `officeparser` or a Pandoc-based
  // approach) in a later pass.
  return { text: "", fullText: "", pageCount: 0, supported: false };
}

module.exports = { extractText };
