// api/nightly-review.js — called by Vercel Cron at midnight ET (04:00 UTC)
// Sends a Web Push notification to all subscribed devices.
// Secured by CRON_SECRET env var (Vercel injects Authorization header automatically).

import webpush from 'web-push';

function isAuthorized(req) {
  const cronSecret = process.env.CRON_SECRET;
  // Vercel Cron: Authorization: Bearer <CRON_SECRET>
  if (cronSecret) {
    const auth = req.headers['authorization'] || '';
    return auth === `Bearer ${cronSecret}`;
  }
  // No CRON_SECRET set → allow only from localhost (dev)
  const origin = req.headers['origin'] || req.headers['referer'] || '';
  return origin.startsWith('http://localhost');
}

export default async function handler(req, res) {
  if (!isAuthorized(req)) { res.status(401).json({ error: 'Unauthorized' }); return; }

  const VAPID_PUBLIC  = process.env.VAPID_PUBLIC_KEY;
  const VAPID_PRIVATE = process.env.VAPID_PRIVATE_KEY;
  const REDIS_URL     = process.env.UPSTASH_REDIS_REST_URL;
  const REDIS_TOKEN   = process.env.UPSTASH_REDIS_REST_TOKEN;

  if (!VAPID_PUBLIC || !VAPID_PRIVATE) { res.status(503).json({ error: 'VAPID keys not configured' }); return; }
  if (!REDIS_URL || !REDIS_TOKEN)       { res.status(503).json({ error: 'Redis not configured' });      return; }

  webpush.setVapidDetails('mailto:rifat@riffycreates.com', VAPID_PUBLIC, VAPID_PRIVATE);

  const upstash = cmd => fetch(REDIS_URL, {
    method: 'POST',
    headers: { Authorization: `Bearer ${REDIS_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(cmd),
  }).then(r => r.json());

  // Fetch all push subscriptions (stored as a Redis hash: endpoint → JSON)
  const { result } = await upstash(['HGETALL', 'riffy-push-subs']);
  if (!result || result.length === 0) { res.json({ sent: 0, message: 'No subscribers' }); return; }

  const payload = JSON.stringify({
    title:             '🌙 End of Day Review',
    body:              "Time to reflect on your day, Riffy. How'd it go?",
    url:               '/',
    requireInteraction: true,
    tag:               'nightly-review',
  });

  let sent = 0, failed = 0, expired = 0;
  // result = [endpoint, subJSON, endpoint, subJSON, ...]
  for (let i = 0; i < result.length; i += 2) {
    const endpoint = result[i];
    const subStr   = result[i + 1];
    try {
      const sub = JSON.parse(subStr);
      await webpush.sendNotification(sub, payload);
      sent++;
    } catch (e) {
      if (e.statusCode === 410 || e.statusCode === 404) {
        // Subscription expired — remove from Redis
        await upstash(['HDEL', 'riffy-push-subs', endpoint]);
        expired++;
      } else {
        console.error('Push failed for', endpoint, e.message);
        failed++;
      }
    }
  }

  res.json({ sent, failed, expired });
}
