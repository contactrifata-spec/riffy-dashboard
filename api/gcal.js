// api/gcal.js — fetches private Google Calendar iCal
// GCAL_PRIVATE_URL lives in env vars, never in frontend code.

export default async function handler(req, res) {
  const origin = req.headers['origin'] || 'https://riffy-dashboard.vercel.app';
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Vary', 'Origin');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  const ICAL_URL = process.env.GCAL_PRIVATE_URL;
  if (!ICAL_URL) {
    res.status(503).send('Server not configured: missing GCAL_PRIVATE_URL');
    return;
  }

  try {
    const r = await fetch(ICAL_URL, { headers: { 'User-Agent': 'riffy-dashboard/1.0' } });
    if (!r.ok) { res.status(r.status).send('Failed to fetch calendar: ' + r.status); return; }
    const text = await r.text();
    res.setHeader('Content-Type', 'text/calendar; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    res.status(200).send(text);
  } catch (e) {
    res.status(500).send('Error: ' + e.message);
  }
}
