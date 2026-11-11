// ============================================================
//  ورودی/نمایش عدد در فرم‌های فروشگاهی
//  معادل Fa.FormatTyping / Fa.ParseDecimal وب
// ============================================================

import '../../../core/utils/fa.dart';

/// نرمال‌سازی ارقام فارسی/عربی به لاتین
String toEnDigits(String input) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final sb = StringBuffer();
  for (final ch in input.split('')) {
    final i = fa.indexOf(ch);
    final j = ar.indexOf(ch);
    if (i >= 0) {
      sb.write(i);
    } else if (j >= 0) {
      sb.write(j);
    } else if (ch == '٫') {
      sb.write('.');
    } else if (ch == '٬' || ch == ',') {
      // جداکنندهٔ هزارگان حذف می‌شود
    } else {
      sb.write(ch);
    }
  }
  return sb.toString();
}

/// خواندن عدد از متن با ارقام فارسی (تهی → صفر)
double parseNum(String? v) => double.tryParse(toEnDigits(v ?? '').trim()) ?? 0;

/// قالب‌بندی زندهٔ عدد با جداکنندهٔ هزارگان (مثل FormatNum وب)
String formatNumText(String? value) {
  final raw = toEnDigits(value ?? '');
  if (raw.trim().isEmpty) return '';
  final parts = raw.split('.');
  final digits = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
  final intPart = digits.isEmpty ? '0' : digits;
  final grouped = Fa.number((num.tryParse(intPart) ?? 0).toInt());
  if (parts.length > 1) {
    final frac = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
    return frac.isEmpty ? grouped : '$grouped٫${Fa.digits(frac)}';
  }
  return grouped;
}
