// api/weather.js — proxy Open-Meteo so the browser never hits it directly
// GET ?lat=43.73&lon=-79.76   → returns 7-day forecast JSON
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  const lat = parseFloat(req.query.lat) || 43.7315;
  const lon = parseFloat(req.query.lon) || -79.7624;
  const tz  = req.query.tz || 'America/Toronto';

  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=weather_code,temperature_2m_max&forecast_days=7&timezone=${encodeURIComponent(tz)}`;

  try {
    const r = await fetch(url);
    if (!r.ok) { res.status(r.status).json({ error: `Open-Meteo error ${r.status}` }); return; }
    const json = await r.json();
    res.setHeader('Cache-Control', 's-maxage=3600, stale-while-revalidate=1800');
    res.json(json);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
}
