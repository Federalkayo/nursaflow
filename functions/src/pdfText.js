const pdfParse = require("pdf-parse");

/**
 * Extracts text from a downloaded file buffer, based on its extension.
 * Returns { text, pageCount, supported }. For formats we can't parse yet
 * (pptx/docx), returns supported: false so the caller can fall back to a
 * course-based prompt instead of failing outright.
 * @param {Buffer} buffer
 * @param {string} fileName
 */
async function extractText(buffer, fileName) {
  const ext = (fileName.split(".").pop() || "").toLowerCase();

  if (ext === "pdf") {
    const data = await pdfParse(buffer);
    return {
      text: data.text.slice(0, 60000), // guard against huge documents blowing the prompt budget
      pageCount: data.numpages || 0,
      supported: true,
    };
  }

  // TODO: add pptx/docx extraction (e.g. via `mammoth` for docx,
  // `officeparser` or a Pandoc-based approach for pptx) in a later pass.
  return { text: "", pageCount: 0, supported: false };
}

module.exports = { extractText };
