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
 * Ask YouTube's oEmbed endpoint whether a video allows embedded playback.
 * 200 -> embeddable. 401/403/404 (owner disabled embedding, or video is
 * private/deleted) -> not embeddable. Any other failure (network blip,
 * 5xx) defaults to true so a transient error never wrongly hides "Watch
 * in App" for a video that actually would have played fine.
 */
async function checkEmbeddable(videoId) {
  const url = `https://www.youtube.com/oembed?url=${encodeURIComponent(
    `https://www.youtube.com/watch?v=${videoId}`
  )}&format=json`;
  try {
    const res = await fetch(url);
    if (res.status === 401 || res.status === 403 || res.status === 404) return false;
    return true;
  } catch (err) {
    logger.warn(`oEmbed check failed for ${videoId}, defaulting to embeddable`, err);
    return true;
  }
}

/**
 * Parses YouTube's ISO 8601 video duration (e.g. "PT14M32S", "PT1H2M") into
 * a short student-facing label like "14 min" or "1h 2m". Returns "" if the
 * string doesn't parse, so callers can safely omit the badge rather than
 * show something broken.
 */
function formatDuration(iso8601) {
  const match = /^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/.exec(iso8601 || "");
  if (!match) return "";
  const hours = parseInt(match[1] || "0", 10);
  const minutes = parseInt(match[2] || "0", 10);
  const seconds = parseInt(match[3] || "0", 10);
  if (hours > 0) return `${hours}h ${minutes}m`;
  if (minutes > 0) return `${minutes} min`;
  return `${seconds}s`;
}

/**
 * Looks up video lengths for a batch of video IDs via videos.list. This is
 * a single call regardless of how many IDs (up to 50) — 1 quota unit total,
 * versus 100 units for the search call itself — so this is cheap even
 * though it runs on every cache-miss alongside the search.
 * Returns a Map<videoId, durationLabel>.
 */
async function fetchDurations(videoIds) {
  if (videoIds.length === 0) return new Map();
  const params = new URLSearchParams({
    part: "contentDetails",
    id: videoIds.join(","),
    key: GOOGLE_API_KEY.value(),
  });
  try {
    const res = await fetch(`https://www.googleapis.com/youtube/v3/videos?${params}`);
    if (!res.ok) {
      logger.warn(`videos.list duration lookup failed: ${res.status}`);
      return new Map();
    }
    const data = await res.json();
    return new Map(
      (data.items || []).map((item) => [
        item.id,
        formatDuration(item.contentDetails?.duration),
      ])
    );
  } catch (err) {
    logger.warn("videos.list duration lookup threw", err);
    return new Map();
  }
}

/**
 * Search YouTube for lecture-style videos on a nursing topic.
 * Returns up to 5 results: { videoId, title, channelTitle, thumbnailUrl, embeddable, duration }.
 */
async function fetchYoutube(query) {
  const params = new URLSearchParams({
    part: "snippet",
    q: `${query} nursing lecture`,
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
  const videos = (data.items || [])
    .filter((item) => item.id?.videoId)
    .map((item) => ({
      videoId: item.id.videoId,
      title: item.snippet?.title || "Untitled",
      channelTitle: item.snippet?.channelTitle || "",
      thumbnailUrl:
        item.snippet?.thumbnails?.medium?.url || item.snippet?.thumbnails?.default?.url || "",
    }));

  // oEmbed check (embeddability) and duration lookup run in parallel with
  // each other — they're independent of one another, just both dependent
  // on the search results above. Both get cached on the document, so this
  // full cost is paid once per topic, not per student.
  const [embeddableFlags, durations] = await Promise.all([
    Promise.all(videos.map((v) => checkEmbeddable(v.videoId))),
    fetchDurations(videos.map((v) => v.videoId)),
  ]);
  return videos.map((v, i) => ({
    ...v,
    embeddable: embeddableFlags[i],
    duration: durations.get(v.videoId) || "",
  }));
}


/**
 * Search Google Books for authoritative nursing textbook references on a topic.
 * Returns up to 5 results: { title, authors, thumbnailUrl, infoLink }.
 */
async function fetchBooks(query) {
  const params = new URLSearchParams({
    q: `${query} nursing textbook subject:medicine`,
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
  const decodeEntities = (s) =>
    (s || "")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&amp;/g, "&");
  const stripTags = (s) => decodeEntities(s).replace(/<[^>]+>/g, "").trim();
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

    const topic = doc.mainTopic || doc.title || doc.course || "nursing fundamentals";
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

    const resources = {
      youtube,
      books,
      medline,
      query: topic,
      updatedAt: new Date().toISOString(),
    };

    await docRef.update({
      resources,
      resourcesFetchedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return resources;
  }
);

module.exports = { fetchResources };