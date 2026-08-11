// api/instagram.js — Instagram data proxy via Apify
// Accepts the user's own Apify token from the x-apify-token header.
// No server-side keys — students bring their own.

const ACTOR_ID = 'apify~instagram-scraper';

function buildInput(username) {
  return { usernames: [username.replace(/^@/, '')], resultsLimit: 60 };
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-apify-token');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  const apifyToken = req.headers['x-apify-token'];
  if (!apifyToken) {
    res.status(400).json({ error: 'Missing Apify token. Open ⚙ API Keys in the top nav to add yours.' });
    return;
  }

  try {
    if (req.method === 'POST') {
      const { username } = req.body;
      if (!username) { res.status(400).json({ error: 'Missing username' }); return; }

      const r = await fetch(`https://api.apify.com/v2/acts/${ACTOR_ID}/runs`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apifyToken}` },
        body: JSON.stringify(buildInput(username)),
      });
      const data = await r.json();
      if (!r.ok) { res.status(r.status).json({ error: data.error?.message || 'Failed to start run' }); return; }
      res.status(200).json({ runId: data.data.id, datasetId: data.data.defaultDatasetId });

    } else if (req.method === 'GET') {
      const { runId, datasetId } = req.query;
      if (!runId) { res.status(400).json({ error: 'Missing runId' }); return; }

      const r = await fetch(`https://api.apify.com/v2/actor-runs/${runId}`, {
        headers: { 'Authorization': `Bearer ${apifyToken}` },
      });
      const data = await r.json();
      if (!r.ok) { res.status(r.status).json({ error: data.error?.message || 'Failed to check status' }); return; }

      const status = data.data.status;
      if (status === 'SUCCEEDED') {
        const dsId = datasetId || data.data.defaultDatasetId;
        const itemsRes = await fetch(`https://api.apify.com/v2/datasets/${dsId}/items?clean=true`, {
          headers: { 'Authorization': `Bearer ${apifyToken}` },
        });
        if (!itemsRes.ok) { res.status(500).json({ error: 'Failed to fetch dataset items' }); return; }
        const items = await itemsRes.json();
        res.status(200).json({ status: 'SUCCEEDED', items });
        return;
      }
      res.status(200).json({ status, items: [] });

    } else {
      res.status(405).json({ error: 'Method not allowed' });
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
