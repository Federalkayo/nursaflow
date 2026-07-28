const { splitIntoChapters } = require("./chunkText");

// Groq's free tier caps requests at 12,000 tokens/minute for
// llama-3.3-70b-versatile (shared across whatever else is calling the same
// model in this org, e.g. concurrent askTutor calls). generateJson already
// reserves JSON_MAX_TOKENS (4096) for the output, and the instructions/schema
// portion of this prompt runs roughly 800-1000 tokens on its own, so the
// source text itself needs to fit in a modest budget or the request gets
// rejected outright with a 413 before Groq ever generates anything (as
// opposed to a truncated/malformed response, which is a different failure
// mode that jsonrepair handles). ~18,000 characters of English prose is
// roughly 3,500-4,000 tokens, which leaves comfortable headroom under the
// 12,000 cap even accounting for concurrent usage.
const MAX_SOURCE_CHARS = 18000;
// Floor so that even a document with an unusually large number of chapters
// doesn't get sliced into useless few-word fragments per chapter.
const MIN_PER_CHAPTER_CHARS = 250;

/**
 * Builds the text that actually gets embedded in the analysis prompt for a
 * document with extracted source text. For a normal single-topic upload
 * (no "Chapter N" structure, or short enough to fit as-is) this is just the
 * text itself, capped to MAX_SOURCE_CHARS. For a long, multi-chapter
 * reference document, naively taking the first MAX_SOURCE_CHARS characters
 * would only ever show Groq the first few chapters — since the prompt
 * explicitly asks for flashcards/mainTopic to reflect the document's full
 * breadth, that would silently bias every broad-reference analysis toward
 * whatever happens to be at the start. Instead, in that case, a bounded
 * excerpt is sampled from every detected chapter so the model actually sees
 * the whole document's scope within the same character budget.
 * @param {string} sourceText - full, untruncated extracted document text
 * @returns {{ text: string, wasSampled: boolean }}
 */
function buildSourceExcerpt(sourceText) {
  if (sourceText.length <= MAX_SOURCE_CHARS) {
    return { text: sourceText, wasSampled: false };
  }

  const chunks = splitIntoChapters(sourceText);

  // Fewer than MIN_CHAPTERS_TO_SPLIT chapter headings (in chunkText.js) means
  // splitIntoChapters already returned a single, already-capped chunk — for
  // this case a straightforward truncation is the correct behavior, it's
  // just one long document, not a multi-chapter reference.
  if (chunks.length <= 1) {
    return { text: sourceText.slice(0, MAX_SOURCE_CHARS), wasSampled: true };
  }

  const perChapterChars = Math.max(
    MIN_PER_CHAPTER_CHARS,
    Math.floor(MAX_SOURCE_CHARS / chunks.length)
  );

  const sampled = chunks
    .map((c) => {
      const label = c.chapterNumber
        ? `Chapter ${c.chapterNumber}${c.heading ? ": " + c.heading : ""}`
        : c.heading || `Section ${c.index + 1}`;
      return `[${label}]\n${c.text.slice(0, perChapterChars)}`;
    })
    .join("\n\n");

  // Label overhead can push slightly over budget for documents with many
  // chapters — hard cap as a final safety net so we never exceed it.
  return { text: sampled.slice(0, MAX_SOURCE_CHARS), wasSampled: true };
}

/**
 * Builds the prompt for turning a lecture document (or, when text isn't
 * available, just a title + course) into NursaFlow's summary/flashcard/quiz
 * schema. Field names below MUST match lib/features/home/models/document.dart,
 * flashcard.dart, and quiz_question.dart exactly — the Flutter app reads
 * these verbatim from Firestore.
 *
 * @param {{ title: string, course: string, sourceText: string, hasSourceText: boolean }} params
 */
function buildAnalysisPrompt({ title, course, sourceText, hasSourceText }) {
  // Heuristic: detect whether this upload is a broad, multi-chapter reference
  // document (e.g. a textbook-style note spanning many distinct clinical
  // subjects) rather than a single focused lecture. Long documents with many
  // "Chapter N" / numbered-heading markers are the giveaway — a normal
  // lecture PDF rarely has more than a handful of headings.
  // Computed on the full, untruncated sourceText so this detection stays
  // accurate regardless of how much gets sampled/truncated below.
  const chapterHeadingMatches = hasSourceText
    ? (sourceText.match(/\bChapter\s+\d+\b/gi) || []).length
    : 0;
  const isLikelyBroadReference =
    hasSourceText && (sourceText.length > 15000 || chapterHeadingMatches >= 6);

  let contextBlock;
  if (hasSourceText) {
    const { text: excerptText, wasSampled } = buildSourceExcerpt(sourceText);
    const truncationNote = wasSampled
      ? isLikelyBroadReference
        ? "\n\n(Note: this document is long, so what follows is a representative excerpt sampled from every chapter/section rather than the full text — base your analysis on the overall scope this shows you.)"
        : "\n\n(Note: this document is long, so what follows is truncated to an initial excerpt rather than the full text.)"
      : "";
    contextBlock = `Base your output strictly on the following lecture material. Do not invent facts not supported by it:\n\n"""\n${excerptText}\n"""${truncationNote}`;
  } else {
    contextBlock = `No extractable text was available for this upload (likely a slide deck or scanned document format not yet supported). Generate clinically accurate, exam-relevant nursing content appropriate for a course titled "${course}" and a document titled "${title}". Be conservative and stick to well-established nursing curriculum content.`;
  }

  const mainTopicInstruction = isLikelyBroadReference
    ? `this document appears to be a BROAD, MULTI-CHAPTER REFERENCE covering many distinct clinical subjects rather than a single focused lecture topic (it has ${chapterHeadingMatches} chapter-style headings and/or is unusually long). Do NOT pick a single recurring keyword or an example that merely appears in several unrelated chapters — that will misrepresent the document. Instead set this to the overarching discipline or course-level subject the document as a whole belongs to, 2-5 words (e.g. 'Medical Laboratory Science', 'Pharmacology Fundamentals', 'Medical-Surgical Nursing'). Base this on the document's actual title/scope and the breadth of topics covered, not on any single section`
    : `the canonical clinical topic this document is actually about, 2-5 words, suitable as a search query on external resource sites (e.g. 'Chronic Kidney Disease', 'Congestive Heart Failure', 'Fluid and Electrolyte Imbalance') — this is NOT the filename or document title, which may be uninformative (e.g. 'Lecture 5.pdf', 'Week 8 Notes'); infer the real subject from the content itself`;

  return `You are a nursing education content expert generating structured study material for a nursing student app called NursaFlow.

Document title: "${title}"
Course: "${course}"

${contextBlock}

Return ONLY a single JSON object (no markdown fences, no commentary) with this exact shape:

{
  "mainTopic": "${mainTopicInstruction}",
  "clinicalOverview": "2-4 sentence overview paragraph",
  "keyQuote": "one short, memorable, clinically-relevant quote or teaching pearl about this specific topic (1-2 sentences, no attribution needed)",
  "keyPrinciples": [
    {"title": "short principle name", "body": "1-2 sentence explanation"}
  ],
  "assessmentNote": "1 sentence of practical guidance on HOW to approach assessing this specific topic (e.g. ordering, technique, patient interaction) — only include if this topic has a genuine assessment/exam component; use empty string \"\" otherwise",
  "assessmentHierarchy": [
    {"title": "assessment step or category", "body": "1-2 sentence explanation"}
  ],
  "clinicalRedFlags": [
    {"title": "warning sign name", "body": "1 sentence explanation of clinical significance"}
  ],
  "takeaways": ["short high-yield concept phrase", "..."],
  "mermaid": "mermaid diagram syntax, or empty string if not applicable — see rules below",
  "illustrationSubject": "a specific, narrow visual subject for an accompanying diagram (3-8 words, e.g. 'the heart and major arteries under pressure', 'a single nephron cross-section', 'the layers of the epidermis') — only needed when mermaid is empty; use empty string \"\" otherwise",
  "flashcards": [
    {"question": "...", "answer": "...", "explanation": "1 sentence explaining why"}
  ],
  "quiz": [
    {
      "tag": "SHORT CATEGORY LABEL",
      "question": "scenario-based or factual nursing question",
      "options": ["option A", "option B", "option C", "option D"],
      "correctIndex": 0,
      "explanation": "1-2 sentence rationale for the correct answer"
    }
  ]
}

Requirements:
- "mainTopic": always required, never empty. If sourceText is available, infer it from the actual content, not the title. If no sourceText, fall back to the clinical subject implied by the course name.
- "keyQuote": always include a genuine, topic-specific quote/pearl — never generic filler
- "keyPrinciples": exactly 3 items
- "assessmentNote": only non-empty if this topic has a real assessment/exam component (skip for purely conceptual topics like anatomy structure with no exam technique involved)
- "assessmentHierarchy": 2-3 items
- "clinicalRedFlags": 2-3 items
- "takeaways": exactly 3 items
- "flashcards": 6-8 items, testing distinct facts${isLikelyBroadReference ? " — for a broad reference document, draw these from across DIFFERENT chapters/sections so they represent the document's overall breadth, not just one section" : ""}
- "quiz": 4-5 items, "options" always has exactly 4 entries, "correctIndex" is 0-3
- Keep clinical content accurate and appropriate for a nursing student audience
- No text outside the JSON object

Rules for "mermaid":
- If this topic is a PROCESS, MECHANISM, CYCLE, DECISION TREE, or STEP SEQUENCE
  (e.g. blood circulation, the nursing process, disease progression, a clinical
  algorithm, medication administration steps), include a valid Mermaid
  flowchart diagram as a single-line string (use \\n for line breaks within
  the string). Use "flowchart TD" or "flowchart LR". Keep it to 5-10 nodes,
  short labels (2-4 words each).
- If this topic is primarily ANATOMICAL/DESCRIPTIVE (e.g. structure of an
  organ, cell types, a body system overview) rather than a process, set
  "mermaid" to an empty string "" — a diagram doesn't add value there and an
  illustration is more appropriate instead. In this case, "illustrationSubject"
  MUST name a single, specific structure or narrow scene — never the whole
  document topic verbatim. For a disease/condition topic (e.g.
  "Hypertension"), name the specific anatomical structure most relevant to
  that condition (e.g. "the heart and major arteries, walls thickened from
  chronic elevated pressure"), not a generic full-body or whole-system
  illustration.
${
  isLikelyBroadReference
    ? `- If this document is a broad multi-chapter reference (as flagged above) with no single dominant process, set "mermaid" to an empty string "" and instead make "illustrationSubject" a narrow scene representative of the document's general discipline (e.g. "a clinical laboratory bench with analysers and blood tubes"), rather than trying to force a diagram of one specific topic buried in one chapter.\n`
    : ""
}- Example mermaid value: "flowchart LR\\nA[Right Atrium] --> B[Right Ventricle]\\nB --> C[Lungs]\\nC --> D[Left Atrium]\\nD --> E[Left Ventricle]\\nE --> F[Body]\\nF --> A"`;
}

/**
 * Builds the prompt for a single AI Tutor turn.
 * @param {{ userMessage: string, documentContext: string|null, history: Array<{sender:string,text:string}> }} params
 */
function buildTutorPrompt({ userMessage, documentContext, history }) {
  const historyBlock = history
    .map((m) => `${m.sender === "user" ? "Student" : "Tutor"}: ${m.text}`)
    .join("\n");

  const contextBlock = documentContext
    ? `The student has an uploaded document with this summary context — use it when relevant, but you can also answer general nursing questions:\n"""\n${documentContext}\n"""\n\n`
    : "";

  return `You are NursaFlow's AI Tutor — a friendly, encouraging, clinically accurate study partner for nursing students. Use plain language and stay focused on nursing/clinical content. See formatting rules below for how to structure your answer.

${contextBlock}Recent conversation:
${historyBlock}

Student: ${userMessage}

Respond as the Tutor. Format your reply for readability, the way a good tutor writes notes:
- Break your answer into short paragraphs (2-3 sentences each), separated by a blank line — never one dense wall of text.
- When listing multiple items, causes, types, or steps, use a bullet on its own line starting with "• " (a plain bullet character), one item per line — not a comma-separated sentence.
- Do NOT use markdown syntax like **bold**, # headers, or numbered "1." lists with periods — the app displays this as plain text, so that syntax would show up as literal stray characters instead of formatting. Structure comes from line breaks and "• " bullets only.
- Keep it focused: 2-5 short paragraphs/bullet groups unless the student explicitly asks for more detail.

IMPORTANT — do not speculate about the uploaded document's specific contents.
If the student asks about a specific section, chapter, or detail of their
document and the context above does not actually contain that information
(including if it contains a "Note:" saying that content isn't available),
say so plainly and briefly rather than guessing. Never write phrases like
"likely covers", "may include", or "probably discusses" about the student's
own uploaded document — either you have the real content and can state it
directly, or you don't and should say you don't have that specific section
available yet. This restriction is only about the student's uploaded
document; you can still answer general nursing knowledge questions normally
using what you already know.

If (and only if) the student is asking about a PROCESS, MECHANISM, CYCLE, or
STEP SEQUENCE (e.g. "explain blood circulation", "walk me through the nursing
process", "how does X progress"), include a short Mermaid flowchart diagram
after your explanation, wrapped in a \`\`\`mermaid code fence, like:

\`\`\`mermaid
flowchart LR
A[Right Atrium] --> B[Right Ventricle]
B --> C[Lungs]
\`\`\`

Keep the diagram to 5-10 nodes with short labels. Do not include a diagram
for purely factual or definitional questions — only for processes.`;
}

module.exports = { buildAnalysisPrompt, buildTutorPrompt };