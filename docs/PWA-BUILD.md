# راهنمای ساخت و انتشار وب‌اپلیکیشن آیفون (iOS PWA) فروغ آریا

> مرجع اصلی **ساخت خروجی وب‌اپلیکیشن (PWA)** از ریشهٔ همین مخزن است.
> هر بار که «خروجی بگیر» خواسته شد، همین گردش کار اجرا می‌شود.
> (آخرین نسخهٔ معتبر در زمان نگارش: `v1.70.7+86` — 2026-11-24)

---

## ۱. پیش‌نیازها (همان محیط بیلد اندروید)

```bash
export PATH=/opt/sdk/flutter/bin:/opt/sdk/android/platform-tools:/opt/sdk/jdk17/bin:$PATH
export FLUTTER_ROOT=/opt/sdk/flutter
export PUB_CACHE=/opt/sdk/pub-cache
export ANDROID_HOME=/opt/sdk/android
export ANDROID_SDK_ROOT=/opt/sdk/android
export JAVA_HOME=/opt/sdk/jdk17
export GRADLE_USER_HOME=/opt/sdk/gradle-cache
```

پوشه‌های اصلی:

| مسیر | کاربرد |
|---|---|
| `web/` | قالب PWA: `index.html`, `pwa-config.js`, `ios-pwa-helper.js`, `manifest.json`, `web.config` (IIS), `sw.js`, `push-worker.js`, آیکن‌ها و اسپلش‌ها |
| `tools/build_single_file_pwa.py` | ساخت نسخهٔ **تک‌فایل** کاملاً خودکفا (تمام دارایی‌ها داخل یک `.html`) |
| `deploy/` | `Dockerfile`, `docker-compose.yml`, `nginx.conf`, `serve-local.py` برای میزبانی Nginx/Docker |
| `docs/README-iPhone-PWA-FA.md` | راهنمای استقرار و نصب روی سرور/آیفون (همین سند مکمل آن است) |

> ⚠️ `build/` در `.gitignore` است؛ خروجی‌ها باید در پایان ساخت به مونوریشهٔ
> workspace (`/home/user/…`) کپی شوند تا در snapshot گیت/اکستونت باقی بمانند.

---

## ۲. ساخت وب‌اپ (پوشه‌ای)

```bash
cd ForoughArya-mobile
flutter build web --no-wasm-dry-run --no-web-resources-cdn --release
```

خروجی در `build/web/` ساخته می‌شود. سپس به پوشهٔ نشر (Deploy) کپی کنید:

```bash
mkdir -p ../ForoughArya-iOS-PWA
cp -a build/web/. ../ForoughArya-iOS-PWA/
rm -f ../ForoughArya-iOS-PWA/.last_build_id
# خواندن فایل فلاتر سرویس‌ورکر فلاتر (flutter_service_worker.js) با sw.js دستی تداخل دارد
rm -f ../ForoughArya-iOS-PWA/flutter_service_worker.js
```

نکته‌ها:

- `--no-web-resources-cdn` اجباری است تا CanvasKit از داخل خود بسته لود شود
  (بدون درخواست به `gstatic.com` — اجرای کامل روی اینترنت داخلی).
- فایل `version.json` خودکار ساخته می‌شود (`flutter build web` آن را
  از `pubspec.yaml` می‌خواند)؛ پس از هر بالا بردن نسخه آن در تمام مسیرها یکی می‌شود.
- `web/pwa-config.js` بدون نیاز به کامپایل مجدد روی سرور قابل ویرایش است؛
  مقدار `apiBaseUrl` را حتماً مطابق «حالت الف/ب/ج» در `docs/README-iPhone-PWA-FA.md` تنظیم کنید.

---

## ۳. ساخت تک‌فایل خودکفا `ForoughArya-SingleFile-vX.Y.Z.html`

```bash
cd ForoughArya-mobile
python3 tools/build_single_file_pwa.py
# یا نام دلخواه نسخه:
SINGLEFILE_VERSION=v1.70.7 python3 tools/build_single_file_pwa.py
cp /home/user/ForoughArya-SingleFile-v1.70.7.html /home/user/ForoughArya-iOS-PWA/single.html
```

- فایل خروجی در `/home/user/ForoughArya-SingleFile-vX.Y.Z.html` ساخته می‌شود
  و کل اپ (فونت فارسی، CanvasKit، JS، آیکن‌ها) با یک بارگذاری گزیپ‌بیس۶۴ باز می‌شود.
- بدون اینترنت، زیر "file://" یا از QuickLook آیفون هرگز به دانلود جداگانه نیاز ندارد.
- `ios-pwa-helper.js` (شیم `isSecureContext` + WebCrypto XOR برای HTTP) داخل هر دو
  خروجی هست، پس اگر سرور روی HTTP میزبانی می‌شود ذخیرهٔ امن و لاگین کار می‌کند.

---

## ۴. بستهٔ استقرار (ZIP) برای سرور ریشهٔ IIS / Nginx

```bash
cd /home && python3 - <<'PY'
import zipfile, os
src = '/home/user/ForoughArya-iOS-PWA'
dst = '/home/user/ForoughArya-iOS-PWA-v1.70.7.zip'
with zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
    for root, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if d != '.git']
        for f in files:
            full = os.path.join(root, f)
            zf.write(full, arcname=os.path.join('ForoughArya-iOS-PWA', os.path.relpath(full, src)))
print('built:', dst)
PY
```

برای ریشهٔ سرور (که آنجا pwa را گذاشتند و بالا رفت)، همین پوشه را بعد از جایگزینیٔ `main.dart.js` و `ios-pwa-helper.js` کامل کپی کنید. رسیدن سایر فایل‌ها (HTML/JS) پس از بازیابی عمومی `Ctrl+F5` کافی است.

---

## ۵. نسخه‌سازی و بالا بردن ورژن

1. `pubspec.yaml` ← `version: 1.70.7+86` (فرمت `X.Y.Z+BUILD`).
2. در صورت نیاز `README`های `docs/README-iPhone-PWA-FA.md` و این سند به‌روز شود.
3. ابتدا بیلد وب می‌گیریم (خوانندهٔ `version.json`)، سپس تک‌فایل، سپس ZIP.
4. خروجی‌های ثابت:
   - `/home/user/ForoughArya-iOS-PWA/` (پوشهٔ مورد استفاده در سرور ریشه)
   - `/home/user/ForoughArya-iOS-PWA-vX.Y.Z.zip`
   - `/home/user/ForoughArya-SingleFile-vX.Y.Z.html`
   - (در صورت نیاز برای دانلود مستقیم) همین‌ها در GoFile/TmpFiles آپلود می‌شوند.

---

## ۶. رفع مشکلات شناخته‌شده

| علامت | علت | درمان |
|---|---|---|
| «در حال بازگشایی بستهٔ تک‌فایل…» گیر می‌کند | `DecompressionStream` در WebKit/Safari قفل می‌کند | رفع شده: در تک‌فایل فقط موتور pure-JS gunzip باقی مانده است؛ همین فایل را استفاده کنید |
| لاگین روی وب/پس از HTTP می‌خورد یا خطای شبکهٔ بی‌دلیل می‌دهد | `flutter_secure_storage_web` در HTTP بدون HTTPS پرتاب می‌کند و مسیر درخواست می‌مرد | رفع شده در `web/ios-pwa-helper.js` (شیم `isSecureContext=true` + WebCrypto XOR) + مهار همهٔ دسترسی‌های `FlutterSecureStorage` در `api_client.dart`، `connection_manager.dart`، `auth_controller.dart` |
| «اتصال‌ها / تنظیمات سرور» ذخیره نمی‌شد | همان خطای secure-storage در مسیر ذخیرهٔ پروفایل‌ها | همان رفع بالا (هم‌زمان). بعد از جایگزینیٔ فایل‌ها `Ctrl+F5` الزامی است |
| «تست» سبز است ولی لاگین نمی‌خورد | تست هر پاسخ‌گویی (حتی 404/خطای IIS) را سرور در دسترس می‌داند | آدرس API را یکی از این سه کنید: (الف) پروکسی معکوس `/api` روی همان IIS/Nginx → هیچ تنظیمی لازم نیست؛ (ب) `pwa-config.js` → `apiBaseUrl: "https://erp.company.ir"` + بازکردن CORS برای دامنهٔ وب‌اپ؛ (ج) داخل خود اپ، «سرور جدید» با آدرس واقعی بسازید و تست/ذخیره کنید |
| میکروفن در دستور کار کار نمی‌کند | پلاگین وب `locales()` برمی‌گرداند `[]` و هیچ‌وقت `finalResult` نمی‌دهد | رفع شده در `voice_input_button.dart`: روی وب `fa-IR` مستقیم + نتایج جزئی در بافر و تزریق هنگام `done/notListening` |
| میکروفن/Voice روی Safari/Chrome موبایل اصلاً مجاز نیست | مرورگرها SpeechRecognition را فقط روی **HTTPS** می‌دهند (یا localhost) | حتماً به HTTPS مهاجرت کنید؛ روی خود HTTP هیچ راه‌حل برنامه‌ای وجود ندارد (تنها روی اندروید اپ بومی قابل استفاده است) |
| پس از تعویض فایل‌ها، همان نسخهٔ قدیمی می‌آید | کش Service Worker/سافاری | `Ctrl+F5` یا حذف SW: در DevTools → Application → Service Workers → Unregister، و پاک‌کردن Cache |

---

## ۷. بررسی سلامت قبل از تحویل

```bash
flutter analyze --no-pub                 # صفر error الزامی است
flutter test test/connection_manager_test.dart test/office_automation_test.dart test/email_test.dart
python3 -c "import zipfile; zipfile.ZipFile('/home/user/ForoughArya-iOS-PWA-vX.Y.Z.zip').testzip(); print('zip OK')"
```

- برای تک‌فایل: خروجی باید شامل `flutterCanvasKit` و شورت‌کد `isSecureContext` باشد.
- `ios-pwa-helper.js` در هر دو خروجی باید ۴۰ تا ۵۰ بار `isSecureContext` را داشته باشد (شیم فعال).
- `single.html`/تک‌فایل در مرورگر باز می‌شود و اسپلش «سامانه جامع فروغ آریا» می‌آید؛
  اگر در پخش QuickLook آیفون گرفتار شدید، فایل را از «فایل‌ها» و با **Documents/Chrome** باز کنید.
