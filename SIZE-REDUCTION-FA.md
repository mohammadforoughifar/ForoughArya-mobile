# راهنمای کاهش حجم اپ و مخزن فروغ آریا (v1.60.1+66)

مخزن کلون شد و بهینه‌سازی‌های جامع مرحلهٔ دوم (متناسب با رشد پروژه تا نسخهٔ `1.60.1+66`) روی هم **حجم فایل APK/AAB/PWA خروجی** و هم **حجم مخزن/سورس دانلودی** اعمال و کامیت شد.

---

## خلاصهٔ تغییرات انجام‌شده در این مرحله

### ۱) فشرده‌سازی کتابخانه‌های بومی و حذف معماری شبیه‌ساز در Android (`بیشترین اثر روی حجم فایل APK`)

در Flutter جدید (`minSdk >= 24` و AGP `8.12.1`) دو رفتار پیش‌فرض باعث ۲ تا ۳ برابر شدن حجم فایل `app-release.apk` می‌شد که هر دو اصلاح شدند (`android/app/build.gradle.kts`):

1. **`packaging.jniLibs.useLegacyPackaging = true`:**
   به‌طور پیش‌فرض، اندروید فایل‌های بزرگ `libflutter.so` و `libapp.so` را **بدون فشرده‌سازی (0% compression)** داخل فایل `.apk` ذخیره می‌کرد که حجم فایل دانلودی APK را حدود **۲ برابر** می‌کرد. اکنون کتابخانه‌های `.so` داخل APK فشرده می‌شوند (~۵۰٪ کاهش حجم فایل دانلودی APK).
2. **`ndk.abiFilters.remove("x86_64")` و `debugSymbolLevel = "NONE"` در بیلد `release`:**
   معماری شبیه‌ساز کامپیوتر (`x86_64`) به‌طور خودکار از بیلد `release` حذف شد، در حالی که هر دو معماری گوشی‌های واقعی (`arm64-v8a` و `armeabi-v7a`) حفظ می‌شوند و با `--split-per-abi` و `--target-platform` نیز تداخلی ندارد (**~۱۵ تا ۲۵ مگابایت کاهش مستقیم در APK یونیورسال**). سمبل‌های دیباگ بومی نیز از فایل‌های `.so` حذف شدند.
3. **حذف متادیتای اضافی (`META-INF/*`, `DebugProbesKt.bin`, `kotlin-tooling-metadata.json`)** و تکمیل قواعد `proguard-rules.pro` برای `flutter_local_notifications`، `GSON TypeToken` و `speech_to_text` به همراه حذف `Log.v/d/i` در نسخهٔ نهایی.

---

### ۲) حذف ۳ وابستگی سنگین و غیرضروری از `pubspec.yaml`

| بستهٔ حذف‌شده | دلیل و اثر واقعی روی حجم و مصرف منابع |
|---|---|
| **`timezone`** (`^0.11.2`) | فایل `timezone/data/latest_all.dart` در `push_service.dart` ایمپورت شده بود اما در هیچ‌جای اپ زمان‌بندی منطقه‌ای (`zonedSchedule`) استفاده نمی‌شد! این ایمپورت کل دیتابیس تاریخی IANA (**~۱.۰۵ مگابایت دادهٔ باینری**) را مستقیماً داخل `libapp.so` و `main.dart.js` کامپایل می‌کرد. |
| **`workmanager`** (`^0.10.10`) | پس از اضافه‌شدن سرویس پیش‌زمینهٔ بومی اندروید (`PushPollingService.kt` هر ۶۰ ثانیه)، `workmanager` عملاً تکراری بود (در iOS هم پیکربندی نشده بود)، هر ۱۵ دقیقه یک موتور Flutter کامل در پس‌زمینه بالا می‌آورد و کتابخانه‌های سنگین `WorkManager + Room + SQLite` (**~۱.۲ تا ۱.۵ مگابایت DEX**) را وارد APK می‌کرد. همچنین مجوزهای بلااستفادهٔ `SCHEDULE_EXACT_ALARM` و `USE_EXACT_ALARM` از `AndroidManifest.xml` حذف شدند. |
| **`uuid`** (`^4.6.0`) | همراه با بسته‌های وابسته (`crypto`, `fixnum`, `sprintf`) فقط در ۲ خط برای تولید `Uuid().v4()` به کار رفته بود و با تابع سبک ۱۸ خطی استاندارد RFC-4122 (`lib/core/utils/uuid_v4.dart` مبتنی بر `Random.secure()`) جایگزین شد. |

> در مرحلهٔ اول نیز بسته‌های بی‌استفادهٔ `cupertino_icons` و `intl` حذف شده بودند.

---

### ۳) کوچک‌سازی بیشتر فونت وزیرمتن و تصاویر بدون افت کیفیت (Lossless)

| مورد | قبل | مرحلهٔ ۱ | مرحلهٔ ۲ (فعلی) |
|---|---|---|---|
| `assets/fonts/Vazirmatn.ttf` | **122 KB** (۱۳۳۳ گلیف) | 77 KB (۸۷۰ گلیف) | **56 KB** (۶۰۲ گلیف — ۵۳٪ کوچک‌تر از نسخهٔ اولیه) |
| ۲۹ آیکن PNG (`web/`, `ios/`, `android/`) | **117 KB** | 117 KB | **102 KB** (فشرده‌سازی بدون افت پیکسلی، تأییدشده با مقایسهٔ بایت‌به‌بایت تصویر) |

- حروف غیرکاربردی پشتو/اردو/سندی/اویغوری و کاراکترهای نوردیک از `Vazirmatn.ttf` حذف شدند، در حالی که **تمامی حروف فارسی، عربی، اعراب، اعداد فارسی/عربی/لاتین، علائم تایپوگرافی («» – — … ٪ € ریال) و جداول اتصال حروف `GSUB`/`GPOS` کاملاً حفظ شده‌اند** و خروجی شکل‌دهی حروف با موتور **HarfBuzz** به‌صورت خودکار تست و ۱۰۰٪ یکسان تأیید شد.

---

### ۴) پاک‌سازی فایل‌های مرده و پیش‌نمایش‌های قدیمی از مخزن

- حذف ۲ فایل Dart یتیم و بدون هیچ ایمپورت در کل پروژه (`office_archive_page.dart` و `office_drafts_page.dart` = **24 KB**).
- حذف پوشهٔ پیش‌نمایش‌های ایستا و قدیمی `previews/*.html` (**115 KB**) که وارد اپ نمی‌شدند و صرفاً حجم کلون مخزن را بالا می‌بردند.

---

## دستور ساخت نسخهٔ نهایی با کمترین حجم ممکن

اسکریپت آماده در پوشهٔ `scripts/` قرار داده شده است که فلگ‌های `--tree-shake-icons`، `--obfuscate` و `--split-debug-info=build/symbols` (کاهش ۳۰ تا ۴۵ درصدی حجم `libapp.so` روی ۱۷۲ فایل Dart پروژه) را به‌صورت خودکار اعمال می‌کند:

```bash
# ۱) ساخت APK تفکیک‌شده (پیشنهادی: کمترین حجم برای هر گوشی)
bash scripts/build-slim.sh apk-split
# خروجی‌ها در build/app/outputs/flutter-apk/:
#   app-arm64-v8a-release.apk   (مناسب بیش از ۹۵٪ گوشی‌های اندرویدی)
#   app-armeabi-v7a-release.apk (گوشی‌های قدیمی ۳۲ بیتی)

# ۲) ساخت تک‌فایل APK فقط ۶۴ بیتی
bash scripts/build-slim.sh apk-arm64

# ۳) ساخت تک‌فایل APK یونیورسال (۳۲ + ۶۴ بیتی، بدون شبیه‌ساز x86_64)
bash scripts/build-slim.sh apk-universal

# ۴) ساخت AAB برای استورها
bash scripts/build-slim.sh aab

# ۵) ساخت وب (PWA) کم‌حجم
bash scripts/build-slim.sh web
```

در ویندوز (PowerShell):
```powershell
.\scripts\build-slim.ps1 apk-split
```

---

## اعمال مستقیم پچ روی مخزن اصلی شما

```bash
cd ForoughArya-mobile
git am /path/to/forougharya-size-optimization.patch
flutter clean && flutter pub get
bash scripts/build-slim.sh apk-split
```
