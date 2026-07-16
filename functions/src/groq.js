const { defineSecret } = require("firebase-functions/params");

// Set this once with:
//   firebase functions:secrets:set GROQ_API_KEY
// Get a free key from https://console.groq.com/keys — no credit card required,
// genuinely free tier (rate-limited, not metered/prepaid like some providers).
const GROQ_API_KEY = defineSecret("GROQ_API_KEY");

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";

// llama-3.3-70b-versatile: best quality/speed balance on Groq's free tier,
// good enough for clinical summarization and conversational tutoring.
const DEFAULT_MODEL = "llama-3.3-70b-versatile";

/**
 * Calls Groq's OpenAI-compatible chat completions endpoint and returns raw
 * text. Uses plain fetch (built into Node 20) rather than an SDK — Groq's
 * API is a straightforward REST/JSON endpoint, so no client library is
 * needed, and it sidesteps any ESM/CommonJS packaging issues entirely.
 * @param {string} prompt
 * @param {{ model?: string, temperature?: number }} [options]
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
    }),
  });

  if (!res.ok) {
    const bodyText = await res.text().catch(() => "");
    throw new Error(`Groq API error ${res.status} ${res.statusText}: ${bodyText}`);
  }

  const data = await res.json();
  const text = data.choices?.[0]?.message?.content;
  if (!text) {
    throw new Error("Groq API returned no content in response.");
  }
  return text;
}

/**
 * Calls Groq expecting a JSON object back, and safely parses it even if
 * the model wraps the JSON in ```json fences.
 * @param {string} prompt
 * @param {{ model?: string, temperature?: number }} [options]
 */
async function generateJson(prompt, options = {}) {
  const raw = await generateText(prompt, { temperature: 0.5, ...options });
  const cleaned = raw
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```\s*$/i, "")
    .trim();
  try {
    return JSON.parse(cleaned);
  } catch (err) {
    const match = cleaned.match(/[[{][\s\S]*[\]}]/);
    if (match) {
      return JSON.parse(match[0]);
    }
    throw new Error(`Groq did not return valid JSON: ${err.message}`);
  }
}

module.exports = { GROQ_API_KEY, generateText, generateJson };
