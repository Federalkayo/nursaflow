// Pollinations.ai's anonymous image endpoint — no API key required, no
// billing, no ESM packaging issues (it's a plain HTTP GET). Rate-limited
// for anonymous use; if that ever becomes a problem, get a free key at
// https://enter.pollinations.ai and add an Authorization header — not
// needed for MVP-scale usage.
const POLLINATIONS_ENDPOINT = "https://image.pollinations.ai/prompt";

/**
 * Generates a single illustrative image for a study document and returns
 * it as a Buffer. Returns null on any failure — illustrations are a
 * nice-to-have, never worth blocking the rest of the document over.
 *
 * @param {{ title: string, course: string, overview: string, subject?: string }} params
 */
async function generateIllustration({ title, course, overview, subject }) {
  // Prefer the specific subject Groq chose (e.g. "the heart and major
  // arteries, walls thickened from chronic pressure") over the raw
  // document title — a bare disease/condition name like "Hypertension"
  // gives the image model nothing concrete to draw, so it defaults to a
  // generic whole-body/whole-system illustration instead of the one
  // structure that's actually clinically relevant.
  const visualSubject = subject && subject.trim() ? subject.trim() : `${title} (${course})`;

  const prompt = `Flat 2D vector-style anatomical/medical diagram for a nursing textbook. Subject: ${visualSubject}. Context: ${overview}. White or plain light background, simple labeled parts, thin clean outlines, muted clinical color palette (blues, teals, soft grays), no photorealistic style, no scene or setting, no watermark — just the labeled diagram itself, centered, professional and tasteful, no graphic or gory content, square composition.`;

  const url =
    `${POLLINATIONS_ENDPOINT}/${encodeURIComponent(prompt)}` +
    `?width=1024&height=1024&model=flux&nologo=true`;

  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Pollinations image request failed: ${res.status} ${res.statusText}`);
  }

  const arrayBuffer = await res.arrayBuffer();
  return Buffer.from(arrayBuffer);
}

/**
 * Generates an image directly from a free-form prompt (used for chat-
 * triggered "draw me a diagram of X" requests, as opposed to the automatic
 * per-document illustration above). Returns a Buffer, or null on failure.
 * @param {string} prompt
 */
async function generateImageFromPrompt(prompt) {
  const fullPrompt = `Flat 2D vector-style anatomical/medical diagram for a nursing textbook. Subject: ${prompt}. White or plain light background, simple labeled parts, thin clean outlines, muted clinical color palette (blues, teals, soft grays), no photorealistic people, no scene or setting, no watermark, no decorative background elements — just the labeled diagram itself, centered, professional and tasteful, no graphic or gory content.`;

  const url =
    `${POLLINATIONS_ENDPOINT}/${encodeURIComponent(fullPrompt)}` +
    `?width=1024&height=1024&model=flux&nologo=true`;

  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Pollinations image request failed: ${res.status} ${res.statusText}`);
  }

  const arrayBuffer = await res.arrayBuffer();
  return Buffer.from(arrayBuffer);
}

module.exports = { generateIllustration, generateImageFromPrompt };