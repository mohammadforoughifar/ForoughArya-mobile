# راهنمای کاهش حجم اپ فروغ آریا (Flutter)

مخزن را کلون کردم و تغییرات زیر روی شاخهٔ کاری اعمال و **کامیت** شد.
پچ آماده هم برای اعمال روی مخزن اصلی در فایل `forougharya-size-optimization.patch` ذخیره شده است.

---

## ۱) فونت وزیرمتن سبک‌سازی شد (بزرگ‌ترین برداشت مستقیم روی حجم فایل در مخزن)

| قبل | بعد |
|---|---|
| `assets/fonts/Vazirmatn.ttf` = **122 KB** (۱۳۳۳ گلیف) | **77 KB** (۸۷۰ گلیف) |

کار انجام‌شده: subset با `fonttools` روی بازه‌های مورد نیاز یک اپ فارسی:

- `U+0020–007E`, `U+00A0–00FF` (لاتین + اعداد + علائم)
- `U+0600–06FF`, `U+0750–077F`, `U+08A0–08FF` (عربی/فارسی، نیم‌فاصله ZWNJ، اعراب)
- `U+2000–206F` (علائم تایپوگرافی: «» – — ٪ …)، `U+20A0–20BF` (ارزها)، `U+2190–21FF` (فلش‌ها)، `U+25A0–25FF`
- همهٔ جداول GSUB/GPOS (ccmp/init/medi/fina/rlig/calt/mark/mkmk/kern) **دست‌نخورده** → چسبیدن حروف فارسی کاملاً سالم

**تست صحت:** با HarfBuzz خروجی شکل‌دهی (گلیف‌ها + advance/offset) برای نمونه‌هایی مثل
«سلام دنیا»، «می‌خواهم»، «پ چ ژ گ ک ی»، «۱۲۳۴۵۶۷۸۹۰»، «Report 2026 — 1,250,000 ریال» با فونت اصلی
**بایت‌به‌بایت یکسان** بود. تنها تفاوت در برخی ایموجی‌های تزئینی (مثل ★) است که همه‌جا از فونت سیستم نمایش داده می‌شوند.

> ⚠️ اگر بعداً به کاراکترهای خارج از این بازه نیاز شد (مثلاً حروف روسی/یونانی یا نمادهای خاص)، باید subset را بازتولید کنید. دستور بازتولید در انتهای فایل آمده است.

## ۲) حذف وابستگی‌های بی‌استفاده (`pubspec.yaml`)

بررسی کردم هیچ ایمپورتی از این‌ها در `lib/` و `test/` نیست:

- `cupertino_icons` (فونت/آیکن ۲۵۰KB+ در بسته‌ها، و در کد استفاده نمی‌شد)
- `intl` (تاریخ/عدد با `shamsi_date` و کد خودتان انجام می‌شود)

حذف این‌ها هم حجم وابستگی‌های ترای را کم می‌کند و هم تعداد پلاگین‌های بسته‌بندی‌شده را.

## ۳) تنظیمات Android برای کوچک‌تر شدن APK/AAB

`android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    // فقط زبان‌های مورد استفاده در اپ بسته‌بندی شوند (حذف زبان‌های کتابخانه‌های Flutter/AndroidX)
    resourceConfigurations += listOf("fa", "en")
}

buildTypes {
    release {
        isMinifyEnabled = true        // R8: حذف کد بی‌استفاده
        isShrinkResources = true      // حذف منابع بی‌استفاده
        proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
    }
}
```

`android/app/proguard-rules.pro` (فایل جدید): قواعد keep برای Flutter embedding و پلاگین‌های
`flutter_secure_storage`, `file_picker`, `share_plus`, `open_filex`, `image_picker` + حذف `Log.d/v` در release.

`android/gradle.properties`: افزودن `android.enableR8.fullMode=true` و `android.enableResourceOptimizations=true`.

` .gitattributes` (جدید): علامت‌گذاری فونت/تصاویر به‌صورت binary (جلوگیری از خرابی و بزرگ‌شدن دیف).

---

## ۴) دستورهای ساخت با کمترین حجم

```bash
flutter clean
flutter pub get

# AAB برای Google Play — کمترین حجم دانلود برای کاربر (Play خودش per-device می‌دهد)
flutter build appbundle --release

# APK سبک برای هر معماری جداگانه (هر کدام ~۳۰–۵۰٪ کوچک‌تر از یونیورسال)
flutter build apk --release --split-per-abi
# خروجی‌ها: app-armeabi-v7a-release.apk / app-arm64-v8a-release.apk / app-x86_64-release.apk

# اختیاری: مبهم‌سازی نام‌ها (حجم کمتر + امنیت بیشتر)
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

## ۵) قدم‌های بعدی با اثر بیشتر (اختیاری)

1. **همیشه AAB بدهید، نه APK یونیورسال** — بزرگ‌ترین تفاوت حجم دانلود کاربران از همین‌جا می‌آید (Play فقط معماری دستگاه کاربر را می‌فرستد).
2. **`--split-per-abi`** وقتی APK مستقیم توزیع می‌کنید.
3. **`previews/*.html` (۱۲۰KB)** داخل مخزن است ولی در باندل نمی‌رود؛ فقط حجم کلون را زیاد می‌کند — اگر لازم نیست، از مخزن خارجش کنید.
4. اگر بعداً تصویر/آیکن اضافه کردید: `webp` + چند رزولوشن (mdpi…xxxhdpi) به‌جای PNG بزرگ.
5. برای درخواست‌های شبکه‌ای تصاویر از `cached_network_image` با `cacheWidth` استفاده کنید (حجم حافظه/دیتا، نه APK).
6. آیکن لانچر فعلی از mipmapهای پیش‌فرض Flutter است؛ اگر آیکن اختصاصی گذاشتید، یک نسخهٔ برداری/`adaptive icon` بسازید.

### بازتولید فونت subset (اگر لازم شد)

```bash
pip install fonttools
python - <<'EOF'
from fontTools import subset
ranges=[(0x0020,0x007E),(0x00A0,0x00FF),(0x2000,0x206F),(0x20A0,0x20BF),
        (0x2190,0x21FF),(0x25A0,0x25FF),(0x0600,0x06FF),(0x0750,0x077F),(0x08A0,0x08FF)]
chars=set(c for a,b in ranges for c in range(a,b+1))
o=subset.Options(); o.layout_features=['*']; o.name_IDs=['*']; o.notdef_outline=True
f=subset.load_font("Vazirmatn-full.ttf",o)
s=subset.Subsetter(options=o); s.populate(text="".join(map(chr,chars))); s.subset(f)
subset.save_font(f,"assets/fonts/Vazirmatn.ttf",o)
EOF
```

---

## اعمال تغییرات روی مخزن خودتان

```bash
git clone https://github.com/mohammadforoughifar/ForoughArya-mobile.git
cd ForoughArya-mobile
git am /path/to/forougharya-size-optimization.patch
flutter clean && flutter pub get && flutter build appbundle --release
```

> نکته: `pubspec.lock` را پس از حذف دو وابستگی باید با `flutter pub get` تازه کنید (در این محیط Flutter نصب نبود، پس lock دست‌نخورده مانده است).
