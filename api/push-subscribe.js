// api/push-subscribe.js — save / delete Web Push subscriptions in Upstash Redis
// POST { subscription } → stores; DELETE { endpoint } → removes

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
  res.setHeader('Access-Control-Allow-Methods', 'POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-dashboard-secret');
  res.setHeader('Vary', 'Origin');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!isAuthorized(req)) { res.status(403).json({ error: 'Forbidden' }); return; }

  const REDIS_URL   = process.env.UPSTASH_REDIS_REST_URL;
  const REDIS_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!REDIS_URL || !REDIS_TOKEN) { res.status(503).json({ error: 'Redis not configured' }); return; }

  const upstash = cmd => fetch(REDIS_URL, {
    method: 'POST',
    headers: { Authorization: `Bearer ${REDIS_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(cmd),
  }).then(r => r.json());

  try {
    if (req.method === 'POST') {
      const sub = req.body;
      if (!sub?.endpoint) { res.status(400).json({ error: 'Invalid subscription object' }); return; }
      await upstash(['HSET', 'riffy-push-subs', sub.endpoint, JSON.stringify(sub)]);
      res.json({ ok: true });

    } else if (req.method === 'DELETE') {
      const { endpoint } = req.body || {};
      if (!endpoint) { res.status(400).json({ error: 'Missing endpoint' }); return; }
      await upstash(['HDEL', 'riffy-push-subs', endpoint]);
      res.json({ ok: true });

    } else {
      res.status(405).json({ error: 'Method not allowed' });
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
