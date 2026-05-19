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
    if (req.method === 'GET' && req.query.action === 'weather') {
      const lat = parseFloat(req.query.lat) || 43.7315;
      const lon = parseFloat(req.query.lon) || -79.7624;
      const tz  = req.query.tz || 'America/Toronto';
      const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=weather_code,temperature_2m_max&forecast_days=7&timezone=${encodeURIComponent(tz)}`;
      const r = await fetch(url);
      if (!r.ok) { res.status(r.status).json({ error: `Open-Meteo ${r.status}` }); return; }
      const json = await r.json();
      res.setHeader('Cache-Control', 's-maxage=3600, stale-while-revalidate=1800');
      res.json(json);
      return;
    }

    // Notion create — POST ?action=notion-create { title, status, date, pillar }
    if (req.method === 'POST' && req.query.action === 'notion-create') {
      const NOTION_TOKEN = process.env.NOTION_TOKEN;
      const NOTION_DB_ID = '2abfe55527ec81e89715defee0fbb96c';
      if (!NOTION_TOKEN) { res.status(503).json({ error: 'NOTION_TOKEN not configured' }); return; }
      const DASHBOARD_TO_NOTION_STATUS = { idea:'Idea', scripting:'Scripting', filming:'Filming', editing:'Editing', scheduled:'Awaiting Approval', posted:'Posted' };
      const { title, status, date, pillar } = req.body || {};
      if (!title) { res.status(400).json({ error: 'title required' }); return; }
      const properties = {
        'Video Idea': { title: [{ text: { content: title } }] },
        'Status': { select: { name: DASHBOARD_TO_NOTION_STATUS[status] || 'Idea' } },
      };
      if (date) properties['Date'] = { date: { start: date } };
      if (pillar) properties['Content Pillar'] = { select: { name: pillar } };
      const nRes = await fetch('https://api.notion.com/v1/pages', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${NOTION_TOKEN}`, 'Notion-Version': '2022-06-28', 'Content-Type': 'application/json' },
        body: JSON.stringify({ parent: { database_id: NOTION_DB_ID }, properties }),
      });
      if (!nRes.ok) { res.status(nRes.status).json({ error: `Notion API ${nRes.status}` }); return; }
      const page = await nRes.json();
      res.json({ ok: true, notionId: page.id });
      return;
    }

    // Notion content calendar sync — GET ?action=notion-calendar
    // Reads Platform Content Calendar from Notion API and returns entries with date+status
    if (req.method === 'GET' && req.query.action === 'notion-calendar') {
      const NOTION_TOKEN = process.env.NOTION_TOKEN;
      const NOTION_DB_ID = '2abfe55527ec81e89715defee0fbb96c';
      if (!NOTION_TOKEN) { res.status(503).json({ error: 'NOTION_TOKEN not configured' }); return; }

      const NOTION_STATUS = { 'Idea':'idea','Scripting':'scripting','Filming':'filming','Editing':'editing','Awaiting Approval':'scheduled','Posted':'posted' };

      // Query Notion database for all entries that have a date set
      const nRes = await fetch(`https://api.notion.com/v1/databases/${NOTION_DB_ID}/query`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${NOTION_TOKEN}`,
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ page_size: 100, filter: { property: 'Date', date: { is_not_empty: true } } }),
      });
      if (!nRes.ok) { res.status(nRes.status).json({ error: `Notion API ${nRes.status}` }); return; }
      const nJson = await nRes.json();

      const entries = (nJson.results || []).map(page => {
        const props = page.properties || {};
        const titleArr = props['Video Idea']?.title || [];
        const title = titleArr.map(t => t.plain_text).join('');
        const date = props['Date']?.date?.start || null;
        const status = NOTION_STATUS[props['Status']?.select?.name] || 'idea';
        const pillar = props['Content Pillar']?.select?.name || '';
        return { notionId: page.id, title, date, status, pillar, notionUrl: page.url };
      }).filter(e => e.date && e.title);

      res.setHeader('Cache-Control', 'no-store');
      res.json({ entries });
      return;
    }

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
