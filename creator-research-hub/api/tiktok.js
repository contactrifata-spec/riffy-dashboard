// api/tiktok.js — TikTok data proxy
// Accepts the user's own RapidAPI key from the x-rapidapi-key header.
// No server-side keys — students bring their own.

const RAPIDAPI_HOST = 'tiktok-scraper7.p.rapidapi.com';
const BASE_URL = `https://${RAPIDAPI_HOST}`;

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-rapidapi-key');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'GET') { res.status(405).json({ error: 'Method not allowed' }); return; }

  const apiKey = req.headers['x-rapidapi-key'];
  if (!apiKey) {
    res.status(400).json({ error: 'Missing RapidAPI key. Open ⚙ API Keys in the top nav to add yours.' });
    return;
  }

  const { path = '/', ...rest } = req.query;
  const params = new URLSearchParams(rest).toString();
  const url = `${BASE_URL}${path}${params ? '?' + params : ''}`;

  try {
    const r = await fetch(url, {
      method: 'GET',
      headers: {
        'x-rapidapi-key': apiKey,
        'x-rapidapi-host': RAPIDAPI_HOST,
      },
    });
    const data = await r.json();
    res.status(r.status).json(data);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
