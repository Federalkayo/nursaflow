const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");
const { jsonrepair } = require("jsonrepair");

// Set this once with:
//   firebase functions:secrets:set GROQ_API_KEY
// Get a free key from https://console.groq.com/keys — no credit card required,
// genuinely free tier (rate-limited, not metered/prepaid like some providers).
const GROQ_API_KEY = defineSecret("GROQ_API_KEY");

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";

// llama-3.3-70b-versatile: best quality/speed balance on Groq's free tier,
// good enough for clinical summarization and conversational tutoring.
const DEFAULT_MODEL = "llama-3.3-70b-versatile";

// Default output budget for generateJson calls specifically (see below) —
// measured against a fully-populated example response (8 flashcards, 5 quiz
// questions, 3 principles, 3 assessment steps, 2-3 red flags, 3 takeaways),
// which needs roughly 1,500-1,600 tokens. 2500 leaves comfortable margin
// above that without eating further into Groq's 12,000 tokens/minute cap,
// which is shared across every Groq call this project makes in the same
// minute (analysis, AI Tutor chat, and image OCR all draw from the same
// pool) — see MAX_SOURCE_CHARS in prompts.js for the corresponding budget
// on the input side. generateText's default (no max_tokens sent) is left
// unchanged for callers like askTutor that don't need this.
const JSON_MAX_TOKENS = 2500;

/**
 * Calls Groq's OpenAI-compatible chat completions endpoint and returns raw
 * text. Uses plain fetch (built into Node 20) rather than an SDK — Groq's
 * API is a straightforward REST/JSON endpoint, so no client library is
 * needed, and it sidesteps any ESM/CommonJS packaging issues entirely.
 * @param {string} prompt
 * @param {{ model?: string, temperature?: number, max_tokens?: number }} [options]
 */
async function generateText(prompt, options = {}) {
  const res = await fetch(GROQ_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${GROQ_API_KEY.value()}`,
    },
    body: JSON.stringify({
      model: options.model || DEFAULT_MODEL,
      messages: [{ role: "user", content: prompt }],
      temperature: options.temperature ?? 0.6,
      ...(options.max_tokens ? { max_tokens: options.max_tokens } : {}),
    }),
  });

  if (!res.ok) {
    const bodyText = await res.text().catch(() => "");
    throw new Error(`Groq API error ${res.status} ${res.statusText}: ${bodyText}`);
  }

  const data = await res.json();
  const choice = data.choices?.[0];
  const text = choice?.message?.content;
  if (!text) {
    throw new Error("Groq API returned no content in response.");
  }

  // finish_reason "length" means Groq hit the token cap and cut the
  // response off mid-generation — worth knowing about even when jsonrepair
  // (see generateJson below) manages to salvage a parseable object out of
  // the truncated text, since it means some content silently got dropped.
  if (choice.finish_reason === "length") {
    logger.warn("Groq response was truncated by max_tokens (finish_reason: length)");
  }

  return text;
}

/**
 * Calls Groq expecting a JSON object back, and safely parses it even if
 * the model wraps the JSON in ```json fences, or returns near-valid JSON
 * with a small formatting slip (a missing comma, an unescaped character,
 * or a response truncated mid-string). Long, content-rich prompts make
 * this kind of slip meaningfully more likely — the more text the model has
 * to generate, the more chances there are for one small mistake — so
 * rather than discarding the whole response over one bad character,
 * `jsonrepair` is used to patch it up before parsing. Falls back to
 * fallbackAnalysis() in the caller only if even that can't recover it.
 * @param {string} prompt
 * @param {{ model?: string, temperature?: number, max_tokens?: number }} [options]
 */
async function generateJson(prompt, options = {}) {
  const raw = await generateText(prompt, {
    temperature: 0.5,
    max_tokens: JSON_MAX_TOKENS,
    ...options,
  });
  const cleaned = raw
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```\s*$/i, "")
    .trim();

  try {
    return JSON.parse(cleaned);
  } catch (firstErr) {
    // First fallback (unchanged from before): the model sometimes wraps
    // valid JSON in stray prose despite instructions not to — grab just
    // the outermost {...} or [...] span and try again.
    const match = cleaned.match(/[[{][\s\S]*[\]}]/);
    const candidate = match ? match[0] : cleaned;

    try {
      return JSON.parse(candidate);
    } catch (secondErr) {
      // Second fallback (new): the JSON is genuinely malformed — a missing
      // comma, an unescaped quote, or an unclosed string/object from
      // truncation. jsonrepair fixes exactly these classes of problem.
      try {
        const repaired = jsonrepair(candidate);
        const parsed = JSON.parse(repaired);
        logger.warn("Groq JSON needed jsonrepair to parse successfully", {
          originalError: secondErr.message,
        });
        return parsed;
      } catch (thirdErr) {
        logger.error("Groq JSON could not be recovered even with jsonrepair", {
          firstErr: firstErr.message,
          secondErr: secondErr.message,
          thirdErr: thirdErr.message,
        });
        throw new Error(`Groq did not return valid JSON: ${firstErr.message}`);
      }
    }
  }
}

module.exports = { GROQ_API_KEY, generateText, generateJson };