#!/usr/bin/env python3
"""
ساخت نسخهٔ «تک‌فایل کاملاً خودکفا» (Single-File Self-Contained iOS Safari PWA — v1.70.1)
رفع قطعی گیر کردن در Safari / WebKit:
  ۱) حذف کامل DecompressionStream مرورگر (که در WebKit/Safari روی فایل‌های حجیم قفل می‌کند)
     و جایگزینی با موتور Pure-JS TypedArray Gunzip (بازگشایی ۱۷ مگابایت در ~۱ ثانیه بدون هیچ Stream خارجی)
  ۲) تشخیص خودکار پیش‌نمایش QuickLook دانلودهای آیفون (زمانی که کاربر فایل دانلودشده را
     مستقیماً داخل لیست Downloads سافاری لمس می‌کند و iOS اجرای اسکریپت را مسدود می‌کند)
  ۳) ساخت استاندارد ReadableStream در پاسخ‌های VFS برای سازگاری ۱۰۰٪ با FontManifest فلاتر در Safari
"""
import base64
import gzip
import json
import os

ROOT = '/home/user/ForoughArya-mobile'
_CANDIDATE_WEB = os.path.join(ROOT, 'build/web')
WEB_BUILD = _CANDIDATE_WEB if os.path.exists(os.path.join(_CANDIDATE_WEB, 'main.dart.js')) else '/home/user/ForoughArya-iOS-PWA'
import os as _os
_SUFFIX = _os.environ.get('SINGLEFILE_VERSION', 'v1.70.3')
OUT_HTML = f'/home/user/ForoughArya-SingleFile-{_SUFFIX}.html'


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
            vfs_payload[rel] = {
                'mime': mime_for(rel),
                'gz': gz_b64(read_bytes(rel)),
            }

    ck_js = read_bytes('canvaskit/canvaskit.js').decode('utf-8')
    ck_js = ck_js.replace('import.meta.url', '"https://forough.vfs/"')
    ck_js = ck_js.replace('export default CanvasKitInit;', 'window.__ForoughCanvasKitInit = CanvasKitInit;')
    ck_js_gz = gz_b64(ck_js.encode('utf-8'))
    ck_wasm_gz = gz_b64(read_bytes('canvaskit/canvaskit.wasm'))
    main_js_gz = gz_b64(read_bytes('main.dart.js'))

    ios_helper_js = open(os.path.join(ROOT, 'web/ios-pwa-helper.js'), 'r', encoding='utf-8').read()

    html = f"""<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="X-UA-Compatible" content="IE=Edge">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
  <meta name="description" content="نسخه تک‌فایل خودکفای وب‌اپلیکیشن سازمانی فروغ آریا ویژه آیفون (iOS Safari PWA)">
  <meta name="theme-color" content="#101d49">
  <meta name="format-detection" content="telephone=no">

  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="فروغ آریا">

  <link rel="icon" type="image/png" href="data:image/png;base64,{favicon_b64}">
  <link rel="apple-touch-icon" href="data:image/png;base64,{touch_icon_b64}">
  <link rel="manifest" href="data:application/manifest+json;base64,{manifest_b64}">
  <title>فروغ آریا — نسخه تک‌فایل آیفون</title>

  <script>
    // به‌محض فعال بودن موتور جاوااسکریپت سافاری، هشدار پیش‌نمایش آفلاین QuickLook مخفی می‌شود
    document.documentElement.className += ' js-ok';
    window.__FOROUGH_SINGLE_FILE = true;
    window.__FOROUGH_ICON_DATA_URI = "data:image/png;base64,{touch_icon_b64}";
    window.FOROUGH_CONFIG = {{
      apiBaseUrl: "",
      autoSameOrigin: true,
      serverProfiles: []
    }};
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
      gap: 15px;
      padding: env(safe-area-inset-top, 16px) 20px env(safe-area-inset-bottom, 16px);
      background: linear-gradient(225deg, #101d49 0%, #2547a8 55%, #5136a7 100%);
      color: #ffffff;
      font-family: Tahoma, -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
      transition: opacity .35s ease;
      text-align: center;
    }}
    #splash img {{
      width: 88px;
      height: 88px;
      border-radius: 22px;
      box-shadow: 0 14px 36px rgba(0, 0, 0, .38);
    }}
    #splash .t {{ font-size: 20px; font-weight: 800; }}
    #splash .sub {{ font-size: 12.5px; opacity: .9; min-height: 20px; max-width: 340px; line-height: 1.7; }}
    #splash .bar {{
      width: 170px;
      height: 5px;
      border-radius: 99px;
      background: rgba(255, 255, 255, .2);
      overflow: hidden;
    }}
    #splash .fill {{
      width: 14%;
      height: 100%;
      background: #ffffff;
      border-radius: 99px;
      transition: width .22s ease;
    }}
    /* تشخیص خودکار باز شدن فایل داخل پیش‌نمایش دانلودهای آیفون (QuickLook که جاوااسکریپت را قفل می‌کند) */
    #ql-warning {{
      max-width: 360px;
      margin-top: 10px;
      padding: 14px 16px;
      border-radius: 16px;
      background: rgba(15, 23, 42, 0.92);
      border: 1px solid rgba(251, 191, 36, 0.55);
      color: #fef3c7;
      font-size: 12px;
      line-height: 1.85;
      text-align: right;
      opacity: 0;
      animation: showQlHelp 0.4s ease 1.6s forwards;
    }}
    html.js-ok #ql-warning {{
      display: none !important;
      animation: none !important;
    }}
    @keyframes showQlHelp {{
      from {{ opacity: 0; transform: translateY(8px); }}
      to {{ opacity: 1; transform: translateY(0); }}
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
    <div id="splash-sub" class="sub">در حال آماده‌سازی برنامه…</div>

    <div id="ql-warning">
      <b style="color:#fbbf24;font-size:13px;">⚠️ فایل را از لیست دانلودهای آیفون باز کرده‌اید!</b><br>
      پیش‌نمایش فایل‌های دانلودی در آیفون (QuickLook) اجازهٔ اجرای برنامه‌ها را نمی‌دهد.<br>
      <b>راه‌حل قطعی:</b> این فایل را روی گوشی دانلود نکنید؛ فقط همین <b>۱ فایل</b> را با نام مثلاً <code>ios.html</code> کنار سایت سرور خود (پوشهٔ <code>wwwroot</code>) کپی کنید و آدرس <code>https://سایت-شما/ios.html</code> را در نوار آدرس بالای <b>Safari</b> وارد نمایید (یا روی گوشی با اپ رایگان <b>Documents</b> بازش کنید).
    </div>
  </div>

  <!-- مخزن فشردهٔ داخلی -->
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
      function nextFrame() {{
        return new Promise(function (resolve) {{ setTimeout(resolve, 20); }});
      }}

      var bootedFrame = false;
      window.addEventListener('flutter-first-frame', function () {{
        bootedFrame = true;
        var s = document.getElementById('splash');
        if (s) {{
          s.style.opacity = '0';
          setTimeout(function () {{ try {{ s.remove(); }} catch (_) {{}} }}, 380);
        }}
      }});
      window.addEventListener('error', function (ev) {{
        if (!bootedFrame && ev && ev.message) {{
          setProgress(100, 'خطای اجرا: ' + ev.message);
        }}
      }});
      window.addEventListener('unhandledrejection', function (ev) {{
        if (!bootedFrame && ev && ev.reason) {{
          var msg = ev.reason.message || String(ev.reason);
          setProgress(100, 'خطای وعده: ' + msg);
        }}
      }});

      function b64ToBytes(b64) {{
        var clean = b64.replace(/\\s+/g, '');
        var bin = atob(clean);
        var len = bin.length;
        var out = new Uint8Array(len);
        for (var i = 0; i < len; i++) out[i] = bin.charCodeAt(i);
        return out;
      }}

      // موتور بازگشایی GZIP صددرصد Pure-JS بدون وابستگی به DecompressionStream سافاری
      var FIXED_LIT = new Uint8Array(288);
      (function () {{
        var i;
        for (i = 0; i <= 143; i++) FIXED_LIT[i] = 8;
        for (i = 144; i <= 255; i++) FIXED_LIT[i] = 9;
        for (i = 256; i <= 279; i++) FIXED_LIT[i] = 7;
        for (i = 280; i <= 287; i++) FIXED_LIT[i] = 8;
      }})();
      var FIXED_DIST = new Uint8Array(32);
      FIXED_DIST.fill(5);
      var LEN_BASE = [3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258];
      var LEN_EXTRA = [0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0];
      var DIST_BASE = [1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577];
      var DIST_EXTRA = [0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13];
      var CL_ORDER = [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15];

      function buildTree(lengths) {{
        var maxBits = 0, i, l;
        var blCount = new Int32Array(16);
        for (i = 0; i < lengths.length; i++) {{
          l = lengths[i];
          if (l > 0) {{ blCount[l]++; if (l > maxBits) maxBits = l; }}
        }}
        if (maxBits === 0) return {{ table: new Int32Array(2), maxBits: 1, mask: 1 }};
        var nextCode = new Int32Array(16);
        var code = 0;
        for (var b = 1; b <= 15; b++) {{
          code = (code + blCount[b - 1]) << 1;
          nextCode[b] = code;
        }}
        var size = 1 << maxBits;
        var table = new Int32Array(size);
        for (var sym = 0; sym < lengths.length; sym++) {{
          var len = lengths[sym];
          if (len === 0) continue;
          var c = nextCode[len]++;
          var rev = 0;
          for (i = 0; i < len; i++) rev = (rev << 1) | ((c >>> i) & 1);
          var entry = (sym << 4) | len;
          var step = 1 << len;
          for (var idx = rev; idx < size; idx += step) table[idx] = entry;
        }}
        return {{ table: table, maxBits: maxBits, mask: size - 1 }};
      }}

      var FIXED_LIT_TREE = buildTree(FIXED_LIT);
      var FIXED_DIST_TREE = buildTree(FIXED_DIST);

      function gunzipSync(src) {{
        if (src[0] !== 0x1f || src[1] !== 0x8b || src[2] !== 8) throw new Error('فرمت فشرده نامعتبر است.');
        var flg = src[3], pos = 10;
        if (flg & 4) {{ var xlen = src[pos] | (src[pos + 1] << 8); pos += 2 + xlen; }}
        if (flg & 8) {{ while (src[pos++] !== 0); }}
        if (flg & 16) {{ while (src[pos++] !== 0); }}
        if (flg & 2) pos += 2;

        var isize = (src[src.length - 4] | (src[src.length - 3] << 8) | (src[src.length - 2] << 16) | (src[src.length - 1] << 24)) >>> 0;
        var out = new Uint8Array(isize > 0 ? isize : src.length * 3);
        var outPos = 0;
        function ensure(n) {{
          if (outPos + n <= out.length) return;
          var nextLen = out.length * 2;
          while (nextLen < outPos + n) nextLen *= 2;
          var next = new Uint8Array(nextLen);
          next.set(out);
          out = next;
        }}

        var bitBuf = 0, bitCnt = 0;
        function bits(n) {{
          while (bitCnt < n) {{
            bitBuf |= ((src[pos++] || 0) << bitCnt);
            bitCnt += 8;
          }}
          var v = bitBuf & ((1 << n) - 1);
          bitBuf >>>= n;
          bitCnt -= n;
          return v;
        }}
        function decodeSym(tree) {{
          while (bitCnt < tree.maxBits) {{
            bitBuf |= ((src[pos++] || 0) << bitCnt);
            bitCnt += 8;
          }}
          var entry = tree.table[bitBuf & tree.mask];
          var len = entry & 15;
          bitBuf >>>= len;
          bitCnt -= len;
          return entry >>> 4;
        }}

        var bfinal = 0;
        while (!bfinal) {{
          bfinal = bits(1);
          var btype = bits(2);
          if (btype === 0) {{
            bitBuf = 0; bitCnt = 0;
            var rawLen = src[pos] | (src[pos + 1] << 8);
            pos += 4;
            ensure(rawLen);
            out.set(src.subarray(pos, pos + rawLen), outPos);
            pos += rawLen; outPos += rawLen;
          }} else {{
            var litTree, distTree;
            if (btype === 1) {{
              litTree = FIXED_LIT_TREE;
              distTree = FIXED_DIST_TREE;
            }} else if (btype === 2) {{
              var hlit = bits(5) + 257, hdist = bits(5) + 1, hclen = bits(4) + 4;
              var clLens = new Uint8Array(19);
              for (var ci = 0; ci < hclen; ci++) clLens[CL_ORDER[ci]] = bits(3);
              var clTree = buildTree(clLens);
              var allLens = new Uint8Array(hlit + hdist);
              var ai = 0;
              while (ai < allLens.length) {{
                var s = decodeSym(clTree);
                if (s < 16) allLens[ai++] = s;
                else if (s === 16) {{
                  var rep = bits(2) + 3, prev = allLens[ai - 1];
                  for (var k = 0; k < rep; k++) allLens[ai++] = prev;
                }} else if (s === 17) ai += bits(3) + 3;
                else ai += bits(7) + 11;
              }}
              litTree = buildTree(allLens.subarray(0, hlit));
              distTree = buildTree(allLens.subarray(hlit));
            }} else {{
              throw new Error('بلوک فشرده نامعتبر');
            }}

            for (;;) {{
              var sym = decodeSym(litTree);
              if (sym < 256) {{
                if (outPos >= out.length) ensure(1);
                out[outPos++] = sym;
              }} else if (sym === 256) {{
                break;
              }} else {{
                var li = sym - 257;
                var length = LEN_BASE[li] + (LEN_EXTRA[li] ? bits(LEN_EXTRA[li]) : 0);
                var di = decodeSym(distTree);
                var dist = DIST_BASE[di] + (DIST_EXTRA[di] ? bits(DIST_EXTRA[di]) : 0);
                if (outPos + length > out.length) ensure(length);
                var srcIdx = outPos - dist;
                for (var m = 0; m < length; m++) out[outPos++] = out[srcIdx++];
              }}
            }}
          }}
        }}
        return out.subarray(0, outPos);
      }}

      function makeVfsResponse(bytes, mime) {{
        var copy = bytes.slice(0);
        if (typeof ReadableStream !== 'undefined') {{
          try {{
            var rs = new ReadableStream({{
              start: function (controller) {{
                controller.enqueue(copy);
                controller.close();
              }}
            }});
            return new Response(rs, {{
              status: 200,
              statusText: 'OK',
              headers: {{ 'Content-Type': mime }}
            }});
          }} catch (_) {{}}
        }}
        return new Response(new Blob([copy], {{ type: mime }}), {{
          status: 200,
          statusText: 'OK',
          headers: {{ 'Content-Type': mime }}
        }});
      }}

      async function bootSingleFileApp() {{
        try {{
          setProgress(25, 'گام ۱ از ۴: بازگشایی فونت فارسی و منابع…');
          await nextFrame();

          var vfsEl = document.getElementById('forough-vfs-json');
          var rawVfs = JSON.parse(vfsEl.textContent);
          vfsEl.remove();

          var vfsMap = Object.create(null);
          var keys = Object.keys(rawVfs);
          for (var i = 0; i < keys.length; i++) {{
            var k = keys[i];
            var entry = rawVfs[k];
            var bytes = gunzipSync(b64ToBytes(entry.gz));
            var rec = {{ bytes: bytes, mime: entry.mime }};
            vfsMap[k] = rec;
            if (k.indexOf('assets/') === 0) {{
              vfsMap[k.substring(7)] = rec;
            }}
          }}

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
                  return Promise.resolve(makeVfsResponse(hit.bytes, hit.mime));
                }}
              }}
            }} catch (_) {{}}
            return origFetch(input, init);
          }};

          setProgress(55, 'گام ۲ از ۴: راه‌اندازی موتور گرافیکی آیفون…');
          await nextFrame();

          var ckJsEl = document.getElementById('forough-ck-js');
          var ckWasmEl = document.getElementById('forough-ck-wasm');
          var ckJsBytes = gunzipSync(b64ToBytes(ckJsEl.textContent));
          var wasmBytes = gunzipSync(b64ToBytes(ckWasmEl.textContent));
          ckJsEl.remove();
          ckWasmEl.remove();

          var ckJsText = new TextDecoder('utf-8').decode(ckJsBytes);
          var ckScript = document.createElement('script');
          ckScript.textContent = ckJsText;
          document.head.appendChild(ckScript);

          window.flutterCanvasKit = await window.__ForoughCanvasKitInit({{
            instantiateWasm: function (imports, receiveInstance) {{
              WebAssembly.instantiate(wasmBytes, imports).then(function (output) {{
                receiveInstance(output.instance, output.module);
              }}, function (err) {{
                setProgress(100, 'خطا در موتور WASM: ' + err);
              }});
              return {{}};
            }}
          }});
          window.flutterCanvasKitLoaded = Promise.resolve(window.flutterCanvasKit);

          setProgress(82, 'گام ۳ از ۴: بارگذاری ماژول‌های فروغ آریا…');
          await nextFrame();

          var mainEl = document.getElementById('forough-main-js');
          var mainBytes = gunzipSync(b64ToBytes(mainEl.textContent));
          mainEl.remove();
          var mainJsText = new TextDecoder('utf-8').decode(mainBytes);

          window._flutter = window._flutter || {{}};
          window._flutter.loader = {{
            didCreateEngineInitializer: async function (engineInitializer) {{
              try {{
                setProgress(95, 'گام ۴ از ۴: ترسیم صفحهٔ ورود…');
                var appRunner = await engineInitializer.initializeEngine({{
                  assetBase: 'https://forough.vfs/',
                  renderer: 'canvaskit'
                }});
                await appRunner.runApp();
              }} catch (initErr) {{
                setProgress(100, 'خطا در راه‌اندازی فلاتر: ' + (initErr && initErr.message ? initErr.message : String(initErr)));
              }}
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

      if (document.readyState === 'loading') {{
        document.addEventListener('DOMContentLoaded', bootSingleFileApp);
      }} else {{
        bootSingleFileApp();
      }}
    }})();
  </script>
</body>
</html>
"""
    with open(OUT_HTML, 'w', encoding='utf-8') as out:
        out.write(html)
    sz_mb = os.path.getsize(OUT_HTML) / (1024 * 1024)
    print(f'Built Single-File HTML v1.70.1: {OUT_HTML} ({sz_mb:.2f} MB)')


if __name__ == '__main__':
    main()
