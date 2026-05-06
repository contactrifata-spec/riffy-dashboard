// api/excel.js — Microsoft Graph proxy for OneDrive Excel sync
export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cache-Control', 'no-store');

  const CLIENT_ID     = process.env.ONEDRIVE_CLIENT_ID;
  const CLIENT_SECRET = process.env.ONEDRIVE_CLIENT_SECRET;
  const REFRESH_TOKEN = process.env.ONEDRIVE_REFRESH_TOKEN;

  if (!CLIENT_ID || !CLIENT_SECRET || !REFRESH_TOKEN) {
    return res.status(503).json({ error: 'not_configured' });
  }

  try {
    // ── 1. Refresh access token ──
    const tokenRes = await fetch('https://login.microsoftonline.com/consumers/oauth2/v2.0/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id:     CLIENT_ID,
        client_secret: CLIENT_SECRET,
        grant_type:    'refresh_token',
        refresh_token: REFRESH_TOKEN,
        scope:         'Files.Read offline_access',
      }).toString()
    });

    const tokenData = await tokenRes.json();
    if (!tokenData.access_token) {
      return res.status(401).json({ error: 'token_failed', detail: tokenData.error_description || tokenData.error });
    }
    const token = tokenData.access_token;

    // ── 2. Resolve sharing URL → drive item ──
    const sharingUrl = 'https://1drv.ms/x/c/b61863ae2d16bf39/IQDBMvY4flqaT5uiHpmuxhNkAdGVYtNfm09vo5Oa_Sd0YKg?e=ZzjABb';
    const encoded = 'u!' + Buffer.from(sharingUrl).toString('base64')
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');

    const shareRes = await fetch(`https://graph.microsoft.com/v1.0/shares/${encoded}/driveItem`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    const shareData = await shareRes.json();

    if (!shareData.id) {
      return res.status(400).json({ error: 'share_resolve_failed', detail: shareData });
    }

    const driveId = shareData.parentReference?.driveId;
    const itemId  = shareData.id;
    const base    = driveId
      ? `https://graph.microsoft.com/v1.0/drives/${driveId}/items/${itemId}`
      : `https://graph.microsoft.com/v1.0/me/drive/items/${itemId}`;

    // ── 3. Determine current month sheet tab ──
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    const sheet  = months[new Date().getMonth()];

    async function readRange(range) {
      const r = await fetch(
        `${base}/workbook/worksheets/${encodeURIComponent(sheet)}/range(address='${encodeURIComponent(range)}')`,
        { headers: { Authorization: `Bearer ${token}` } }
      );
      const d = await r.json();
      return d?.values ?? null;
    }

    // ── 4. Fetch summary cells ──
    const [incomeVals, spendingVals, categoriesVals] = await Promise.all([
      readRange('D71'),
      readRange('J5'),
      readRange('AW25:AX30'),
    ]);

    const income   = incomeVals?.[0]?.[0]   ?? null;
    const spending = spendingVals?.[0]?.[0] ?? null;

    // categories: [[name, amount], ...]  — filter empty rows
    const categories = (categoriesVals ?? [])
      .filter(row => row[0] && row[1] != null)
      .map(row => ({ name: String(row[0]), amount: Number(row[1]) || 0 }));

    res.status(200).json({ income, spending, categories, sheet });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}
