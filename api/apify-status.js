const APIFY_TOKEN = 'apify_api_FipNWGwlUcfMYldqrQ5jRqf4Y5xUZN02Z9Os';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  const { runId, datasetId } = req.query;
  if (!runId) { res.status(400).json({ error: 'Missing runId' }); return; }

  try {
    const r = await fetch(
      `https://api.apify.com/v2/actor-runs/${runId}`,
      { headers: { 'Authorization': `Bearer ${APIFY_TOKEN}` } }
    );
    const data = await r.json();
    if (!r.ok) {
      res.status(r.status).json({ error: data.error?.message || 'Failed to check run status' });
      return;
    }

    const status = data.data.status;

    if (status === 'SUCCEEDED') {
      const dsId = datasetId || data.data.defaultDatasetId;
      const itemsRes = await fetch(
        `https://api.apify.com/v2/datasets/${dsId}/items?clean=true`,
        { headers: { 'Authorization': `Bearer ${APIFY_TOKEN}` } }
      );
      if (!itemsRes.ok) {
        res.status(500).json({ error: 'Failed to fetch dataset items' });
        return;
      }
      const items = await itemsRes.json();
      res.status(200).json({ status: 'SUCCEEDED', items });
      return;
    }

    if (status === 'FAILED' || status === 'ABORTED' || status === 'TIMED-OUT') {
      res.status(200).json({ status, items: [] });
      return;
    }

    res.status(200).json({ status, items: [] });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
