// api/claude.js — Claude API proxy
// Key lives in ANTHROPIC_API_KEY env var, never in frontend code.
// Auth: browser requests validated by Origin header; direct calls need x-dashboard-secret.

function isAuthorized(req) {
  const origin = req.headers['origin'] || req.headers['referer'] || '';
  const secret = req.headers['x-dashboard-secret'];
  const allowed = process.env.VERCEL_URL
    ? [`https://${process.env.VERCEL_URL}`, 'https://riffy-dashboard.vercel.app']
    : ['https://riffy-dashboard.vercel.app'];
  if (allowed.some(a => origin.startsWith(a))) return true;
  if (origin.startsWith('http://localhost')) return true;
  const ds = process.env.DASHBOARD_SECRET;
  if (ds && secret === ds) return true;
  return false;
}

export default async function handler(req, res) {
  const origin = req.headers['origin'] || 'https://riffy-dashboard.vercel.app';
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-dashboard-secret');
  res.setHeader('Vary', 'Origin');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'Method not allowed' }); return; }

  if (!isAuthorized(req)) {
    res.status(403).json({ error: 'Forbidden' });
    return;
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    res.status(503).json({ error: 'Server not configured: missing ANTHROPIC_API_KEY' });
    return;
  }

  const { messages, system, model = 'claude-sonnet-4-6', max_tokens = 1024 } = req.body;
  if (!messages || !Array.isArray(messages)) {
    res.status(400).json({ error: 'Missing messages array' });
    return;
  }

  try {
    const body = { model, max_tokens, messages };
    if (system) body.system = system;

    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify(body),
    });

    const data = await r.json();
    if (!r.ok) {
      res.status(r.status).json({ error: data.error?.message || 'Claude API error' });
      return;
    }
    res.status(200).json(data);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
