// api/oauth-callback.js — one-time OAuth handshake to get a refresh token
export default async function handler(req, res) {
  const { code, error, error_description } = req.query;

  if (error) {
    return res.status(400).send(`<pre style="font-family:monospace;padding:24px;">OAuth Error: ${error}\n${error_description}</pre>`);
  }

  if (!code) {
    // No code yet → redirect to Microsoft login
    const CLIENT_ID    = process.env.ONEDRIVE_CLIENT_ID;
    const REDIRECT_URI = `https://${req.headers.host}/api/oauth-callback`;
    const authUrl = `https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize` +
      `?client_id=${CLIENT_ID}` +
      `&response_type=code` +
      `&redirect_uri=${encodeURIComponent(REDIRECT_URI)}` +
      `&scope=${encodeURIComponent('Files.Read offline_access')}` +
      `&response_mode=query` +
      `&prompt=consent`;
    return res.redirect(authUrl);
  }

  // Exchange code → tokens
  const CLIENT_ID     = process.env.ONEDRIVE_CLIENT_ID;
  const CLIENT_SECRET = process.env.ONEDRIVE_CLIENT_SECRET;
  const REDIRECT_URI  = `https://${req.headers.host}/api/oauth-callback`;

  const tokenRes = await fetch('https://login.microsoftonline.com/consumers/oauth2/v2.0/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id:     CLIENT_ID,
      client_secret: CLIENT_SECRET,
      code,
      redirect_uri:  REDIRECT_URI,
      grant_type:    'authorization_code',
      scope:         'Files.Read offline_access',
    }).toString()
  });

  const data = await tokenRes.json();

  if (!data.refresh_token) {
    return res.status(400).send(`<pre style="font-family:monospace;padding:24px;">Failed:\n${JSON.stringify(data, null, 2)}</pre>`);
  }

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
<html>
<head>
<title>OneDrive Connected ✓</title>
<style>
  body { font-family: system-ui, sans-serif; max-width: 680px; margin: 60px auto; padding: 0 24px; background: #fafaf9; color: #32302f; }
  .card { background: #fff; border: 1px solid #e4e2e1; border-radius: 16px; padding: 32px; }
  h2 { margin: 0 0 20px; font-size: 22px; }
  .step { margin-bottom: 14px; font-size: 14px; line-height: 1.6; }
  .step strong { display: block; margin-bottom: 4px; }
  pre { background: #1a1a1a; color: #88ddff; padding: 16px; border-radius: 10px; word-break: break-all; white-space: pre-wrap; font-size: 12px; user-select: all; cursor: text; }
  code { background: #f1f0f0; padding: 2px 6px; border-radius: 4px; font-size: 13px; }
  .copy-btn { background: #32302f; color: #fff; border: none; border-radius: 8px; padding: 8px 18px; font-size: 13px; cursor: pointer; margin-top: 8px; }
  .copy-btn:hover { opacity: 0.85; }
  .done { color: #486635; font-weight: 600; font-size: 16px; margin-bottom: 20px; }
</style>
</head>
<body>
<div class="card">
  <div class="done">✅ Microsoft account connected!</div>
  <h2>One more step — add this token to Vercel</h2>

  <div class="step">
    <strong>1. Copy your refresh token:</strong>
    <pre id="rt">${data.refresh_token}</pre>
    <button class="copy-btn" onclick="navigator.clipboard.writeText(document.getElementById('rt').textContent).then(()=>this.textContent='Copied!')">Copy token</button>
  </div>

  <div class="step">
    <strong>2. Add it to Vercel:</strong>
    Go to <a href="https://vercel.com/dashboard" target="_blank">vercel.com/dashboard</a> → your project → <strong>Settings → Environment Variables</strong><br>
    Add a new variable: <code>ONEDRIVE_REFRESH_TOKEN</code> = (paste token above)
  </div>

  <div class="step">
    <strong>3. Redeploy:</strong>
    Go to <strong>Deployments</strong> → click ⋯ on the latest → <strong>Redeploy</strong>
  </div>

  <div class="step">
    🎉 After redeployment, your Finance section will auto-sync Income and Spending from Excel every time you open the dashboard.
  </div>
</div>
</body>
</html>`);
}
