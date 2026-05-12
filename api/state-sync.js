// api/state-sync.js — cross-device state sync via Upstash Redis
// GET  ?key=<key>          → return { value, updatedAt } for any riffy-* key
// GET  ?action=crm-sheet   → proxy-fetch the CRM Google Sheet and return rows as JSON
// POST { key, value }      → store value under key

function isAuthorized(req) {
  const origin = req.headers['origin'] || req.headers['referer'] || '';
  const secret = req.headers['x-dashboard-secret'];
  if (origin.startsWith('https://riffy-dashboard.vercel.app')) return true;
  if (origin.startsWith('http://localhost')) return true;
  // PWA/iOS standalone requests sometimes send no origin — allow if no origin at all
  if (!origin) return true;
  const ds = process.env.DASHBOARD_SECRET;
  if (ds && secret === ds) return true;
  return false;
}

export default async function handler(req, res) {
  const origin = req.headers['origin'] || 'https://riffy-dashboard.vercel.app';
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
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
    if (req.method === 'GET' && req.query.action === 'ideas-sheet') {
      const IDEAS_SHEET_ID = '1jlDrA_MDdqEfF9lxqwXT7Q7cT1lEj0IJNnQsv4EEbac';
      const sheetUrl = `https://docs.google.com/spreadsheets/d/${IDEAS_SHEET_ID}/gviz/tq?tqx=out:json&range=F3:F1000`;
      const r = await fetch(sheetUrl, { headers: { 'User-Agent': 'riffy-dashboard/1.0' } });
      if (!r.ok) { res.status(r.status).json({ error: `Sheet fetch failed: ${r.status}` }); return; }
      const raw = await r.text();
      const json = JSON.parse(raw.replace(/^[^(]+\(/, '').replace(/\);?\s*$/, ''));
      const texts = (json?.table?.rows || [])
        .map(r => r?.c?.[0]?.v)
        .filter(v => v && typeof v === 'string' && v.trim().length > 0)
        .map(v => v.trim());
      res.setHeader('Cache-Control', 'no-store');
      res.json({ texts });
      return;
    }

    if (req.method === 'GET' && req.query.action === 'crm-sheet') {
      const CRM_SHEET_ID = '1CRTPlpmxWYmWvI4CjjEPRCyhw-7MKez4cbwZoCWIofI';
      // sheet = e.g. "May 2026" — passed by the client to target the right tab
      const sheet = req.query.sheet || '';
      const sheetParam = sheet ? `&sheet=${encodeURIComponent(sheet)}` : '';
      const sheetUrl = `https://docs.google.com/spreadsheets/d/${CRM_SHEET_ID}/gviz/tq?tqx=out:json${sheetParam}&range=A5:F1000`;
      const r = await fetch(sheetUrl, { headers: { 'User-Agent': 'riffy-dashboard/1.0' } });
      if (!r.ok) { res.status(r.status).json({ error: `Sheet fetch failed: ${r.status}` }); return; }
      const raw = await r.text();
      const json = JSON.parse(raw.replace(/^[^(]+\(/, '').replace(/\);?\s*$/, ''));
      // User-specified columns (A=0,B=1,C=2,D=3,E=4,F=5):
      // A=Client Name  C=Status  D=Deliverables  E=Total Rate  F=Date(Contracted)
      const rows = (json?.table?.rows || []).map(row => ({
        name:         row?.c?.[0]?.v ?? null,  // A
        status:       row?.c?.[2]?.v ?? null,  // C
        deliverables: row?.c?.[3]?.v ?? null,  // D
        rate:         row?.c?.[4]?.v ?? null,  // E
        date:         row?.c?.[5]?.v ?? null,  // F
      }));
      res.setHeader('Cache-Control', 'no-store');
      res.json({ rows });
      return;
    }

    if (req.method === 'GET') {
      const key = req.query.key;
      if (!key || !key.startsWith('riffy-')) { res.status(400).json({ error: 'Invalid key' }); return; }
      const { result } = await upstash(['GET', key]);
      if (!result) { res.status(404).json({ value: null, updatedAt: null }); return; }
      const parsed = JSON.parse(result);
      res.setHeader('Cache-Control', 'no-store');
      res.json(parsed); // { value, updatedAt }

    } else if (req.method === 'POST') {
      const { key, value } = req.body || {};
      if (!key || !key.startsWith('riffy-')) { res.status(400).json({ error: 'Invalid key' }); return; }
      if (value === undefined) { res.status(400).json({ error: 'Missing value' }); return; }
      const payload = JSON.stringify({ value, updatedAt: new Date().toISOString() });
      await upstash(['SET', key, payload, 'EX', 60 * 60 * 24 * 90]); // 90-day TTL
      res.json({ ok: true });

    } else {
      res.status(405).json({ error: 'Method not allowed' });
    }
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
