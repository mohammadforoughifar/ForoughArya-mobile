// ============================================================
//  قواعد یکپارچهٔ شناسه‌های فروشگاهی — آینهٔ دقیق سرور و وب:
//    Inventory.Shared/ShopIdentifierRules.cs
//    Inventory.Shared/Dtos/ShopPrintSettingsDto.cs (ShopPrintBankRules)
//
//  همهٔ فیلدها اختیاری‌اند (خالی = null)، اما اگر مقدار وارد شود باید کامل و معتبر باشد:
//    • موبایل / تلفن ثابت : دقیقاً ۱۱ رقم با صفر آغازین (پشتیبانی از +98 / 0098)
//    • کد پستی           : دقیقاً ۱۰ رقم
//    • شناسه ملی/مالیاتی  : ۱۰، ۱۱، ۱۲ یا ۱۴ رقم
//    • شماره کارت بانکی   : دقیقاً ۱۶ رقم
//    • شماره شبا          : دقیقاً ۲۴ رقم بدون IR (یا ۲۶ کاراکتر با IR)
// ============================================================

import 'fa_num.dart';

class ShopIdentifierRules {
  const ShopIdentifierRules._();

  /// نرمال‌سازی رشتهٔ ورودی: ارقام فارسی/عربی → لاتین و حذف فاصله و خط تیره
  static String? normalize(String? value) {
    if (value == null) return null;
    final cleaned = toEnDigits(value)
        .trim()
        .replaceAll(RegExp(r'[\s\-]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }

  /// نرمال‌سازی شبا: حذف پیشوند `IR` و بزرگ‌سازی حروف
  static String? normalizeIban(String? value) {
    final normalized = normalize(value)?.toUpperCase();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized.startsWith('IR') ? normalized.substring(2) : normalized;
  }

  /// نرمال‌سازی شمارهٔ تلفن/موبایل با پشتیبانی از پیش‌شمارهٔ کشور (+98 / 0098 / 98)
  static String? normalizePhone(String? value) {
    var phone = normalize(value);
    if (phone == null) return null;
    phone = phone.replaceAll(RegExp(r'[()+.]'), '');
    if (phone.startsWith('0098') && phone.length > 4) {
      phone = '0${phone.substring(4)}';
    } else if (phone.startsWith('98') && phone.length == 12) {
      phone = '0${phone.substring(2)}';
    }
    return phone.isEmpty ? null : phone;
  }

  /// فقط ارقام لاتین ۰ تا ۹ را نگه می‌دارد (برای کنترل زندهٔ ورودی‌های بانکی/عددی)
  static String digitsOnly(String? value, {int? maxLength}) {
    final raw = toEnDigits(value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (maxLength != null && raw.length > maxLength) {
      return raw.substring(0, maxLength);
    }
    return raw;
  }

  static bool isDigits(String value) =>
      value.isNotEmpty && RegExp(r'^[0-9]+$').hasMatch(value);

  /// گروه‌بندی ۴رقمی کارت یا شبا برای نمایش خوانا (مثل پیش‌نمایش چاپ در وب)
  static String groupBy4(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '';
    final chunks = <String>[];
    for (var i = 0; i < clean.length; i += 4) {
      final end = (i + 4 < clean.length) ? i + 4 : clean.length;
      chunks.add(clean.substring(i, end));
    }
    return chunks.join(' ');
  }

  /// کد پستی اختیاری است؛ در صورت ورود باید دقیقاً ۱۰ رقم باشد.
  static String? validatePostalCode(
    String? value, {
    String label = 'کد پستی',
  }) {
    final postal = normalize(value);
    if (postal == null) return null;
    return (postal.length == 10 && isDigits(postal))
        ? null
        : '$label باید دقیقاً ۱۰ رقم باشد.';
  }

  /// تلفن/موبایل اختیاری است؛ در صورت ورود باید ۳ تا ۱۵ رقم معتبر باشد
  /// (و اگر با ۰۹ شروع می‌شود دقیقاً ۱۱ رقم باشد، مطابق `ShopIdentifierRules.cs` سرور).
  static String? validatePhone(
    String? value, {
    String label = 'شماره تلفن',
  }) {
    final phone = normalizePhone(value);
    if (phone == null) return null;
    if (!isDigits(phone) || phone.length < 3 || phone.length > 15) {
      return '$label معتبر نیست.';
    }
    if (phone.startsWith('09') && phone.length != 11) {
      return '$label باید دقیقاً ۱۱ رقم با صفر آغازین باشد.';
    }
    return null;
  }

  /// شناسه ملی / اقتصادی / مالیاتی طرف حساب: ۱۰، ۱۱، ۱۲ یا ۱۴ رقم
  static String? validateTaxId(
    String? value, {
    String label = 'شناسه ملی/مالیاتی',
  }) {
    final tax = normalize(value);
    if (tax == null) return null;
    const validLengths = {10, 11, 12, 14};
    return (validLengths.contains(tax.length) && isDigits(tax))
        ? null
        : '$label باید ۱۰، ۱۱، ۱۲ یا ۱۴ رقم باشد.';
  }

  /// اعتبارسنجی یکجای اطلاعات تماس و هویتی طرف حساب
  static String? validateParty({
    String? mobile,
    String? phone,
    String? taxId,
    String? postalCode,
    bool isSupplier = false,
    bool? isCustomer,
  }) {
    final supplier = isCustomer != null ? !isCustomer : isSupplier;
    return validatePhone(mobile, label: 'شماره موبایل') ??
        validatePhone(phone, label: 'تلفن ثابت') ??
        validateTaxId(
          taxId,
          label: supplier
              ? 'شناسه ملی/اقتصادی تأمین‌کننده'
              : 'شناسه ملی خریدار',
        ) ??
        validatePostalCode(
          postalCode,
          label: supplier ? 'کد پستی تأمین‌کننده' : 'کد پستی خریدار',
        );
  }

  /// اعتبارسنجی شماره کارت (۱۶ رقم)، شماره شبا (۲۴ رقم بدون IR)، شماره حساب و کد شعبه
  static String? validateBank({
    String? cardNumber,
    String? iban,
    String? accountNumber,
    String? branchCode,
  }) {
    final card = normalize(cardNumber);
    final normIban = normalizeIban(iban);
    final acc = normalize(accountNumber);
    final branch = normalize(branchCode);
    if (card != null && (card.length != 16 || !isDigits(card))) {
      return 'شماره کارت باید دقیقاً ۱۶ رقم باشد.';
    }
    if (normIban != null && (normIban.length != 24 || !isDigits(normIban))) {
      return 'شماره شبا باید دقیقاً ۲۴ رقم بدون IR (یا ۲۶ کاراکتر با IR) باشد.';
    }
    if (acc != null &&
        (acc.length < 3 || acc.length > 30 || !isDigits(acc))) {
      return 'شماره حساب بانکی باید فقط شامل ۳ تا ۳۰ رقم باشد.';
    }
    if (branch != null && (branch.length > 10 || !isDigits(branch))) {
      return 'کد شعبه باید فقط شامل ارقام (حداکثر ۱۰ رقم) باشد.';
    }
    return null;
  }
}
