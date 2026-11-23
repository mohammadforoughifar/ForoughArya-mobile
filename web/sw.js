/* ==========================================================================
 *  Forough Arya — Unified iOS Safari PWA Service Worker (sw.js v1.70.0)
 *  1) کش هوشمند آفلاین هستهٔ اپ، فونت وزیرمتن، آیکن‌ها و موتور گرافیکی محلی CanvasKit
 *  2) اولویت شبکه (Network-First) برای index.html و pwa-config.js جهت اعمال آنی تغییرات سرور
 *  3) عبور مستقیم درخواست‌های API و WebSocket (/api/* , /hubs/*) بدون کش اشتباه
 *  4) پشتیبانی ۱۰۰٪ بومی از Web Push اپل (iOS 16.4+ APNs / web.push.apple.com) و VAPID سرور
 * ========================================================================== */

const SW_VERSION = 'forough-pwa-v1.70.0';
const STATIC_CACHE = SW_VERSION + '-static';
const FOROUGH_PUSH_OWNER_CACHE = 'forough-push-owner-v1';
const FOROUGH_PUSH_OWNER_URL = '/__forough_push_owner__';

const CORE_ASSETS = [
  './',
  'index.html',
  'manifest.json',
  'pwa-config.js',
  'ios-pwa-helper.js',
  'flutter_bootstrap.js',
  'main.dart.js',
  'favicon.png',
  'icons/apple-touch-icon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'assets/FontManifest.json',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/assets/fonts/Vazirmatn.ttf'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil((async () => {
    try {
      const cache = await caches.open(STATIC_CACHE);
      const scopeRoot = self.registration ? self.registration.scope : self.location.href;
      await Promise.allSettled(
        CORE_ASSETS.map((rel) => {
          const url = new URL(rel, scopeRoot).href;
          return cache.add(new Request(url, { cache: 'reload' }));
        })
      );
    } catch (_) {}
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((k) => k.startsWith('forough-pwa-') && k !== STATIC_CACHE)
          .map((k) => caches.delete(k))
      );
    } catch (_) {}
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  let url;
  try {
    url = new URL(req.url);
  } catch (_) {
    return;
  }

  // فقط درخواست‌های هم‌مبدأ و غیر از API/SignalR کش شوند
  if (url.origin !== self.location.origin) return;
  if (
    url.pathname.includes('/api/') ||
    url.pathname.includes('/hubs/') ||
    url.pathname.includes('/swagger')
  ) {
    return;
  }

  const isRealtimeConfigOrShell =
    req.mode === 'navigate' ||
    url.pathname.endsWith('/') ||
    url.pathname.endsWith('/index.html') ||
    url.pathname.endsWith('/pwa-config.js') ||
    url.pathname.endsWith('/version.json');

  if (isRealtimeConfigOrShell) {
    // Network-First با پشتیبانی آفلاین کامل در صورت قطع اینترنت آیفون
    event.respondWith((async () => {
      const cache = await caches.open(STATIC_CACHE);
      try {
        const fresh = await fetch(req);
        if (fresh && fresh.ok) {
          cache.put(req, fresh.clone()).catch(() => {});
        }
        return fresh;
      } catch (_) {
        const cached = await cache.match(req);
        if (cached) return cached;
        if (req.mode === 'navigate') {
          const scopeRoot = self.registration ? self.registration.scope : self.location.href;
          const fallback = await cache.match(new URL('index.html', scopeRoot).href);
          if (fallback) return fallback;
        }
        throw new Error('Offline');
      }
    })());
    return;
  }

  // Cache-First برای فایل‌های سنگین استاتیک (main.dart.js, canvaskit.wasm, Vazirmatn.ttf, icons)
  event.respondWith((async () => {
    const cache = await caches.open(STATIC_CACHE);
    const cached = await cache.match(req);
    if (cached) return cached;
    const resp = await fetch(req);
    if (resp && resp.ok) {
      cache.put(req, resp.clone()).catch(() => {});
    }
    return resp;
  })());
});

/* ---------------- Web Push (iOS 16.4+ APNs / VAPID) ---------------- */

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
