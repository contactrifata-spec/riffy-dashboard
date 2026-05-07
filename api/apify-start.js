const APIFY_TOKEN = 'apify_api_FipNWGwlUcfMYldqrQ5jRqf4Y5xUZN02Z9Os';

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
  return {
    directUrls: [`https://www.instagram.com/${username}/`],
    resultsType: 'posts',
    resultsLimit: 60,
  };
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'Method not allowed' }); return; }

  const { platform, username } = req.body;
  if (!platform || !username) {
    res.status(400).json({ error: 'Missing platform or username' });
    return;
  }

  const actorId = ACTORS[platform];
  if (!actorId) {
    res.status(400).json({ error: `Unknown platform: ${platform}` });
    return;
  }

  try {
    const r = await fetch(
      `https://api.apify.com/v2/acts/${actorId}/runs`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${APIFY_TOKEN}`,
        },
        body: JSON.stringify(buildInput(platform, username)),
      }
    );
    const data = await r.json();
    if (!r.ok) {
      res.status(r.status).json({ error: data.error?.message || 'Failed to start Apify run' });
      return;
    }
    res.status(200).json({ runId: data.data.id, datasetId: data.data.defaultDatasetId });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
