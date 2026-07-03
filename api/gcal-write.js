// api/gcal-write.js — Google Calendar write integration
//
// GET  ?action=auth              → redirect to Google OAuth consent screen
// GET  ?code=...                 → exchange code for refresh token, store in Redis
// POST { events: [...] }         → create events in Google Calendar
// GET  ?action=status            → check if connected

const SCOPES = 'https://www.googleapis.com/auth/calendar.events';
const REDIS_TOKEN_KEY = 'riffy-gcal-refresh-token';

function getRedirectUri(req) {
  const host = req.headers.host;
  const proto = host.startsWith('localhost') ? 'http' : 'https';
  return `${proto}://${host}/api/gcal-write`;
}

function isAuthorized(req) {
  const origin = req.headers['origin'] || req.headers['referer'] || '';
  if (!origin) return true;
  return origin.startsWith('https://riffy-dashboard.vercel.app') || origin.startsWith('http://localhost');
}

async function getAccessToken(refreshToken, clientId, clientSecret) {
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id:     clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type:    'refresh_token',
    }).toString(),
  });
  const data = await r.json();
  if (!data.access_token) throw new Error(data.error_description || 'Failed to refresh access token');
  return data.access_token;
}

export default async function handler(req, res) {
  const origin = req.headers['origin'] || 'https://riffy-dashboard.vercel.app';
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Vary', 'Origin');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  const CLIENT_ID     = process.env.GOOGLE_CLIENT_ID;
  const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;

  const REDIS_URL   = process.env.UPSTASH_REDIS_REST_URL;
  const REDIS_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN;

  const upstash = cmd => fetch(REDIS_URL, {
    method: 'POST',
    headers: { Authorization: `Bearer ${REDIS_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(cmd),
  }).then(r => r.json());

  // ── GET ?action=auth → redirect to Google OAuth ──────────────────────────
  if (req.method === 'GET' && req.query.action === 'auth') {
    if (!CLIENT_ID) {
      res.status(503).send('GOOGLE_CLIENT_ID not configured. See setup instructions.');
      return;
    }
    const authUrl = 'https://accounts.google.com/o/oauth2/v2/auth?' + new URLSearchParams({
      client_id:     CLIENT_ID,
      redirect_uri:  getRedirectUri(req),
      response_type: 'code',
      scope:         SCOPES,
      access_type:   'offline',
      prompt:        'consent',
    }).toString();
    res.redirect(authUrl);
    return;
  }

  // ── GET ?code=... → OAuth callback, exchange for refresh token ───────────
  if (req.method === 'GET' && req.query.code) {
    if (!CLIENT_ID || !CLIENT_SECRET) {
      res.status(503).send('Google OAuth credentials not configured.');
      return;
    }
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id:     CLIENT_ID,
        client_secret: CLIENT_SECRET,
        code:          req.query.code,
        redirect_uri:  getRedirectUri(req),
        grant_type:    'authorization_code',
      }).toString(),
    });
    const data = await tokenRes.json();
    if (!data.refresh_token) {
      res.status(400).send(`<pre>OAuth failed:\n${JSON.stringify(data, null, 2)}</pre>`);
      return;
    }
    await upstash(['SET', REDIS_TOKEN_KEY, data.refresh_token, 'EX', 60 * 60 * 24 * 365]);
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(`<!DOCTYPE html><html><head><title>Google Calendar Connected ✓</title>
<style>body{font-family:system-ui,sans-serif;max-width:520px;margin:80px auto;padding:0 24px;background:#f9f9f7;color:#222;}
.card{background:#fff;border:1px solid #e4e2e0;border-radius:16px;padding:32px;}
h2{margin:0 0 12px;font-size:20px;}p{color:#555;line-height:1.6;margin:0 0 20px;}
a{display:inline-block;background:#222;color:#fff;padding:10px 22px;border-radius:8px;text-decoration:none;font-size:14px;}</style></head>
<body><div class="card"><h2>✅ Google Calendar connected!</h2>
<p>Your Riffy Dashboard can now push schedule events directly to your Google Calendar. Close this tab and click <strong>Sync Calendar</strong> on the dashboard.</p>
<a href="/">← Back to Dashboard</a></div></body></html>`);
    return;
  }

  // ── GET ?action=status → check if connected ───────────────────────────────
  if (req.method === 'GET' && req.query.action === 'status') {
    if (!isAuthorized(req)) { res.status(403).json({ error: 'Forbidden' }); return; }
    const { result } = await upstash(['EXISTS', REDIS_TOKEN_KEY]);
    res.json({ connected: result === 1 });
    return;
  }

  // ── POST { events } → create events in Google Calendar ───────────────────
  if (req.method === 'POST') {
    if (!isAuthorized(req)) { res.status(403).json({ error: 'Forbidden' }); return; }
    if (!CLIENT_ID || !CLIENT_SECRET) {
      res.status(503).json({ error: 'Google OAuth credentials not configured in Vercel env vars (GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET).' });
      return;
    }

    const { result: refreshToken } = await upstash(['GET', REDIS_TOKEN_KEY]);
    if (!refreshToken) {
      res.status(401).json({ error: 'not_connected', message: 'Google Calendar not connected. Click Connect first.' });
      return;
    }

    const { events, calendarId = 'primary' } = req.body || {};
    if (!events || !events.length) { res.status(400).json({ error: 'No events provided' }); return; }

    let accessToken;
    try { accessToken = await getAccessToken(refreshToken, CLIENT_ID, CLIENT_SECRET); }
    catch (e) { res.status(401).json({ error: 'token_refresh_failed', message: e.message }); return; }

    const results = [];
    for (const evt of events) {
      try {
        const r = await fetch(`https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(evt),
        });
        const data = await r.json();
        results.push({ ok: r.ok, id: data.id, summary: data.summary, error: data.error?.message });
      } catch (e) {
        results.push({ ok: false, error: e.message });
      }
    }

    const failed = results.filter(r => !r.ok);
    res.json({ ok: true, created: results.filter(r => r.ok).length, failed: failed.length, results });
    return;
  }

  res.status(405).json({ error: 'Method not allowed' });
}
