const { GROQ_API_KEY } = require("./groq");

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";

// Per https://console.groq.com/docs/vision — Groq's vision lineup changes
// fairly often (this replaced the earlier llama-3.2-vision models). If
// transcription starts failing outright, check that doc for the current
// model id before assuming something else broke.
const VISION_MODEL = "qwen/qwen3.6-27b";

/**
 * Transcribes readable text out of a photo (typically a Camera Scan
 * upload of a handwritten or printed nursing note) using Groq's
 * vision-capable model, rather than a traditional OCR engine — this
 * handles messy handwriting and clinical shorthand far better than
 * engines like Tesseract, which is what the in-app "Camera Scan" copy
 * ("optimized for clinical shorthand") is actually relying on.
 *
 * Returns an empty string if no readable text was found — callers should
 * treat that the same as an unsupported file (fall back to course-based
 * generation) rather than as an error.
 *
 * @param {Buffer} buffer
 * @param {string} mimeType e.g. "image/jpeg" | "image/png"
 */
async function transcribeImage(buffer, mimeType) {
  const base64 = buffer.toString("base64");

  const res = await fetch(GROQ_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${GROQ_API_KEY.value()}`,
    },
    body: JSON.stringify({
      model: VISION_MODEL,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text:
                "Transcribe every word of readable text in this image exactly as written, " +
                "including handwritten nursing notes, diagram labels, and headings. Preserve " +
                "the original structure and line breaks as closely as you can. Do not " +
                "summarize, interpret, or add any commentary of your own — output only the " +
                "transcribed text itself. If the image genuinely contains no readable text, " +
                "respond with exactly: NO_TEXT_FOUND",
            },
            {
              type: "image_url",
              image_url: { url: `data:${mimeType};base64,${base64}` },
            },
          ],
        },
      ],
      temperature: 0.2,
      max_completion_tokens: 4096,
    }),
  });

  if (!res.ok) {
    const bodyText = await res.text().catch(() => "");
    throw new Error(`Groq vision API error ${res.status} ${res.statusText}: ${bodyText}`);
  }

  const data = await res.json();
  const text = data.choices?.[0]?.message?.content?.trim();
  if (!text || text === "NO_TEXT_FOUND") {
    return "";
  }
  return text;
}

module.exports = { transcribeImage };