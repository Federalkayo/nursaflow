# NursaFlow Cloud Functions

Two functions, powered by **Groq** (text) and **Pollinations.ai** (images) —
switched from Gemini after hitting repeated instability (a deprecated model
ID, and a "prepayment credits depleted" error on what should've been a free
key). Both providers here are genuinely free with no billing surprises.

- **`analyzeDocument`** — fires automatically whenever a new document is
  created at `users/{uid}/documents/{docId}` in Firestore (which happens the
  moment `upload_screen.dart` finishes its Firestore write). Extracts PDF
  text if available, calls Groq (Llama 3.3 70B) for the summary/flashcards/
  quiz, calls Pollinations for an illustration, writes everything back to
  Firestore.

- **`askTutor`** — callable function. The Flutter client writes the
  student's own message to Firestore directly (unchanged). This function
  reads chat history + document context, calls Groq, writes the reply back
  to the same Firestore path — the client's existing stream listener picks
  it up automatically.

## One-time setup

### 1. Get a free Groq API key
Go to **https://console.groq.com/keys** → Create API Key. No credit card
required. This is a genuinely free tier gated only by rate limits (30
requests/min, ~1,000 requests/day on `llama-3.3-70b-versatile`) — not a
prepaid-credits system, so it won't suddenly demand billing mid-use the way
the previous provider did.

### 2. Set it as a Cloud Functions secret
From the project root (not inside `functions/`):
```bash
firebase functions:secrets:set GROQ_API_KEY
```
Paste the key when prompted.

### 3. Images need no key at all
Pollinations.ai's anonymous image endpoint (`image.pollinations.ai/prompt/...`)
requires no API key, no signup, no secret to configure. If you ever hit
rate limits on it, get a free key at https://enter.pollinations.ai and add
an `Authorization: Bearer` header in `src/imageGen.js` — not needed for
MVP-scale usage.

### 4. Install dependencies
```bash
cd functions
npm install
```
Notably lighter than before — no Gemini SDKs, no ESM/CommonJS packaging
issues, just `firebase-admin`, `firebase-functions`, and `pdf-parse`. Both
Groq and Pollinations are called with plain `fetch` (built into Node 20),
no client library needed.

### 5. Deploy
```bash
firebase deploy --only functions
```

## Watching it work

```bash
firebase functions:log
```
Tail this while uploading a document — you'll see `analyzeDocument` fire,
log progress, then finish. Groq's LPU hardware is notably fast (3-10x
quicker than typical GPU-based inference), so expect summaries back in a
few seconds rather than the 10-15s Gemini sometimes took.

## Known limitations (MVP)

- Only **PDF** text extraction is implemented — `.pptx`/`.docx` uploads
  fall back to generating course-appropriate content from the title/course
  alone rather than the actual file content.
- Groq's free tier is rate-limited (not prepaid), so heavy simultaneous
  usage (e.g. many students during exam season) may occasionally hit a 429
  — the app should retry/queue rather than fail hard once you have real
  traffic at that scale. Not an issue at current testing volume.
- Pollinations' anonymous image endpoint has no documented hard rate limit
  but is best-effort/community infrastructure — if illustrations start
  failing under load, get a free API key rather than assuming it's a bug.
