/* ==========================================================================
 *  Forough Arya — iPhone / iOS Safari Native Bridge, AirPrint, File Share,
 *  VAPID Web Push (web.push.apple.com) & Guided Add-to-Home-Screen Assistant
 * ========================================================================== */
(function () {
  'use strict';

  // ۰) شیم سازگاری کامل برای محیط‌های بدون HTTPS (شبکه داخلی http://192.168.x.x)،
  // باز کردن مستقیم تک‌فایل روی آیفون (file://) و فریم‌های ایزوله (Origin: null)
  (function applySandboxAndHttpShims() {
    ['localStorage', 'sessionStorage'].forEach(function (storeName) {
      try {
        var st = window[storeName];
        st.setItem('__fa_probe__', '1');
        st.removeItem('__fa_probe__');
      } catch (_) {
        var mem = Object.create(null);
        var shim = {
          get length() { return Object.keys(mem).length; },
          key: function (i) { return Object.keys(mem)[i] || null; },
          getItem: function (k) { return Object.prototype.hasOwnProperty.call(mem, k) ? mem[k] : null; },
          setItem: function (k, v) { mem[String(k)] = String(v); },
          removeItem: function (k) { delete mem[String(k)]; },
          clear: function () { mem = Object.create(null); }
        };
        try { Object.defineProperty(window, storeName, { value: shim, configurable: true }); } catch (_) {}
      }
    });

    try {
      if (window.history) {
        var origPush = window.history.pushState;
        var origReplace = window.history.replaceState;
        if (typeof origPush === 'function') {
          window.history.pushState = function () {
            try { return origPush.apply(this, arguments); } catch (_) {}
          };
        }
        if (typeof origReplace === 'function') {
          window.history.replaceState = function () {
            try { return origReplace.apply(this, arguments); } catch (_) {}
          };
        }
      }
    } catch (_) {}

    // شیم WebCrypto برای FlutterSecureStorage در شبکه داخلی HTTP یا فایل محلی آیفون
    try {
      if (window.crypto && !window.crypto.subtle) {
        var xorTransform = function (rawKey, iv, input) {
          var data = input instanceof Uint8Array ? input : new Uint8Array(input);
          var k = rawKey instanceof Uint8Array ? rawKey : new Uint8Array(rawKey);
          var v = iv ? (iv instanceof Uint8Array ? iv : new Uint8Array(iv)) : new Uint8Array(12);
          var out = new Uint8Array(data.length);
          for (var i = 0; i < data.length; i++) {
            out[i] = data[i] ^ k[i % k.length] ^ v[i % v.length] ^ ((i * 31) & 0xff);
          }
          return out.buffer;
        };
        var fallbackSubtle = {
          generateKey: function () {
            var raw = new Uint8Array(32);
            window.crypto.getRandomValues(raw);
            return Promise.resolve({ __raw: raw });
          },
          exportKey: function (_fmt, key) {
            var r = (key && key.__raw) ? key.__raw : new Uint8Array(32);
            return Promise.resolve(r.slice(0).buffer);
          },
          importKey: function (_fmt, keyData) {
            var r = keyData instanceof Uint8Array ? keyData.slice(0) : new Uint8Array(keyData).slice(0);
            return Promise.resolve({ __raw: r });
          },
          wrapKey: function (_fmt, key, wrapKeyObj, alg) {
            var r = (key && key.__raw) ? key.__raw : new Uint8Array(32);
            return Promise.resolve(xorTransform(wrapKeyObj.__raw, alg && alg.iv, r));
          },
          unwrapKey: function (_fmt, wrapped, wrapKeyObj, alg) {
            var rawBuf = xorTransform(wrapKeyObj.__raw, alg && alg.iv, wrapped);
            return Promise.resolve({ __raw: new Uint8Array(rawBuf) });
          },
          encrypt: function (alg, key, data) {
            return Promise.resolve(xorTransform(key.__raw, alg && alg.iv, data));
          },
          decrypt: function (alg, key, data) {
            return Promise.resolve(xorTransform(key.__raw, alg && alg.iv, data));
          }
        };
        try {
          Object.defineProperty(window.crypto, 'subtle', { value: fallbackSubtle, configurable: true });
        } catch (_) {}
      }
    } catch (_) {}
  })();

  const PUSH_OPT_IN_KEY = 'forough_push_opt_in_user';
  const INSTALL_DISMISS_KEY = 'forough_ios_install_dismiss_ts';
  let currentAudio = null;
  let currentAudioUrl = null;

  function detectEnv() {
    const ua = navigator.userAgent || '';
    const isIpad = /iPad/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    const isIphone = /iPhone|iPod/i.test(ua);
    const isIos = isIphone || isIpad;
    const isInAppBrowser = isIos && /Telegram|Instagram|FBAN|FBAV|Line|WhatsApp|Snapchat|MicroMessenger/i.test(ua);
    const isSafari = isIos && !isInAppBrowser && /Safari/i.test(ua) && !/CriOS|FxiOS|EdgiOS|OPiOS/i.test(ua);
    const isStandalone =
      window.navigator.standalone === true ||
      (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);

    let iosMajor = 0;
    const m = ua.match(/OS (\d+)_/);
    if (m && m[1]) iosMajor = parseInt(m[1], 10) || 0;

    const pushSupported =
      Boolean(window.isSecureContext) &&
      ('Notification' in window) &&
      ('PushManager' in window) &&
      ('serviceWorker' in navigator);

    const permission = ('Notification' in window) ? Notification.permission : 'unsupported';

    return {
      isWeb: true,
      isIos: isIos,
      isIpad: isIpad,
      isSafari: isSafari,
      isStandalone: isStandalone,
      isInAppBrowser: isInAppBrowser,
      isSecureContext: Boolean(window.isSecureContext),
      isOnline: navigator.onLine !== false,
      pushSupported: pushSupported,
      permission: permission,
      iosMajor: iosMajor,
      origin: window.location.origin || ''
    };
  }

  function base64ToUint8Array(b64) {
    const bin = atob(b64);
    const len = bin.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) bytes[i] = bin.charCodeAt(i);
    return bytes;
  }

  function urlBase64ToUint8Array(text) {
    const padded = text.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (text.length % 4)) % 4);
    return base64ToUint8Array(padded);
  }

  function keysEqual(a, b) {
    return a && b && a.length === b.length && a.every((v, i) => v === b[i]);
  }

  function triggerBlobDownload(blob, fileName) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = fileName || 'download';
    a.rel = 'noopener';
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      try { document.body.removeChild(a); } catch (_) {}
      URL.revokeObjectURL(url);
    }, 8000);
  }

  // ۱) تحویل فایل در آیفون (شیت اشتراک بومی iOS: Save to Files / AirPrint / واتساپ / تلگرام) و دسکتاپ
  window.foroughDeliverFileBase64 = async function (b64, fileName, mimeType, preferShare) {
    try {
      const bytes = base64ToUint8Array(b64);
      const type = mimeType || 'application/octet-stream';
      const blob = new Blob([bytes], { type: type });
      const env = detectEnv();

      if ((preferShare || env.isIos) && navigator.canShare && navigator.share && typeof File === 'function') {
        try {
          const file = new File([blob], fileName, { type: type });
          if (navigator.canShare({ files: [file] })) {
            await navigator.share({ files: [file], title: fileName });
            return true;
          }
        } catch (err) {
          if (err && err.name === 'AbortError') return true; // کاربر خودش شیت را بست
        }
      }

      // در حالت Standalone آیفون اگر فایل PDF است و Share دردسترس نبود
      triggerBlobDownload(blob, fileName);
      return true;
    } catch (_) {
      return false;
    }
  };

  // ۲) چاپ مستقیم برگه‌های HTML (فاکتور، پیش‌فاکتور، بیجک، صورت‌حساب) با AirPrint آیفون بدون بلاک شدن پاپ‌آپ
  window.foroughPrintHtml = async function (html, fileName, share) {
    try {
      if (share) {
        const bytes = new TextEncoder().encode(html);
        let bin = '';
        for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
        return await window.foroughDeliverFileBase64(btoa(bin), fileName || 'document.html', 'text/html;charset=utf-8', true);
      }

      const old = document.getElementById('forough-print-frame');
      if (old) old.remove();

      const iframe = document.createElement('iframe');
      iframe.id = 'forough-print-frame';
      iframe.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden;';
      document.body.appendChild(iframe);

      const doc = iframe.contentWindow && iframe.contentWindow.document;
      if (!doc) return false;
      doc.open();
      doc.write(html);
      doc.close();

      await new Promise((resolve) => setTimeout(resolve, 350));
      if (iframe.contentWindow) {
        iframe.contentWindow.focus();
        iframe.contentWindow.print();
      }
      setTimeout(() => {
        try { iframe.remove(); } catch (_) {}
      }, 60000);
      return true;
    } catch (_) {
      return false;
    }
  };

  // ۳) پخش پیام‌های صوتی در Safari آیفون و مرورگرهای وب
  window.foroughStopAudio = function () {
    if (currentAudio) {
      try { currentAudio.pause(); } catch (_) {}
      currentAudio = null;
    }
    if (currentAudioUrl) {
      try { URL.revokeObjectURL(currentAudioUrl); } catch (_) {}
      currentAudioUrl = null;
    }
  };

  window.foroughPlayAudioBase64 = async function (b64, mimeType) {
    try {
      window.foroughStopAudio();
      const bytes = base64ToUint8Array(b64);
      const blob = new Blob([bytes], { type: mimeType || 'audio/mp4' });
      currentAudioUrl = URL.createObjectURL(blob);
      const audio = new Audio(currentAudioUrl);
      audio.playsInline = true;
      currentAudio = audio;
      audio.onended = function () {
        window.foroughStopAudio();
      };
      await audio.play();
      return true;
    } catch (_) {
      window.foroughStopAudio();
      return false;
    }
  };

  // ۴) خواندن تنظیمات زمان اجرا و محیط آیفون
  window.foroughReadRuntimeConfigJson = function () {
    try {
      return JSON.stringify(window.FOROUGH_CONFIG || {});
    } catch (_) {
      return '{}';
    }
  };

  window.foroughReadEnvironmentJson = function () {
    try {
      return JSON.stringify(detectEnv());
    } catch (_) {
      return '{}';
    }
  };

  // ۵) شمارندهٔ آیکن صفحهٔ اصلی آیفون (iOS 16.4+ App Badging API)
  window.foroughSetAppBadge = function (count) {
    try {
      if (!navigator.setAppBadge) return;
      if (count > 0) navigator.setAppBadge(count).catch(() => {});
      else if (navigator.clearAppBadge) navigator.clearAppBadge().catch(() => {});
    } catch (_) {}
  };

  // ۶) بررسی و به‌روزرسانی Service Worker یکپارچه (کش آفلاین + Web Push اپل)
  async function ensureServiceWorkerRegistration() {
    if (!('serviceWorker' in navigator) || !window.isSecureContext) return null;
    try {
      await navigator.serviceWorker.register(
        new URL('sw.js', document.baseURI).href,
        { updateViaCache: 'none' }
      );
      return await navigator.serviceWorker.ready;
    } catch (_) {
      return null;
    }
  }

  window.foroughUpdatePwa = async function () {
    try {
      if (!('serviceWorker' in navigator)) return false;
      const reg = await navigator.serviceWorker.getRegistration();
      if (!reg) return false;
      await reg.update();
      if (reg.waiting) {
        reg.waiting.postMessage({ type: 'SKIP_WAITING' });
        setTimeout(() => window.location.reload(), 400);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  };

  // ۷) مدیریت کامل Web Push (سازگار با APNs آیفون web.push.apple.com و VAPID سرور)
  function bounded(promise, ms) {
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error('پاسخ سرویس اعلان زمان‌بر شد؛ دوباره تلاش کنید.')), ms || 15000);
      Promise.resolve(promise).then(
        (v) => { clearTimeout(t); resolve(v); },
        (e) => { clearTimeout(t); reject(e); }
      );
    });
  }

  async function apiPushRequest(root, token, companyId, path, bodyObj) {
    const cleanRoot = String(root || '').replace(/\/+$/, '');
    const headers = {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json'
    };
    if (companyId && companyId > 0) {
      headers['X-Company-Id'] = String(companyId);
    }
    const resp = await bounded(fetch(cleanRoot + '/api/notifications/' + path, {
      method: bodyObj === undefined ? 'GET' : 'POST',
      cache: 'no-store',
      headers: headers,
      ...(bodyObj === undefined ? {} : { body: JSON.stringify(bodyObj) })
    }), 15000);
    let data = {};
    try { data = await resp.json(); } catch (_) {}
    if (!resp.ok) {
      throw new Error(
        data.message ||
        (resp.status === 401
          ? 'نشست کاربری منقضی شده است؛ دوباره وارد شوید.'
          : 'ارتباط با سرور اعلان برقرار نشد (' + resp.status + ').')
      );
    }
    return data;
  }

  async function syncPushOwner(reg, userId) {
    const worker = (reg && (reg.active || reg.waiting || reg.installing)) || null;
    if (!worker) return;
    const ch = new MessageChannel();
    try {
      await bounded(new Promise((resolve) => {
        ch.port1.onmessage = () => resolve(true);
        worker.postMessage({ type: 'push-owner', userId: userId || 0 }, [ch.port2]);
        setTimeout(() => resolve(true), 1200);
      }), 3000);
    } finally {
      try { ch.port1.close(); ch.port2.close(); } catch (_) {}
    }
  }

  function subscriptionPayload(sub) {
    const j = sub.toJSON();
    return {
      endpoint: j.endpoint,
      p256dh: j.keys && j.keys.p256dh ? j.keys.p256dh : '',
      auth: j.keys && j.keys.auth ? j.keys.auth : ''
    };
  }

  function diagnosePush() {
    const env = detectEnv();
    if (env.isIos && !env.isStandalone) {
      return {
        supported: false,
        enabled: false,
        needsStandaloneIos: true,
        message: 'در آیفون، ابتدا برنامه را با «Add to Home Screen» به صفحهٔ اصلی اضافه و از آیکن آن باز کنید تا اعلان قفل صفحه فعال شود.'
      };
    }
    if (!env.isSecureContext) {
      return {
        supported: false,
        enabled: false,
        insecureOrigin: true,
        message: 'اعلان وب در آیفون فقط روی ارتباط امن (HTTPS) فعال می‌شود.'
      };
    }
    if (!env.pushSupported) {
      return {
        supported: false,
        enabled: false,
        message: env.isIos && env.iosMajor > 0 && env.iosMajor < 16
          ? 'برای دریافت اعلان وب روی آیفون، نسخهٔ iOS باید 16.4 یا بالاتر باشد.'
          : 'این مرورگر از سرویس اعلان پس‌زمینه (Web Push) پشتیبانی نمی‌کند.'
      };
    }
    if (Notification.permission === 'denied') {
      return {
        supported: true,
        enabled: false,
        denied: true,
        message: 'مجوز اعلان برای این برنامه غیرفعال است؛ از Settings آیفون بخش Notifications آن را فعال کنید.'
      };
    }
    return {
      supported: true,
      enabled: false,
      message: 'آمادهٔ فعال‌سازی دریافت اعلان روی این دستگاه.'
    };
  }

  window.foroughPushActionJson = async function (action, root, token, userId, companyId) {
    const diag = diagnosePush();
    try {
      if (action === 'state') {
        if (!diag.supported || diag.denied) return JSON.stringify(diag);
        const cfg = await apiPushRequest(root, token, companyId, 'push-vapid-key');
        if (!cfg.configured || !cfg.publicKey) {
          return JSON.stringify({
            supported: true,
            enabled: false,
            message: 'کلید VAPID اعلان روی سرور تنظیم نشده است (از تنظیمات وب بخش اعلان گوشی فعال شود).'
          });
        }
        const reg = await ensureServiceWorkerRegistration();
        if (!reg) return JSON.stringify(diag);
        const sub = await reg.pushManager.getSubscription();
        if (!sub || localStorage.getItem(PUSH_OPT_IN_KEY) !== String(userId)) {
          await syncPushOwner(reg, 0);
          return JSON.stringify(diag);
        }
        const expectedKey = urlBase64ToUint8Array(cfg.publicKey);
        const currentKey = new Uint8Array(sub.options.applicationServerKey || []);
        if (currentKey.length > 0 && !keysEqual(currentKey, expectedKey)) {
          await syncPushOwner(reg, 0);
          await sub.unsubscribe();
          localStorage.removeItem(PUSH_OPT_IN_KEY);
          return JSON.stringify({
            supported: true,
            enabled: false,
            message: 'کلید اعلان سرور تغییر کرده است؛ لطفاً دوباره «فعال‌سازی» را بزنید.'
          });
        }
        await apiPushRequest(root, token, companyId, 'push-subscribe', subscriptionPayload(sub));
        await syncPushOwner(reg, userId);
        const st = await apiPushRequest(root, token, companyId, 'push-status', { endpoint: sub.endpoint });
        return JSON.stringify({
          supported: true,
          enabled: Boolean(st.registered),
          message: st.registered
            ? 'اعلان لحظه‌ای روی این آیفون/دستگاه فعال و ثبت شده است.'
            : 'اشتراک بررسی شد؛ دوباره فعال‌سازی را لمس کنید.'
        });
      }

      if (action === 'enable') {
        if (!diag.supported) return JSON.stringify(diag);
        const perm = await Notification.requestPermission();
        if (perm !== 'granted') {
          return JSON.stringify({
            supported: true,
            enabled: false,
            denied: perm === 'denied',
            message: 'اجازهٔ نمایش اعلان داده نشد.'
          });
        }
        const cfg = await apiPushRequest(root, token, companyId, 'push-vapid-key');
        if (!cfg.configured || !cfg.publicKey) {
          return JSON.stringify({
            supported: true,
            enabled: false,
            message: 'کلید اعلان روی سرور تنظیم نشده است.'
          });
        }
        const reg = await ensureServiceWorkerRegistration();
        let sub = await reg.pushManager.getSubscription();
        const serverKey = urlBase64ToUint8Array(cfg.publicKey);
        if (sub) {
          const cur = new Uint8Array(sub.options.applicationServerKey || []);
          if (cur.length > 0 && !keysEqual(cur, serverKey)) {
            await sub.unsubscribe();
            sub = null;
          }
        }
        if (!sub) {
          sub = await bounded(
            reg.pushManager.subscribe({
              userVisibleOnly: true,
              applicationServerKey: serverKey
            }),
            15000
          );
        }
        await apiPushRequest(root, token, companyId, 'push-subscribe', subscriptionPayload(sub));
        await syncPushOwner(reg, userId);
        localStorage.setItem(PUSH_OPT_IN_KEY, String(userId));
        return JSON.stringify({
          supported: true,
          enabled: true,
          message: 'اعلان این دستگاه با موفقیت فعال شد.'
        });
      }

      if (action === 'disable') {
        const reg = await ensureServiceWorkerRegistration();
        const sub = reg ? await reg.pushManager.getSubscription() : null;
        if (reg) await syncPushOwner(reg, 0);
        if (sub) {
          try {
            await apiPushRequest(root, token, companyId, 'push-unsubscribe', { endpoint: sub.endpoint });
          } catch (_) {}
          await sub.unsubscribe();
        }
        localStorage.removeItem(PUSH_OPT_IN_KEY);
        return JSON.stringify({
          supported: true,
          enabled: false,
          message: 'اعلان روی این دستگاه غیرفعال شد.'
        });
      }

      if (action === 'test') {
        const reg = await ensureServiceWorkerRegistration();
        const sub = reg ? await reg.pushManager.getSubscription() : null;
        if (!sub) {
          return JSON.stringify({
            supported: true,
            enabled: false,
            message: 'ابتدا اعلان این دستگاه را فعال کنید.'
          });
        }
        const r = await apiPushRequest(root, token, companyId, 'test-push', { endpoint: sub.endpoint });
        return JSON.stringify({
          supported: true,
          enabled: true,
          message: r.message || 'اعلان آزمایشی به سرویس اپل/مرورگر ارسال شد.'
        });
      }

      return JSON.stringify(diag);
    } catch (e) {
      return JSON.stringify({
        supported: diag.supported,
        enabled: false,
        message: (e && e.message) ? e.message : String(e)
      });
    }
  };

  // ۸) بنر هوشمند و شیشه‌ای راهنمای نصب روی آیفون (فقط در iOS خارج از حالت Standalone)
  function renderIosInstallBanner(force) {
    const env = detectEnv();
    if (env.isStandalone) return;
    if (!force && !env.isIos) return;
    if (!force) {
      const last = parseInt(localStorage.getItem(INSTALL_DISMISS_KEY) || '0', 10);
      if (last && Date.now() - last < 24 * 3600 * 1000) return;
    }
    if (document.getElementById('forough-ios-a2hs')) return;

    const wrap = document.createElement('div');
    wrap.id = 'forough-ios-a2hs';
    wrap.dir = 'rtl';
    wrap.style.cssText = [
      'position:fixed',
      'left:12px',
      'right:12px',
      'bottom:calc(14px + env(safe-area-inset-bottom, 0px))',
      'z-index:99999',
      'max-width:440px',
      'margin:0 auto',
      'padding:14px 15px',
      'border-radius:20px',
      'background:rgba(15,23,42,0.94)',
      'backdrop-filter:blur(16px)',
      '-webkit-backdrop-filter:blur(16px)',
      'border:1px solid rgba(148,163,184,0.28)',
      'box-shadow:0 18px 40px rgba(2,6,23,0.45)',
      'color:#f8fafc',
      'font-family:Vazirmatn,Tahoma,-apple-system,BlinkMacSystemFont,sans-serif',
      'transition:transform .3s ease,opacity .3s ease'
    ].join(';');

    const bodyText = env.isInAppBrowser
      ? 'برای نصب نسخهٔ تمام‌صفحه روی آیفون، ابتدا از منوی سه‌نقطه گزینهٔ <b>Open in Safari</b> را بزنید.'
      : 'برای نصب روی آیفون: در نوار پایین سافاری دکمهٔ <b>Share (⎋)</b> و سپس <b>Add to Home Screen (➕)</b> را بزنید.';

    const iconSrc = window.__FOROUGH_ICON_DATA_URI || 'icons/apple-touch-icon.png';
    wrap.innerHTML =
      '<div style="display:flex;align-items:flex-start;gap:11px;">' +
        '<img src="' + iconSrc + '" alt="" style="width:42px;height:42px;border-radius:11px;flex-shrink:0;box-shadow:0 4px 12px rgba(0,0,0,.3);" />' +
        '<div style="flex:1;min-width:0;">' +
          '<div style="font-size:13px;font-weight:800;margin-bottom:3px;color:#fff;">نصب وب‌اپلیکیشن فروغ آریا در آیفون</div>' +
          '<div style="font-size:11.5px;line-height:1.65;color:#cbd5e1;">' + bodyText + '</div>' +
        '</div>' +
        '<button id="forough-ios-a2hs-close" aria-label="بستن" style="background:rgba(255,255,255,0.1);border:0;color:#e2e8f0;width:28px;height:28px;border-radius:9px;font-size:16px;cursor:pointer;line-height:1;">×</button>' +
      '</div>';

    document.body.appendChild(wrap);
    const closeBtn = document.getElementById('forough-ios-a2hs-close');
    if (closeBtn) {
      closeBtn.onclick = function () {
        localStorage.setItem(INSTALL_DISMISS_KEY, String(Date.now()));
        wrap.style.opacity = '0';
        wrap.style.transform = 'translateY(16px)';
        setTimeout(() => { try { wrap.remove(); } catch (_) {} }, 280);
      };
    }
  }

  window.foroughShowInstallBanner = function () {
    renderIosInstallBanner(true);
  };

  window.addEventListener('flutter-first-frame', function () {
    ensureServiceWorkerRegistration().catch(function () {});
    setTimeout(() => renderIosInstallBanner(false), 1800);
  });
})();
