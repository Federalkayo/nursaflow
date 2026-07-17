/**
 * Used only if the Gemini call itself fails (network error, quota, bad
 * response) so a document never gets permanently stuck in "processing"
 * instead of the student seeing real AI content. Deliberately generic.
 */
function fallbackAnalysis(title, course) {
  return {
    mainTopic: course,
    clinicalOverview: `This document covers key concepts from "${title}" in ${course}. We weren't able to generate a full AI summary this time — try re-uploading, or ask the AI Tutor directly about topics from this document.`,
    keyPrinciples: [
      { title: "Review Core Concepts", body: "Revisit your lecture notes for the foundational definitions covered in this material." },
      { title: "Cross-Reference Textbook", body: "Use your course textbook to fill in any gaps while we retry processing." },
      { title: "Ask the AI Tutor", body: "You can ask specific questions about this topic directly in the AI Tutor chat." },
    ],
    assessmentHierarchy: [
      { title: "General Assessment", body: "Follow standard head-to-toe or systems-based assessment order for this topic." },
    ],
    clinicalRedFlags: [
      { title: "When in doubt, escalate", body: "Always report any signs outside expected parameters to your clinical instructor." },
    ],
    takeaways: [
      `Key concepts from ${course}`,
      "Ask the AI Tutor for a personalized breakdown",
      "Try re-uploading for a full AI summary",
    ],
    flashcards: [
      {
        question: `What is one key concept from "${title}"?`,
        answer: "Ask the AI Tutor for a detailed breakdown of this document.",
        explanation: "Full AI-generated flashcards will appear once processing succeeds.",
      },
    ],
    quiz: [
      {
        tag: course.toUpperCase(),
        question: "This quiz will be regenerated shortly. In the meantime, would you like to ask the AI Tutor a practice question?",
        options: ["Yes, ask the tutor", "I'll wait", "Re-upload the document", "Check back later"],
        correctIndex: 0,
        explanation: "This is placeholder content shown only when AI processing temporarily fails.",
      },
    ],
  };
}

module.exports = { fallbackAnalysis };