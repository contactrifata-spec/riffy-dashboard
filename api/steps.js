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
      // Accept simple { steps: N } OR Health Auto Export format { data: { metrics: [...] } }
      let steps = Number(req.body?.steps);
      if (!Number.isFinite(steps)) {
        // Health Auto Export format
        const metrics = req.body?.data?.metrics || req.body?.metrics || [];
        const stepMetric = metrics.find(m =>
          m.name === 'step_count' || m.name === 'steps' || /step/i.test(m.name)
        );
        if (stepMetric) {
          const entries = stepMetric.data || [];
          // Sum all entries for today, or take the latest qty
          const todayStr = new Date().toISOString().slice(0, 10);
          const todayEntries = entries.filter(e => e.date && String(e.date).startsWith(todayStr));
          if (todayEntries.length > 0) {
            steps = todayEntries.reduce((sum, e) => sum + Number(e.qty || 0), 0);
          } else if (entries.length > 0) {
            // Take the most recent entry
            steps = Number(entries[entries.length - 1].qty || 0);
          }
        }
      }
      if (!Number.isFinite(steps) || steps < 0) {
        res.status(400).json({ error: 'steps must be a non-negative number' });
        return;
      }
      steps = Math.round(steps);
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
