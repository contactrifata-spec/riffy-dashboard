// api/push-subscribe.js — Web Push subscription management + cron-driven push sender
//
// POST  { ...subscriptionObject }   → save push subscription to Redis
// DELETE { endpoint }               → remove push subscription from Redis
// GET   (called by Vercel cron)     → send push notifications for schedule events due in ~10 min

import webpush from 'web-push';

function isDashboardOrigin(req) {
  const origin = req.headers['origin'] || req.headers['referer'] || '';
  if (!origin) return true; // PWA/iOS standalone sends no origin
  return origin.startsWith('https://riffy-dashboard.vercel.app') || origin.startsWith('http://localhost');
}

function isCron(req) {
  const cronSecret = process.env.CRON_SECRET;
  if (!cronSecret) return false;
  return req.headers['authorization'] === `Bearer ${cronSecret}`;
}

export default async function handler(req, res) {
  const origin = req.headers['origin'] || 'https://riffy-dashboard.vercel.app';
  res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-dashboard-secret');
  res.setHeader('Vary', 'Origin');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  const REDIS_URL   = process.env.UPSTASH_REDIS_REST_URL;
  const REDIS_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!REDIS_URL || !REDIS_TOKEN) { res.status(503).json({ error: 'Redis not configured' }); return; }

  const upstash = cmd => fetch(REDIS_URL, {
    method: 'POST',
    headers: { Authorization: `Bearer ${REDIS_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(cmd),
  }).then(r => r.json());

  // ── GET: cron-triggered push sender ────────────────────────────────────────
  if (req.method === 'GET') {
    if (!isCron(req) && !isDashboardOrigin(req)) {
      res.status(401).json({ error: 'Unauthorized' }); return;
    }

    const VAPID_PUBLIC  = process.env.VAPID_PUBLIC_KEY;
    const VAPID_PRIVATE = process.env.VAPID_PRIVATE_KEY;
    if (!VAPID_PUBLIC || !VAPID_PRIVATE) {
      res.status(503).json({ error: 'VAPID keys not configured' }); return;
    }

    webpush.setVapidDetails('mailto:rifat@riffycreates.com', VAPID_PUBLIC, VAPID_PRIVATE);

    // 1. Get today's schedule from Redis (stored by state-sync as {value, updatedAt})
    const TZ = 'America/Toronto';
    const todayStr = new Date().toLocaleDateString('en-CA', { timeZone: TZ });
    const dayKey = `riffy-day-${todayStr}`;
    const { result: dayRaw } = await upstash(['GET', dayKey]);
    if (!dayRaw) { res.json({ ok: true, sent: 0, reason: 'no schedule' }); return; }

    let schedule = [];
    try {
      const parsed = JSON.parse(dayRaw);
      schedule = parsed?.value?.schedule || parsed?.schedule || [];
    } catch (_) {}

    if (schedule.length === 0) { res.json({ ok: true, sent: 0, reason: 'empty schedule' }); return; }

    // 2. Find events whose 10-min-warning falls within the current cron window
    const now = new Date();
    const nowMs = now.getTime();
    const WARN_MS  = 10 * 60 * 1000; // warn 10 min before event
    const WINDOW_MS = 11 * 60 * 1000; // 11-min window (10-min cron + 1-min grace)

    const toNotify = schedule.filter(s => {
      const m = (s.time || '').match(/(\d+):(\d+)\s*(AM|PM)/i);
      if (!m) return false;
      let h = +m[1], mn = +m[2];
      const ap = m[3].toUpperCase();
      if (ap === 'PM' && h !== 12) h += 12;
      if (ap === 'AM' && h === 12) h = 0;
      const evtMs = new Date(now.getFullYear(), now.getMonth(), now.getDate(), h, mn).getTime();
      const notifyMs = evtMs - WARN_MS;
      return notifyMs >= nowMs - 60_000 && notifyMs < nowMs + WINDOW_MS;
    });

    if (toNotify.length === 0) { res.json({ ok: true, sent: 0 }); return; }

    // 3. Dedup — skip events already notified today
    const sentKey = `riffy-push-sent:${todayStr}`;
    const { result: sentMembers } = await upstash(['SMEMBERS', sentKey]);
    const alreadySent = new Set(sentMembers || []);
    const fresh = toNotify.filter(s => s.id && !alreadySent.has(s.id));
    if (fresh.length === 0) { res.json({ ok: true, sent: 0, reason: 'already sent' }); return; }

    // 4. Get all push subscriptions
    const { result: hashResult } = await upstash(['HGETALL', 'riffy-push-subs']);
    if (!hashResult || hashResult.length === 0) {
      res.json({ ok: true, sent: 0, reason: 'no subscribers' }); return;
    }
    // hashResult = [endpoint, subJSON, endpoint, subJSON, ...]
    const subs = [];
    for (let i = 0; i < hashResult.length; i += 2) {
      try { subs.push({ endpoint: hashResult[i], sub: JSON.parse(hashResult[i + 1]) }); } catch (_) {}
    }

    // 5. Send a push for each due event to every subscriber
    let sent = 0;
    for (const evt of fresh) {
      const label = evt.label || 'Event';
      const payload = JSON.stringify({
        title: `⏰ ${label} in 10 min`,
        body:  `Starting at ${evt.time}`,
        tag:   evt.id || 'riffy-sched',
        url:   '/',
      });

      for (const { endpoint, sub } of subs) {
        try {
          await webpush.sendNotification(sub, payload);
          sent++;
        } catch (e) {
          if (e.statusCode === 410 || e.statusCode === 404) {
            await upstash(['HDEL', 'riffy-push-subs', endpoint]);
          }
        }
      }

      // Mark as sent (expire at end of day)
      if (evt.id) {
        await upstash(['SADD', sentKey, evt.id]);
        await upstash(['EXPIRE', sentKey, 86400]);
      }
    }

    res.json({ ok: true, sent });
    return;
  }

  // ── POST: save push subscription ───────────────────────────────────────────
  if (!isDashboardOrigin(req)) { res.status(403).json({ error: 'Forbidden' }); return; }

  if (req.method === 'POST') {
    const sub = req.body;
    if (!sub?.endpoint) { res.status(400).json({ error: 'Invalid subscription object' }); return; }
    await upstash(['HSET', 'riffy-push-subs', sub.endpoint, JSON.stringify(sub)]);
    res.json({ ok: true });

  } else if (req.method === 'DELETE') {
    const { endpoint } = req.body || {};
    if (!endpoint) { res.status(400).json({ error: 'Missing endpoint' }); return; }
    await upstash(['HDEL', 'riffy-push-subs', endpoint]);
    res.json({ ok: true });

  } else {
    res.status(405).json({ error: 'Method not allowed' });
  }
}
