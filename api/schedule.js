// api/schedule.js — Riffy widget schedule sync via Upstash Redis
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  const REDIS_URL   = process.env.UPSTASH_REDIS_REST_URL;
  const REDIS_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN;

  if (!REDIS_URL || !REDIS_TOKEN) {
    res.status(503).json({ error: 'Widget sync not configured. Add UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN to Vercel env vars.' });
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
      const { result } = await upstash(['GET', 'riffy-schedule']);
      const schedule = result ? JSON.parse(result) : [];
      res.setHeader('Cache-Control', 'no-store');
      res.json({ schedule, updatedAt: result ? new Date().toISOString() : null });

    } else if (req.method === 'POST') {
      const { schedule } = req.body;
      if (!Array.isArray(schedule)) { res.status(400).json({ error: 'schedule must be an array' }); return; }
      await upstash(['SET', 'riffy-schedule', JSON.stringify(schedule)]);
      res.json({ ok: true });

    } else {
      res.status(405).json({ error: 'Method not allowed' });
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
