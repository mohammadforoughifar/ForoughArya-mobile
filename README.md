# ForoughArya Mobile (فروغ آریا)

کلاینت Flutter سامانهٔ سازمانی فروغ آریا (Android / iOS / Web PWA).

## ساخت نسخهٔ کم‌حجم (Release)

اسکریپت آماده برای ساخت کوچک‌ترین خروجی ممکن (حذف آیکن‌های بی‌استفاده، جداسازی جدول سمبل‌های دیباگ، مبهم‌سازی و تفکیک معماری):

```bash
# لینوکس / سرور / مک:
bash scripts/build-slim.sh

# ویندوز (PowerShell):
powershell -ExecutionPolicy Bypass -File scripts/build-slim.ps1
```

جزئیات کامل بهینه‌سازی‌های حجم در فایل [`SIZE-REDUCTION-FA.md`](SIZE-REDUCTION-FA.md) مستند شده است.
