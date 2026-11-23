#!/usr/bin/env python3
"""
ساخت نسخهٔ «تک‌فایل کاملاً خودکفا» (Single-File Self-Contained iOS PWA)
خروجی: یک فایل واحد HTML شامل کل کد دارت، موتور گرافیکی CanvasKit (WASM)،
فونت فارسی وزیرمتن، آیکن‌های متریال، آیکن اپل و شیم‌های کامل اجرایی در آیفون.
"""
import base64
import gzip
import json
import os

ROOT = '/home/user/ForoughArya-mobile'
WEB_BUILD = os.path.join(ROOT, 'build/web')
OUT_HTML = '/home/user/ForoughArya-SingleFile-v1.70.0.html'


def gz_b64(raw_bytes: bytes) -> str:
    compressed = gzip.compress(raw_bytes, compresslevel=9, mtime=0)
    return base64.b64encode(compressed).decode('ascii')


def read_bytes(rel_path: str) -> bytes:
    with open(os.path.join(WEB_BUILD, rel_path), 'rb') as f:
        return f.read()


def mime_for(path: str) -> str:
    ext = path.rsplit('.', 1)[-1].lower() if '.' in path else ''
    return {
        'json': 'application/json; charset=utf-8',
        'bin': 'application/octet-stream',
        'ttf': 'font/ttf',
        'otf': 'font/otf',
        'frag': 'application/octet-stream',
        'png': 'image/png',
        'js': 'application/javascript; charset=utf-8',
        'wasm': 'application/wasm',
    }.get(ext, 'application/octet-stream')


def main():
    # ۱. آیکن‌های پایه به‌صورت Data URI برای پشتیبانی مستقیم Add to Home Screen در Safari آیفون
    touch_icon_b64 = base64.b64encode(read_bytes('icons/apple-touch-icon.png')).decode('ascii')
    icon192_b64 = base64.b64encode(read_bytes('icons/Icon-192.png')).decode('ascii')
    favicon_b64 = base64.b64encode(read_bytes('favicon.png')).decode('ascii')

    manifest_obj = {
        "name": "سامانه جامع فروغ آریا",
        "short_name": "فروغ آریا",
        "description": "نسخه تک‌فایل وب‌اپلیکیشن فروغ آریا ویژه آیفون و وب",
        "display": "standalone",
        "dir": "rtl",
        "lang": "fa-IR",
        "background_color": "#101d49",
        "theme_color": "#101d49",
        "icons": [
            {
                "src": f"data:image/png;base64,{icon192_b64}",
                "sizes": "192x192",
                "type": "image/png"
            }
        ]
    }
    manifest_b64 = base64.b64encode(
        json.dumps(manifest_obj, ensure_ascii=False).encode('utf-8')
    ).decode('ascii')

    # ۲. فایل‌های سیستم فایل مجازی (VFS) برای فونت‌ها، شیدرها و مانیفست دارایی‌های فلاتر
    vfs_files = [
        'assets/AssetManifest.bin',
        'assets/AssetManifest.bin.json',
        'assets/FontManifest.json',
        'assets/NOTICES',
        'assets/assets/fonts/Vazirmatn.ttf',
        'assets/fonts/MaterialIcons-Regular.otf',
        'assets/fonts/fallback/Roboto-Regular.ttf',
        'assets/shaders/ink_sparkle.frag',
        'assets/shaders/stretch_effect.frag',
        'version.json',
    ]
    vfs_payload = {}
    for rel in vfs_files:
        full = os.path.join(WEB_BUILD, rel)
        if os.path.exists(full):
            raw = read_bytes(rel)
            vfs_payload[rel] = {
                'mime': mime_for(rel),
                'gz': gz_b64(raw),
            }

    # ۳. آماده‌سازی CanvasKit بدون وابستگی به ES Module خارجی یا CDN گوگل
    ck_js = read_bytes('canvaskit/canvaskit.js').decode('utf-8')
    ck_js = ck_js.replace('import.meta.url', '"https://forough.vfs/"')
    ck_js = ck_js.replace('export default CanvasKitInit;', 'window.__ForoughCanvasKitInit = CanvasKitInit;')
    ck_js_gz = gz_b64(ck_js.encode('utf-8'))
    ck_wasm_gz = gz_b64(read_bytes('canvaskit/canvaskit.wasm'))

    # ۴. کد اصلی کامپایل‌شدهٔ دارت (main.dart.js)
    main_js_gz = gz_b64(read_bytes('main.dart.js'))

    # ۵. پل بومی iOS Safari PWA
    ios_helper_js = open(os.path.join(ROOT, 'web/ios-pwa-helper.js'), 'r', encoding='utf-8').read()

    html = f"""<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="X-UA-Compatible" content="IE=Edge">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
  <meta name="description" content="نسخه تک‌فایل خودکفای وب‌اپلیکیشن سازمانی فروغ آریا ویژه آیفون (iOS PWA)">
  <meta name="theme-color" content="#101d49">
  <meta name="format-detection" content="telephone=no">

  <!-- قابلیت اجرای تمام‌صفحه (Standalone) در آیفون و آیپد -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="فروغ آریا">

  <link rel="icon" type="image/png" href="data:image/png;base64,{favicon_b64}">
  <link rel="apple-touch-icon" href="data:image/png;base64,{touch_icon_b64}">
  <link rel="manifest" href="data:application/manifest+json;base64,{manifest_b64}">
  <title>فروغ آریا — نسخه تک‌فایل آیفون</title>

  <script>
    /**
     * تنظیمات سرور (اختیاری):
     * اگر این تک‌فایل را روی سرور خودتان بگذارید، خودکار به همان سرور وصل می‌شود.
     * اگر می‌خواهید مستقیم روی خودِ آیفون بازش کنید، می‌توانید آدرس سرور را در صفحهٔ ورود
     * بخش «مدیریت سرورها و آدرس‌ها» وارد کنید یا همین‌جا داخل apiBaseUrl بنویسید:
     */
    window.FOROUGH_CONFIG = {{
      apiBaseUrl: "",
      autoSameOrigin: true,
      serverProfiles: []
    }};
    window.__FOROUGH_ICON_DATA_URI = "data:image/png;base64,{touch_icon_b64}";
  </script>

  <style>
    html, body {{
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      overscroll-behavior: none;
      background: #101d49;
      -webkit-tap-highlight-color: transparent;
      -webkit-touch-callout: none;
      -webkit-text-size-adjust: 100%;
      user-select: none;
      -webkit-user-select: none;
    }}
    input, textarea, select, [contenteditable="true"] {{
      font-size: 16px !important;
      user-select: text;
      -webkit-user-select: text;
    }}
    #splash {{
      position: fixed;
      inset: 0;
      z-index: 9999;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 16px;
      padding: env(safe-area-inset-top, 16px) 20px env(safe-area-inset-bottom, 16px);
      background: linear-gradient(225deg, #101d49 0%, #2547a8 55%, #5136a7 100%);
      color: #ffffff;
      font-family: Tahoma, -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
      transition: opacity .35s ease;
      text-align: center;
    }}
    #splash img {{
      width: 90px;
      height: 90px;
      border-radius: 22px;
      box-shadow: 0 14px 36px rgba(0, 0, 0, .38);
    }}
    #splash .t {{ font-size: 20px; font-weight: 800; }}
    #splash .sub {{ font-size: 12px; opacity: .84; min-height: 18px; }}
    #splash .bar {{
      width: 160px;
      height: 5px;
      border-radius: 99px;
      background: rgba(255, 255, 255, .2);
      overflow: hidden;
    }}
    #splash .fill {{
      width: 18%;
      height: 100%;
      background: #ffffff;
      border-radius: 99px;
      transition: width .25s ease;
    }}
  </style>

  <script>
{ios_helper_js}
  </script>
</head>
<body>
  <div id="splash">
    <img src="data:image/png;base64,{icon192_b64}" alt="فروغ آریا">
    <div class="t">سامانه جامع فروغ آریا</div>
    <div class="bar"><div id="splash-fill" class="fill"></div></div>
    <div id="splash-sub" class="sub">در حال بازگشایی بستهٔ تک‌فایل…</div>
  </div>

  <!-- مخزن فشردهٔ داخلی (VFS + CanvasKit WASM + Dart Core) -->
  <script id="forough-vfs-json" type="application/json">{json.dumps(vfs_payload, separators=(',', ':'))}</script>
  <script id="forough-ck-js" type="text/plain">{ck_js_gz}</script>
  <script id="forough-ck-wasm" type="text/plain">{ck_wasm_gz}</script>
  <script id="forough-main-js" type="text/plain">{main_js_gz}</script>

  <script>
    (function () {{
      'use strict';

      var statusEl = document.getElementById('splash-sub');
      var fillEl = document.getElementById('splash-fill');
      function setProgress(pct, text) {{
        if (fillEl) fillEl.style.width = pct + '%';
        if (statusEl && text) statusEl.textContent = text;
      }}

      window.addEventListener('flutter-first-frame', function () {{
        var s = document.getElementById('splash');
        if (s) {{
          s.style.opacity = '0';
          setTimeout(function () {{ try {{ s.remove(); }} catch (_) {{}} }}, 380);
        }}
      }});

      function b64ToBytes(b64) {{
        var bin = atob(b64);
        var len = bin.length;
        var out = new Uint8Array(len);
        for (var i = 0; i < len; i++) out[i] = bin.charCodeAt(i);
        return out;
      }}

      async function gunzipB64(b64) {{
        var compressed = b64ToBytes(b64);
        if (typeof DecompressionStream !== 'undefined') {{
          var ds = new DecompressionStream('gzip');
          var stream = new Blob([compressed]).stream().pipeThrough(ds);
          var buf = await new Response(stream).arrayBuffer();
          return new Uint8Array(buf);
        }}
        throw new Error('مرورگر از بازگشایی فشرده پشتیبانی نمی‌کند؛ لطفاً از iOS 16.4+ یا Safari به‌روز استفاده کنید.');
      }}

      async function bootSingleFileApp() {{
        try {{
          setProgress(22, 'در حال بارگذاری فونت فارسی و منابع داخلی…');
          var rawVfs = JSON.parse(document.getElementById('forough-vfs-json').textContent);
          document.getElementById('forough-vfs-json').remove();

          var vfsMap = Object.create(null);
          var keys = Object.keys(rawVfs);
          await Promise.all(keys.map(async function (k) {{
            var entry = rawVfs[k];
            var bytes = await gunzipB64(entry.gz);
            var rec = {{ bytes: bytes, mime: entry.mime }};
            vfsMap[k] = rec;
            if (k.indexOf('assets/') === 0) {{
              vfsMap[k.substring(7)] = rec;
            }}
          }}));

          // رهگیری هوشمند window.fetch فقط برای فایل‌های مجازی داخلی (بدون دخالت در درخواست‌های API سرور)
          var origFetch = window.fetch.bind(window);
          window.fetch = function (input, init) {{
            try {{
              var urlStr = typeof input === 'string'
                ? input
                : (input && typeof input.url === 'string' ? input.url : String(input));
              var clean = urlStr.split('?')[0].split('#')[0];
              var vfsPrefix = 'https://forough.vfs/';
              var lookup = null;
              if (clean.indexOf(vfsPrefix) === 0) {{
                lookup = decodeURIComponent(clean.substring(vfsPrefix.length));
              }} else {{
                var idx = clean.indexOf('assets/');
                if (idx >= 0 && clean.indexOf('/api/') < 0) {{
                  lookup = decodeURIComponent(clean.substring(idx));
                }} else if (clean.endsWith('/FontManifest.json') || clean === 'FontManifest.json') {{
                  lookup = 'assets/FontManifest.json';
                }} else if (clean.endsWith('/AssetManifest.bin') || clean === 'AssetManifest.bin') {{
                  lookup = 'assets/AssetManifest.bin';
                }} else if (clean.endsWith('/AssetManifest.bin.json') || clean === 'AssetManifest.bin.json') {{
                  lookup = 'assets/AssetManifest.bin.json';
                }}
              }}
              if (lookup) {{
                lookup = lookup.replace(/^\\/+/, '');
                var hit = vfsMap[lookup];
                if (hit) {{
                  return Promise.resolve(new Response(hit.bytes.slice(0), {{
                    status: 200,
                    statusText: 'OK',
                    headers: {{
                      'Content-Type': hit.mime,
                      'Content-Length': String(hit.bytes.byteLength)
                    }}
                  }}));
                }}
              }}
            }} catch (_) {{}}
            return origFetch(input, init);
          }};

          setProgress(52, 'در حال راه‌اندازی موتور گرافیکی آیفون…');
          var ckJsEl = document.getElementById('forough-ck-js');
          var ckWasmEl = document.getElementById('forough-ck-wasm');
          var results = await Promise.all([
            gunzipB64(ckJsEl.textContent),
            gunzipB64(ckWasmEl.textContent)
          ]);
          ckJsEl.remove();
          ckWasmEl.remove();

          var ckJsText = new TextDecoder('utf-8').decode(results[0]);
          var wasmBytes = results[1];

          var ckScript = document.createElement('script');
          ckScript.textContent = ckJsText;
          document.head.appendChild(ckScript);

          window.flutterCanvasKit = await window.__ForoughCanvasKitInit({{
            instantiateWasm: function (imports, receiveInstance) {{
              WebAssembly.instantiate(wasmBytes, imports).then(function (output) {{
                receiveInstance(output.instance, output.module);
              }});
              return {{}};
            }}
          }});
          window.flutterCanvasKitLoaded = Promise.resolve(window.flutterCanvasKit);

          setProgress(82, 'در حال اجرای هستهٔ فروغ آریا…');
          var mainEl = document.getElementById('forough-main-js');
          var mainBytes = await gunzipB64(mainEl.textContent);
          mainEl.remove();
          var mainJsText = new TextDecoder('utf-8').decode(mainBytes);

          window._flutter = window._flutter || {{}};
          window._flutter.loader = {{
            didCreateEngineInitializer: async function (engineInitializer) {{
              setProgress(95, 'در حال ترسیم رابط کاربری…');
              var appRunner = await engineInitializer.initializeEngine({{
                assetBase: 'https://forough.vfs/',
                renderer: 'canvaskit'
              }});
              await appRunner.runApp();
            }}
          }};

          var appScript = document.createElement('script');
          appScript.textContent = mainJsText;
          document.body.appendChild(appScript);
        }} catch (err) {{
          console.error('Forough SingleFile boot error:', err);
          setProgress(100, 'خطا در راه‌اندازی: ' + (err && err.message ? err.message : String(err)));
        }}
      }}

      bootSingleFileApp();
    }})();
  </script>
</body>
</html>
"""
    with open(OUT_HTML, 'w', encoding='utf-8') as out:
        out.write(html)
    sz_mb = os.path.getsize(OUT_HTML) / (1024 * 1024)
    print(f'Built Single-File HTML: {OUT_HTML} ({sz_mb:.2f} MB)')


if __name__ == '__main__':
    main()
