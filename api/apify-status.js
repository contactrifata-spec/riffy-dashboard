// api/apify-status.js — polls an Apify run and returns results when done
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

export default async function handler(req, res) {
  const origin = req.headers['origin'] || 'https://riffy-dashboard.vercel.app';
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-dashboard-secret');
  res.setHeader('Vary', 'Origin');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!isAuthorized(req)) { res.status(403).json({ error: 'Forbidden' }); return; }

  const APIFY_TOKEN = process.env.APIFY_API_KEY;
  if (!APIFY_TOKEN) { res.status(503).json({ error: 'Server not configured: missing APIFY_API_KEY' }); return; }

  const { runId, datasetId } = req.query;
  if (!runId) { res.status(400).json({ error: 'Missing runId' }); return; }

  try {
    const r = await fetch(`https://api.apify.com/v2/actor-runs/${runId}`, {
      headers: { 'Authorization': `Bearer ${APIFY_TOKEN}` },
    });
    const data = await r.json();
    if (!r.ok) { res.status(r.status).json({ error: data.error?.message || 'Failed to check run status' }); return; }

    const status = data.data.status;

    if (status === 'SUCCEEDED') {
      const dsId = datasetId || data.data.defaultDatasetId;
      const itemsRes = await fetch(`https://api.apify.com/v2/datasets/${dsId}/items?clean=true`, {
        headers: { 'Authorization': `Bearer ${APIFY_TOKEN}` },
      });
      if (!itemsRes.ok) { res.status(500).json({ error: 'Failed to fetch dataset items' }); return; }
      const items = await itemsRes.json();
      res.status(200).json({ status: 'SUCCEEDED', items });
      return;
    }

    if (['FAILED', 'ABORTED', 'TIMED-OUT'].includes(status)) {
      res.status(200).json({ status, items: [] });
      return;
    }

    res.status(200).json({ status, items: [] });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
