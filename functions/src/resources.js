const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

// Set once with:
//   firebase functions:secrets:set GOOGLE_API_KEY
// One Google Cloud API key covering both APIs used here — enable "YouTube
// Data API v3" and "Books API" on the same project at
// https://console.cloud.google.com/apis/credentials, then set that single
// key as this one secret.
const GOOGLE_API_KEY = defineSecret("GOOGLE_API_KEY");

// Reference materials for a fixed topic don't change day to day, so a long
// cache TTL keeps YouTube/Books quota usage low without students ever
// noticing stale results. MedlinePlus is keyless so it costs us nothing,
// but it's cached alongside the others for a consistent single fetch.
const CACHE_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

/**
 * Search YouTube for lecture-style videos on a nursing topic.
 * Returns up to 5 results: { videoId, title, channelTitle, thumbnailUrl }.
 */
async function fetchYoutube(query) {
  const params = new URLSearchParams({
    part: "snippet",
    q: `${query} nursing lecture explained`,
    type: "video",
    maxResults: "5",
    safeSearch: "strict",
    relevanceLanguage: "en",
    key: GOOGLE_API_KEY.value(),
  });
  const res = await fetch(`https://www.googleapis.com/youtube/v3/search?${params}`);
  if (!res.ok) {
    throw new Error(`YouTube API error ${res.status}: ${await res.text().catch(() => "")}`);
  }
  const data = await res.json();
  return (data.items || [])
    .filter((item) => item.id?.videoId)
    .map((item) => ({
      videoId: item.id.videoId,
      title: item.snippet?.title || "Untitled",
      channelTitle: item.snippet?.channelTitle || "",
      thumbnailUrl:
        item.snippet?.thumbnails?.medium?.url || item.snippet?.thumbnails?.default?.url || "",
    }));
}

/**
 * Search Google Books for authoritative nursing textbook references on a topic.
 * Returns up to 5 results: { title, authors, thumbnailUrl, infoLink }.
 */
async function fetchBooks(query) {
  const params = new URLSearchParams({
    q: `${query} nursing textbook`,
    maxResults: "5",
    printType: "books",
    key: GOOGLE_API_KEY.value(),
  });
  const res = await fetch(`https://www.googleapis.com/books/v1/volumes?${params}`);
  if (!res.ok) {
    throw new Error(`Google Books API error ${res.status}: ${await res.text().catch(() => "")}`);
  }
  const data = await res.json();
  return (data.items || []).map((item) => {
    const info = item.volumeInfo || {};
    // Google Books image links are http:// by default, which gets blocked
    // by default mixed-content/App Transport Security rules on iOS/Android
    // network images — force https.
    const rawThumb = info.imageLinks?.thumbnail || info.imageLinks?.smallThumbnail || "";
    return {
      title: info.title || "Untitled",
      authors: (info.authors || []).join(", "),
      thumbnailUrl: rawThumb.replace("http://", "https://"),
      infoLink: info.infoLink || info.previewLink || "",
    };
  });
}

/**
 * Look up a topic on MedlinePlus's public search feed — no API key
 * required. Returns up to 5 student-friendly reference results:
 * { title, url, snippet }.
 */
async function fetchMedlinePlus(query) {
  const params = new URLSearchParams({
    db: "healthTopics",
    term: query,
    retmax: "5",
    rettype: "brief",
  });
  const res = await fetch(`https://wsearch.nlm.nih.gov/ws/query?${params}`);
  if (!res.ok) {
    throw new Error(`MedlinePlus API error ${res.status}: ${await res.text().catch(() => "")}`);
  }
  const xml = await res.text();
  return parseMedlinePlusXml(xml).slice(0, 5);
}

/**
 * MedlinePlus's search endpoint returns XML, and there's no XML parser
 * already in this functions package — rather than add a dependency for one
 * feed, this pulls out just the few fields needed with regex against the
 * feed's stable, documented structure. This is NOT a general-purpose XML
 * parser and shouldn't be reused for arbitrary XML.
 */
function parseMedlinePlusXml(xml) {
  const documents = xml.split("<document ").slice(1);
  const stripTags = (s) => (s || "").replace(/<[^>]+>/g, "").trim();
  return documents
    .map((docChunk) => {
      const urlMatch = docChunk.match(/url="([^"]+)"/);
      const titleMatch = docChunk.match(/<content name="title">([\s\S]*?)<\/content>/);
      const snippetMatch = docChunk.match(/<content name="snippet">([\s\S]*?)<\/content>/);
      return {
        title: stripTags(titleMatch?.[1]) || "MedlinePlus Topic",
        url: urlMatch?.[1] || "",
        snippet: stripTags(snippetMatch?.[1]),
      };
    })
    .filter((d) => d.url);
}

/**
 * Callable function: fetchResources({ documentId: string })
 *
 * Uses the document's title (falling back to its course) as the search
 * topic across YouTube, Google Books, and MedlinePlus, and caches the
 * combined result on the document itself (resources + resourcesFetchedAt)
 * so reopening the Resources tab doesn't re-spend API quota. Each provider
 * is looked up independently — if one fails or is rate-limited, the other
 * two still return normally and that section just shows empty client-side.
 */
const fetchResources = onCall(
  {
    secrets: [GOOGLE_API_KEY],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in to view resources.");
    }

    const uid = request.auth.uid;
    const documentId = request.data?.documentId;
    if (!documentId) {
      throw new HttpsError("invalid-argument", "documentId is required.");
    }

    const docRef = admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("documents")
      .doc(documentId);
    const docSnap = await docRef.get();
    if (!docSnap.exists) {
      throw new HttpsError("not-found", "Document not found.");
    }
    const doc = docSnap.data();

    // Serve from cache if it's still fresh.
    const fetchedAtMs = doc.resourcesFetchedAt?.toMillis?.();
    if (doc.resources && fetchedAtMs && Date.now() - fetchedAtMs < CACHE_TTL_MS) {
      return doc.resources;
    }

    const topic = doc.title || doc.course || "nursing fundamentals";
    logger.info(`Fetching resources for document ${documentId}`, { topic });

    const [youtube, books, medline] = await Promise.all([
      fetchYoutube(topic).catch((err) => {
        logger.warn(`YouTube lookup failed for "${topic}"`, err);
        return [];
      }),
      fetchBooks(topic).catch((err) => {
        logger.warn(`Google Books lookup failed for "${topic}"`, err);
        return [];
      }),
      fetchMedlinePlus(topic).catch((err) => {
        logger.warn(`MedlinePlus lookup failed for "${topic}"`, err);
        return [];
      }),
    ]);

    const resources = { youtube, books, medline };

    await docRef.update({
      resources,
      resourcesFetchedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return resources;
  }
);

module.exports = { fetchResources };