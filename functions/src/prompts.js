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
  const contextBlock = hasSourceText
    ? `Base your output strictly on the following lecture material. Do not invent facts not supported by it:\n\n"""\n${sourceText}\n"""`
    : `No extractable text was available for this upload (likely a slide deck or scanned document format not yet supported). Generate clinically accurate, exam-relevant nursing content appropriate for a course titled "${course}" and a document titled "${title}". Be conservative and stick to well-established nursing curriculum content.`;

  return `You are a nursing education content expert generating structured study material for a nursing student app called NursaFlow.

Document title: "${title}"
Course: "${course}"

${contextBlock}

Return ONLY a single JSON object (no markdown fences, no commentary) with this exact shape:

{
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
- "keyQuote": always include a genuine, topic-specific quote/pearl — never generic filler
- "keyPrinciples": exactly 3 items
- "assessmentNote": only non-empty if this topic has a real assessment/exam component (skip for purely conceptual topics like anatomy structure with no exam technique involved)
- "assessmentHierarchy": 2-3 items
- "clinicalRedFlags": 2-3 items
- "takeaways": exactly 3 items
- "flashcards": 6-8 items, testing distinct facts
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
- Example mermaid value: "flowchart LR\\nA[Right Atrium] --> B[Right Ventricle]\\nB --> C[Lungs]\\nC --> D[Left Atrium]\\nD --> E[Left Ventricle]\\nE --> F[Body]\\nF --> A"`;
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