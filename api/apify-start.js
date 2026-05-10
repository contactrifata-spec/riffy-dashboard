// api/apify-start.js — starts an Apify actor run
// APIFY_API_KEY lives in env vars, never in frontend code.

function isAuthorized(req) {
  const origin = req.headers['origin'] || req.headers['referer'] || '';
  const secret = req.headers['x-dashboard-secret'];
  if (origin.startsWith('https://riffy-dashboard.vercel.app')) return true;
  if (origin.startsWith('http://localhost')) return true;
  const ds = process.env.DASHBOARD_SECRET;
  if (ds && secret === ds) return true;
  return false;
}

const ACTORS = {
  tiktok: 'clockworks~tiktok-scraper',
  instagram: 'apify~instagram-scraper',
};

function buildInput(platform, username) {
  if (platform === 'tiktok') {
    return {
      profiles: [`@${username}`],
      resultsType: 'posts',
      maxPostsPerPage: 60,
      shouldDownloadVideos: false,
      shouldDownloadCovers: false,
      shouldDownloadSubtitles: false,
    };
  }
  const url = username.startsWith('http')
    ? username
    : `https://www.instagram.com/${username}/`;
  return {
    directUrls: [url],
    resultsType: 'posts',
    resultsLimit: 60,
  };
}

export default async function handler(req, res) {
  const origin = req.headers['origin'] || 'https://riffy-dashboard.vercel.app';
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-dashboard-secret');
  res.setHeader('Vary', 'Origin');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'Method not allowed' }); return; }

  if (!isAuthorized(req)) { res.status(403).json({ error: 'Forbidden' }); return; }

  const APIFY_TOKEN = process.env.APIFY_API_KEY;
  if (!APIFY_TOKEN) { res.status(503).json({ error: 'Server not configured: missing APIFY_API_KEY' }); return; }

  const { platform, username } = req.body;
  if (!platform || !username) { res.status(400).json({ error: 'Missing platform or username' }); return; }

  const actorId = ACTORS[platform];
  if (!actorId) { res.status(400).json({ error: `Unknown platform: ${platform}` }); return; }

  try {
    const r = await fetch(`https://api.apify.com/v2/acts/${actorId}/runs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${APIFY_TOKEN}`,
      },
      body: JSON.stringify(buildInput(platform, username)),
    });
    const data = await r.json();
    if (!r.ok) { res.status(r.status).json({ error: data.error?.message || 'Failed to start Apify run' }); return; }
    res.status(200).json({ runId: data.data.id, datasetId: data.data.defaultDatasetId });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
