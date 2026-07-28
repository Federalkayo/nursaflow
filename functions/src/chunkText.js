// Matches headings like "Chapter 4", "Chapter 12: Molecular Diagnostics",
// "CHAPTER 4 - Something" — case-insensitive, optional colon/dash/period
// separator before the heading title. This intentionally targets the
// "Chapter N" convention specifically (rather than trying to guess at
// every possible heading style) since that's the convention used by
// NursaFlow's own long-form reference notes and by most textbook-style
// uploads students are likely to bring in.
const CHAPTER_HEADING_REGEX = /(^|\n)\s*(Chapter\s+(\d+)\s*[:.\-–]?\s*([^\n]*))/gi;

// A document needs at least this many distinct chapter headings before
// we bother splitting it — below this, it's more likely a short lecture
// that just happens to mention the word "chapter" once or twice, and
// treating it as a single chunk (current/original behavior) is correct.
const MIN_CHAPTERS_TO_SPLIT = 3;

// Cap on how much of any single chapter's text we persist per chunk.
// Keeps individual Firestore documents small and keeps the amount of text
// later injected into a single AI Tutor prompt bounded and cheap, while
// still comfortably covering a normal chapter's worth of content.
const MAX_CHARS_PER_CHAPTER = 12000;

/**
 * Splits extracted document text into per-chapter chunks wherever
 * "Chapter N" style headings are found. Returns an array of
 *   { index, chapterNumber, heading, text }
 * - chapterNumber is the integer parsed from the heading (e.g. 4 for
 *   "Chapter 4: ..."), or null if it couldn't be parsed for some entry.
 * - heading is the short title text following "Chapter N" (may be empty).
 * - text is that chapter's content, truncated to MAX_CHARS_PER_CHAPTER.
 *
 * If fewer than MIN_CHAPTERS_TO_SPLIT headings are found, the whole text
 * is returned as a single chunk (index 0, chapterNumber null) rather than
 * being split — this keeps normal single-topic lecture uploads behaving
 * exactly as a single unit, unchanged from before this feature existed.
 *
 * @param {string} text - full, untruncated extracted document text
 * @returns {Array<{index:number, chapterNumber:number|null, heading:string, text:string}>}
 */
function splitIntoChapters(text) {
  if (!text || !text.trim()) return [];

  const rawMatches = [...text.matchAll(CHAPTER_HEADING_REGEX)];

  if (rawMatches.length < MIN_CHAPTERS_TO_SPLIT) {
    return [
      {
        index: 0,
        chapterNumber: null,
        heading: "",
        text: text.trim().slice(0, MAX_CHARS_PER_CHAPTER),
      },
    ];
  }

  // Many documents (this one included) include a Table of Contents — or a
  // separate listing like an assessment schedule — that repeats lines like
  // "Chapter 2: The Chain of Infection..." well before the real Chapter 2
  // heading appears in the body. A naive scan treats every one of those
  // listing lines as its own chapter boundary, which both fragments real
  // chapters AND, worse, means the WRONG occurrence (the near-empty TOC
  // line, immediately followed by the next TOC line) can end up being the
  // one persisted and later looked up by the AI Tutor for that chapter
  // number — exactly the bug this comment is here to prevent regressing.
  //
  // Fix: compute how much text follows each raw match before the next raw
  // match (its "content span"). A real chapter heading is followed by
  // substantial body content; a TOC/listing entry is followed almost
  // immediately by the next listing entry, so its span is tiny by
  // comparison. When the same chapter number appears more than once, only
  // its occurrence with the largest span is kept as the real heading.
  const spans = rawMatches.map((m, i) => {
    const nextIndex = i + 1 < rawMatches.length ? rawMatches[i + 1].index : text.length;
    return nextIndex - m.index;
  });

  const bestByChapterNumber = new Map();
  rawMatches.forEach((match, i) => {
    const chapterNumberRaw = match[3];
    // Unnumbered "Chapter" mentions (shouldn't really happen given the
    // regex requires \d+, but guard anyway) are each kept as their own key
    // so they're never accidentally merged with a real numbered chapter.
    const key = chapterNumberRaw ? parseInt(chapterNumberRaw, 10) : `unnumbered-${match.index}`;
    const span = spans[i];
    const existing = bestByChapterNumber.get(key);
    if (!existing || span > existing.span) {
      bestByChapterNumber.set(key, { match, span });
    }
  });

  const realMatches = [...bestByChapterNumber.values()]
    .map((v) => v.match)
    .sort((a, b) => a.index - b.index);

  if (realMatches.length < MIN_CHAPTERS_TO_SPLIT) {
    return [
      {
        index: 0,
        chapterNumber: null,
        heading: "",
        text: text.trim().slice(0, MAX_CHARS_PER_CHAPTER),
      },
    ];
  }

  const chunks = [];
  for (let i = 0; i < realMatches.length; i++) {
    const match = realMatches[i];
    // matchAll index is relative to the full string; matches[i].index
    // points at the start of the captured leading group (which may be a
    // newline), so we use the offset of the actual heading text itself.
    const headingStart = match.index + match[1].length;
    const chunkEnd = i + 1 < realMatches.length ? realMatches[i + 1].index : text.length;

    const chapterNumberRaw = match[3];
    const chapterNumber = chapterNumberRaw ? parseInt(chapterNumberRaw, 10) : null;
    const heading = (match[4] || "").trim();

    const chunkText = text.slice(headingStart, chunkEnd).trim();

    chunks.push({
      index: i,
      chapterNumber: Number.isFinite(chapterNumber) ? chapterNumber : null,
      heading,
      text: chunkText.slice(0, MAX_CHARS_PER_CHAPTER),
    });
  }

  return chunks;
}

module.exports = { splitIntoChapters };