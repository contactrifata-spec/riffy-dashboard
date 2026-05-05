export default async function handler(req, res) {
  const ICAL_URL = 'https://calendar.google.com/calendar/ical/rifat%40riffycreates.com/private-3e6a8b2550e625ab22c486b8fa9890bb/basic.ics';
  try {
    const r = await fetch(ICAL_URL, {
      headers: { 'User-Agent': 'riffy-dashboard/1.0' }
    });
    if (!r.ok) {
      res.status(r.status).send('Failed to fetch calendar: ' + r.status);
      return;
    }
    const text = await r.text();
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Content-Type', 'text/calendar; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    res.status(200).send(text);
  } catch (e) {
    res.status(500).send('Error: ' + e.message);
  }
}
