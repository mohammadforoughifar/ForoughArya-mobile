# ماژول اتوماسیون اداری — پیاده‌سازی در اپ اندروید (فلاتر)

این سند توضیح می‌دهد ماژول **اتوماسیون اداری** پروژهٔ
`TotallCollectionSoftware` (بک‌اند C#) چگونه به اپ فلاتر `ForoughArya-mobile` اضافه شد.

---

## ۱. منبع استخراج (بررسی کامل بک‌اند)

ماژول از این بخش‌های مخزن C# استخراج و تطبیق داده شد:

| بخش بک‌اند | مسیر | کاربردی که منتقل شد |
|---|---|---|
| موجودیت‌های نامه | `src/Inventory.Api/Entities/Office/` | `OfficeAutomation.cs` (LetterSource، InnerLetter، Erja، Amalgar، Pishnevis، RelatedLetter، LetterBayegani، LetterGroup، LetterStrature)، `OutgoingLetter.cs`، `IncomingLetter.cs` |
| کنترلرها | `src/Inventory.Api/Controllers/Office/` | `InnerLettersController` (674 خط)، `OutgoingLettersController` (897)، `IncomingLettersController` (510) |
| DTOها | `src/Inventory.Shared/Dtos/LetterDtos.cs` + `OutgoingLetterDtos.cs` | همهٔ فیلدهای فرم و پاسخ‌ها |
| قرارداد صفحه‌بندی | `src/Inventory.Api/Services/Paging.cs` | سه شکل پاسخ پشتیبانی می‌شود |
| قواعد أعمالی | داخل کنترلرها | سقف ۲۰MB پیوست، سقف ۵۰۰ ردیف در lookup، ۲۰۰۰ گره بایگانی |

> ماژول‌های دیگر مخزن (حقوق و دستمزد، مالی، انبار، مودیان، ماشین‌های اداری، ایمیل، صورت‌جلسه)
> **عمداً وارد نشدند** — درخواست شما فقط «اتوماسیون اداری» بود.

---

## ۲. ساختار فایل‌های جدید در اپ

```
lib/
├── app/
│   ├── app.dart              ← تغییر: WorkOrdersPage → HomeShell
│   └── home_shell.dart       ← NEW: ناوبری پایین بین ۲ ماژول
├── main.dart                 ← تغییر: ثبت OfficeAutomationRepository
└── features/office_automation/
    ├── models/
    │   ├── office_common.dart      ← Paged<T>، گیرنده، گروه، عملگر، گردش، بایگانی، آمار، ثابت‌ها
    │   └── letter_models.dart      ← سطر کارتابل، جزئیات داخلی/صادره، ارجاع، پیش‌نویس، امضاکننده
    ├── data/
    │   └── office_repository.dart  ← همهٔ فراخوانی‌های API + enum LetterKind
    └── presentation/
        ├── office_home_page.dart   ← ۸ تب: داشبورد، داخلی، صادره، وارده، امضا، دبیرخانه، بایگانی، پیش‌نویس
        ├── letter_detail_page.dart ← جزئیات + ارجاع + پاسخ + امضا + دبیرخانه + پیوست + گردش
        ├── letter_editor_page.dart ← فرم ثبت/ویرایش هر سه نوع نامه
        ├── office_archive_page.dart← بایگانی درختی سه‌سطحی
        ├── office_drafts_page.dart ← پیش‌نویس‌ها
        └── office_widgets.dart     ← کارت نامه، بج‌ها، انتخاب‌گر گیرندگان/گروه‌ها
test/
└── office_automation_test.dart     ← ۱۳ تست نگاشت داده
```

---

## ۳. نگاشت API (عیناً مطابق کنترلرها)

### نامهٔ داخلی — `/api/letters`
```
GET    /inbox?search&unreadOnly&page&pageSize&skip&take
GET    /sent        GET /archive      GET /stats
GET    /{id}        POST /            PUT /{id}      DELETE /{id}
GET    /{id}/print?size=A4&withHamesh
GET    /{id}/gardesh    GET /pick
POST   /{id}/neshan
POST   /erja        POST /erja/{erjaId}/answer|read|neshan|bayegani
POST   /erja/batch-bayegani
GET    /bayegani/tree   POST /bayegani/main-category|sub-category|letters
GET/POST /pishnevis     DELETE /pishnevis/{id}
GET    /recivers   /groups   /amalgars
GET/POST/DELETE /{id}/attachments …
```

### نامهٔ صادره — `/api/outgoing-letters`
```
GET  /inbox  /signing-inbox  /sent  /archive  /dabirkhane  /stats
GET  /{id}      POST /{id}/sign         POST /{id}/status
GET  /{id}/signers      GET /available-signers
GET  /{id}/copy-tos     PUT /{id}/copy-tos
POST /{id}/dabirkhane   ← ثبت دبیرخانه و ارسال
GET  /dabirkhane/stats  /dabirkhane/creators  /dabirkhane/bayegani/tree
GET  /companies  /companies/active
GET  /{id}/print?size=A4&withCopy
```

### نامهٔ وارده — `/api/incoming-letters`
```
GET  /inbox  /sent  /archive  /stats  /{id}
POST /            POST /{id}/finalize    PUT/DELETE /{id}
GET  /reservations?typeForm=3   POST /reserve-number
POST /{id}/neshan   /{id}/bayegani
```

### قرارداد پاسخ صفحه‌بندی (از `Paging.cs`)
| حالت | پاسخ | رفتار اپ |
|---|---|---|
| بدون `skip/take` | آرایهٔ ساده | همهٔ آیتم‌ها |
| با `skip/take` | `{ total, items }` | `Paged.totalCount` پر می‌شود |
| مسیر قدیمی | `{ items, totalCount, page, pageSize }` | پشتیبانی می‌شود |

---

## ۴. قابلیت‌هایی که در UI دیده می‌شوند

### داشبورد
- بنر «کارتابل امروز» با تعداد خوانده‌نشده (جمع سه کارتابل)
- ۸ دکمهٔ دسترسی سریع
- ۶ شمارندهٔ کلیک‌پذیر: دریافتی، ارسالی، نشان‌شده، پیش‌نویس، در انتظار امضا، دبیرخانه

### کارتابل‌ها (داخلی / صادره / وارده)
- جست‌وجوی سروری + بارگذاری تدریجی (infinite scroll) + pull-to-refresh
- کارت هر نامه: عنوان، شماره اندیکاتور، فرستنده/سازمان، تاریخ شمسی، ستارهٔ نشان
- بج‌های وضعیت: فوریت، محرمانگی، نوع ارجاع (گیرنده/ارجاع/هامش)، پیوست، تأیید/رد، «پاسخ دارد»، مهلت پاسخ (با هشدار قرمز اگر گذشته)، شمارهٔ صادره

### جزئیات نامه
- کارت سربرگ با همهٔ بج‌ها + متن نامه (قابل انتخاب/کپی)
- گیرندگان در سه دستهٔ جدا: **گیرنده / ارجاع / هامش**
- نامه‌های مرتبط با برچسب **عطف** یا **پیرو**
- کارت «ارجاع به شما»: فرستنده، عملگر، مهلت، دستور، پاسخ، وضعیت تأیید
- **گردش نامه** به‌صورت درخت تودرتو (سطح‌بندی با `ParentErjaId`)
- پیوست‌ها: آپلود (سقف ۲۰MB سرور)، دانلود و باز کردن فایل، حذف

### نامهٔ صادره
- اطلاعات کامل گیرندهٔ بیرونی (سازمان، شخص، سمت، آدرس، شمارهٔ نامهٔ طرف مقابل)
- رونوشت‌ها از جدول مستقل `CopyTos`
- **زنجیرهٔ امضا** با ترتیب شماره‌دار و وضعیت هر امضاکننده
- دکمهٔ «امضای نامه» فقط وقتی **نوبت کاربر جاری** است (رعایت `Order`)
- پس از امضای آخرین نفر → شمارهٔ صادره (`SadereNumber`) صادر می‌شود
- کارت دبیرخانه با روش ارسال و فیلدهای وابسته:
  - ایمیل → آدرس ایمیل مقصد
  - پست / پست پیشتاز → کد رهگیری + نام تحویل‌گیرنده
  - پیک / تحویل حضوری → نام تحویل‌گیرنده
  - فکس → شماره فکس مقصد

### فرم ثبت نامه
- **داخلی**: عنوان، متن، محرمانگی، فوریت، سه دستهٔ گیرنده، عطف/پیرو
- **صادره**: افزون بر موارد بالا، سازمان مقصد (الزامی)، شخص/سمت/آدرس، رونوشت، شمارهٔ خارجی، شرکت صادرکننده (سربرگ چاپ)، انتخاب امضاکنندگان از `available-signers`
- **وارده**: فرستنده (الزامی)، شمارهٔ نامهٔ مبدأ، تاریخ نامه/ثبت، روش ارسال، تحویل‌گیرنده، محرمانگی و فوریت **عددی** (مطابق مدل C#: ۰..۳)، شمارهٔ اندیکاتور **رزرو خودکار** از `reserve-number`
- دکمهٔ **ذخیرهٔ پیش‌نویس** در همهٔ انواع

### انتخاب گیرنده
- جست‌وجو در نام و **سمت‌ها** (`Positions`)
- انتخاب گروهی: با یک ضربه همهٔ اعضای گروه اضافه می‌شوند (`LetterGroup.Members`)

### بایگانی و پیش‌نویس
- سه‌گانهٔ داخلی/صادره/وارده
- درخت پوشه با افزودن دستهٔ اصلی، زیرپوشه، تغییر نام، حذف
- برگ نامه با شماره، سازمان مقصد، روش ارسال، تاریخ

---

## ۵. تصمیم‌های فنی

1. **بدون وابستگی جدید** — فقط از پکیج‌های موجود پروژه استفاده شد
   (`dio`, `provider`, `file_picker`, `open_filex`, `path_provider`, `shamsi_date`).
2. **تحمل تفاوت نام‌گذاری** — تابع `pick()` هم `camelCase` و هم `PascalCase` را می‌خواند،
   چون بعضی مسیرهای ASP.NET با تنظیمات پیش‌فرض `PascalCase` برمی‌گردانند.
3. **هم‌خوانی با معماری موجود** — `ApiClient` مشترک، توکن از `flutter_secure_storage`،
   مدیریت ۴۰۱ با `onUnauthorized`، خطاها به‌صورت `ApiException` با پیام فارسی.
4. **RTL و فونت** — همهٔ صفحه‌ها داخل `Directionality.rtl` و فونت `Vazirmatn` اپ قرار می‌گیرند.
5. **ناوبری** — `HomeShell` با `IndexedStack` تا وضعیت کارتابل‌ها بین تب‌ها حفظ شود.
6. **مجوزها** — ثابت‌های `OfficePerm` آماده‌اند؛ سرور خودش ۴۰۳ می‌دهد و اپ پیام فارسی نشان می‌دهد.

---

## ۶. وضعیت تست و کیفیت

```
flutter analyze lib      → ۰ خطا
flutter test             → ۱۷ تست پاس (۱۳ تست مخصوص این ماژول)
flutter build apk        → موفق
```

---

## ۷. قدم‌های بعدی پیشنهادی

- **PDF چاپ رسمی**: مسیرهای `/{id}/print` آماده‌اند؛ فقط باید `pdf`/`printing` اضافه شود
  تا سربرگ شرکت و امضاها روی موبایل رندر شوند.
- **امضای لمسی (Signature Pad)**: مسیر `POST /{id}/sign` آماده است؛ یک ویجت `CustomPainter`
  برای گرفتن امضا و ارسال به‌صورت تصویر لازم است.
- **نشان‌گذاری خودکار خوانده‌شده**: با ورود به صفحهٔ جزئیات، `POST /erja/{id}/read` صدا زده شود.
- **Push notification** برای نامهٔ جدید (از `INCOMING-*-FA.md` بک‌اند الگو بگیرید).
- **آفلاین**: کش آخرین کارتابل با `hive`/`sqflite` برای شبکهٔ ضعیف.

---

## ۸. نکتهٔ مهم برای اجرا

آدرس سرور را با `--dart-define` بدهید (پیش‌فرض `http://localhost:5100` است و روی گوشی کار نمی‌کند):

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-server:8181
```

یا از داخل اپ، بعد از ورود، آدرس سرور را تنظیم کنید (قابلیت `setBaseUrl` در `ApiClient`).
