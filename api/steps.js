// api/steps.js — Apple Health step count sync via Upstash Redis
// POST { steps: 8432 }  → stores step count (called by iOS Shortcut)
// GET                   → returns latest step count + timestamp
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  const REDIS_URL   = process.env.UPSTASH_REDIS_REST_URL;
  const REDIS_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN;

  if (!REDIS_URL || !REDIS_TOKEN) {
    res.status(503).json({ error: 'Redis not configured.' });
    return;
  }

  const upstash = (cmd) =>
    fetch(REDIS_URL, {
      method:  'POST',
      headers: { Authorization: `Bearer ${REDIS_TOKEN}`, 'Content-Type': 'application/json' },
      body:    JSON.stringify(cmd),
    }).then(r => r.json());

  try {
    if (req.method === 'GET') {
      const { result } = await upstash(['GET', 'riffy-steps']);
      if (!result) { res.json({ steps: null, updatedAt: null }); return; }
      const data = JSON.parse(result);
      res.setHeader('Cache-Control', 'no-store');
      res.json(data);

    } else if (req.method === 'POST') {
      const steps = Number(req.body?.steps);
      if (!Number.isFinite(steps) || steps < 0) {
        res.status(400).json({ error: 'steps must be a non-negative number' });
        return;
      }
      const payload = { steps, updatedAt: new Date().toISOString() };
      await upstash(['SET', 'riffy-steps', JSON.stringify(payload)]);
      res.json({ ok: true, steps });

    } else {
      res.status(405).json({ error: 'Method not allowed' });
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
