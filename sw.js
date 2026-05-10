// sw.js — Riffy Dashboard Service Worker
// Handles Web Push notifications and notification clicks.

const CACHE_VERSION = 'riffy-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(clients.claim()));

// ── Push notification received from server ──
self.addEventListener('push', event => {
  let data = {};
  try { data = event.data?.json() ?? {}; } catch (_) {}

  const title   = data.title  || 'Riffy Dashboard';
  const options = {
    body:              data.body  || '',
    icon:              data.icon  || '/icon-192.png',
    badge:             '/badge-72.png',
    vibrate:           [200, 100, 200],
    requireInteraction: data.requireInteraction ?? false,
    data:              { url: data.url || '/' },
    actions:           data.actions || [],
    tag:               data.tag || 'riffy-push',
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// ── Notification clicked — focus or open the app ──
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const url = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(cs => {
      const match = cs.find(c => new URL(c.url).origin === self.location.origin);
      if (match) { match.focus(); match.postMessage({ type: 'notif-open', url }); return; }
      return clients.openWindow(url);
    })
  );
});

// ── Messages from the main thread (for local in-page notifications) ──
self.addEventListener('message', event => {
  if (event.data?.type === 'SHOW_NOTIFICATION') {
    const { title, body, url, tag } = event.data;
    self.registration.showNotification(title || 'Riffy', {
      body:    body || '',
      icon:    '/icon-192.png',
      vibrate: [200, 100, 200],
      data:    { url: url || '/' },
      tag:     tag || 'riffy-local',
    });
  }
});
