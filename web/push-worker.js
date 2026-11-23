/* ==========================================================================
 *  Forough Arya — iOS 16.4+ / Safari / Android / Desktop Web Push Worker
 *  100% سازگار با NotificationsController.cs و PushService.cs بک‌اند
 * ========================================================================== */

const FOROUGH_PUSH_OWNER_CACHE = 'forough-push-owner-v1';
const FOROUGH_PUSH_OWNER_URL = '/__forough_push_owner__';

async function foroughGetOwner() {
  try {
    const cache = await caches.open(FOROUGH_PUSH_OWNER_CACHE);
    const res = await cache.match(FOROUGH_PUSH_OWNER_URL);
    return res ? (parseInt(await res.text(), 10) || 0) : 0;
  } catch (_) {
    return 0;
  }
}

async function foroughSetOwner(userId) {
  const cache = await caches.open(FOROUGH_PUSH_OWNER_CACHE);
  if (userId > 0) {
    await cache.put(FOROUGH_PUSH_OWNER_URL, new Response(String(userId)));
  } else {
    await cache.delete(FOROUGH_PUSH_OWNER_URL);
  }
}

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'push-owner') {
    const reply = (ok) => {
      try {
        if (event.ports && event.ports[0]) {
          event.ports[0].postMessage({ ok });
        }
      } catch (_) {}
    };
    event.waitUntil(
      foroughSetOwner(event.data.userId || 0).then(
        () => reply(true),
        () => reply(false)
      )
    );
  } else if (event.data && event.data.type === 'SKIP_WAITING') {
    if (typeof self.skipWaiting === 'function') {
      self.skipWaiting();
    }
  }
});

self.addEventListener('push', (event) => {
  event.waitUntil((async () => {
    let data = {};
    try {
      data = event.data ? event.data.json() : {};
    } catch (_) {
      try {
        data = { title: 'فروغ آریا', body: event.data ? event.data.text() : '' };
      } catch (_) {}
    }

    const owner = await foroughGetOwner();
    if (data.userId && owner && data.userId !== owner) return;
    if (data.expiresAtUtc && Date.parse(data.expiresAtUtc) <= Date.now()) return;

    if (self.navigator && typeof self.navigator.setAppBadge === 'function') {
      try {
        const badgeCount = typeof data.badgeCount === 'number' ? data.badgeCount : 1;
        await self.navigator.setAppBadge(badgeCount);
      } catch (_) {}
    }

    const scopeRoot = self.registration ? self.registration.scope : self.location.origin + '/';
    const iconUrl = new URL('icons/Icon-192.png', scopeRoot).href;

    await self.registration.showNotification(data.title || 'فروغ آریا', {
      body: data.body || 'اعلان جدید در سامانهٔ فروغ آریا دارید.',
      tag: data.tag || 'forough-notification',
      icon: iconUrl,
      badge: iconUrl,
      dir: 'rtl',
      lang: 'fa',
      data: { link: data.link || './' }
    });
  })());
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const rawLink = (event.notification.data && event.notification.data.link) || './';
  const scopeRoot = self.registration ? self.registration.scope : self.location.origin + '/';
  let targetUrl = scopeRoot;
  try {
    targetUrl = new URL(rawLink, scopeRoot).href;
  } catch (_) {}

  event.waitUntil((async () => {
    const windowClients = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    });
    for (const client of windowClients) {
      if (client.url.startsWith(scopeRoot) && 'focus' in client) {
        await client.focus();
        return;
      }
    }
    if (self.clients.openWindow) {
      await self.clients.openWindow(targetUrl);
    }
  })());
});
