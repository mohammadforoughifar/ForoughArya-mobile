// ============================================================
//  ورودی/نمایش عدد و مبالغ در فرم‌های عملیاتی و فروشگاهی
//  معادل Fa.FormatTyping / Fa.ParseDecimal وب (تفکیک ۳ رقم ۳ رقم)
// ============================================================

import 'package:flutter/services.dart';

import '../../../core/utils/fa.dart';

/// نرمال‌سازی ارقام فارسی/عربی به لاتین و حذف جداکننده‌های هزارگان
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

/// خواندن عدد از متن با ارقام فارسی یا جداکننده هزارگان (تهی → صفر)
double parseNum(String? v) => double.tryParse(toEnDigits(v ?? '').trim()) ?? 0;

/// قالب‌بندی زندهٔ عدد با جداکنندهٔ هزارگان ۳ رقم ۳ رقم (مثل FormatTyping وب)
String formatNumText(
  String? value, {
  bool allowDecimal = true,
  bool allowNegative = false,
}) {
  final raw = toEnDigits(value ?? '').trim();
  if (raw.isEmpty) return '';
  final isNeg = allowNegative && raw.startsWith('-');
  final unsigned = isNeg ? raw.substring(1) : raw;
  if (unsigned.isEmpty) return isNeg ? '-' : '';

  final parts = allowDecimal ? unsigned.split('.') : <String>[unsigned];
  final digits = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
  final hasDot = allowDecimal && parts.length > 1;
  final frac = hasDot ? parts.sublist(1).join().replaceAll(RegExp(r'[^0-9]'), '') : '';

  if (digits.isEmpty && !hasDot) {
    return isNeg ? '-' : '';
  }
  final intPart = digits.isEmpty ? '0' : digits;
  // گروه‌بندی ۳ رقم ۳ رقم بدون محدودیت طول عدد
  final normalizedInt = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final groupedEn = normalizedInt.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '٬',
  );
  final grouped = '${isNeg ? '-' : ''}${Fa.digits(groupedEn)}';
  if (hasDot) {
    return frac.isEmpty ? '$grouped٫' : '$grouped٫${Fa.digits(frac)}';
  }
  return grouped;
}

/// فرمت‌کنندهٔ استاندارد ۳ رقم ۳ رقم برای تمام فیلدهای مبلغ / قیمت / هزینه
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter({
    this.allowDecimal = true,
    this.allowNegative = false,
    this.minThreshold = 0,
  });

  final bool allowDecimal;
  final bool allowNegative;

  /// اگر بزرگ‌تر از صفر باشد (مثلاً ۱۰۰ برای فیلدهای ترکیبی درصد/مبلغ)،
  /// مقادیر کوچک‌تر یا مساوی آستانه بدون جداکننده می‌مانند و مبالغ بزرگ‌تر ۳ رقم ۳ رقم تفکیک می‌شوند.
  final double minThreshold;

  static bool _isSigChar(String ch) {
    if (ch == '.' || ch == '٫' || ch == '-') return true;
    final code = ch.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) || // 0-9
        (code >= 0x06F0 && code <= 0x06F9) || // ۰-۹
        (code >= 0x0660 && code <= 0x0669); // ٠-٩
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    var workingText = newValue.text;
    var workingCursor = newValue.selection.extentOffset.clamp(
      0,
      workingText.length,
    );

    // اگر کاربر Backspace را دقیقاً روی جداکنندهٔ هزارگان (٬ یا ,) زد، رقم قبل از آن حذف شود
    if (oldValue.text.length - newValue.text.length == 1 &&
        oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed) {
      final delIdx = newValue.selection.extentOffset;
      if (delIdx >= 0 && delIdx < oldValue.text.length) {
        final deleted = oldValue.text[delIdx];
        if ((deleted == '٬' || deleted == ',') && delIdx > 0) {
          workingText =
              workingText.substring(0, delIdx - 1) +
              workingText.substring(delIdx);
          workingCursor = (delIdx - 1).clamp(0, workingText.length);
        }
      }
    }

    if (minThreshold > 0) {
      final n = parseNum(workingText);
      if (n <= minThreshold) {
        return TextEditingValue(
          text: workingText,
          selection: TextSelection.collapsed(offset: workingCursor),
        );
      }
    }

    var sigBeforeCursor = 0;
    for (var i = 0; i < workingCursor; i++) {
      if (_isSigChar(workingText[i])) sigBeforeCursor++;
    }

    final formatted = formatNumText(
      workingText,
      allowDecimal: allowDecimal,
      allowNegative: allowNegative,
    );
    if (formatted.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // تنظیم دقیق مکان‌نما متناظر با تعداد ارقام قبل از مکان‌نما
    final totalInputSig = workingText
        .split('')
        .where(_isSigChar)
        .length;
    final totalFormattedSig = formatted
        .split('')
        .where(_isSigChar)
        .length;
    final adjustedSigTarget =
        (sigBeforeCursor - (totalInputSig - totalFormattedSig)).clamp(
          0,
          totalFormattedSig,
        );

    var targetOffset = 0;
    var seenSig = 0;
    while (targetOffset < formatted.length && seenSig < adjustedSigTarget) {
      if (_isSigChar(formatted[targetOffset])) {
        seenSig++;
      }
      targetOffset++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: targetOffset.clamp(0, formatted.length),
      ),
    );
  }
}

/// فرمت‌کنندهٔ آماده برای تمام تکست‌باکس‌های مبلغ و قیمت (ریال)
const List<TextInputFormatter> moneyInputFormatters = <TextInputFormatter>[
  ThousandsSeparatorInputFormatter(),
];

/// فرمت‌کنندهٔ آماده برای مبالغ علامت‌دار (مثل مانده اول دوره)
const List<TextInputFormatter> signedMoneyInputFormatters =
    <TextInputFormatter>[
      ThousandsSeparatorInputFormatter(allowNegative: true),
    ];

/// فرمت‌کنندهٔ آماده برای فیلدهای ترکیبی درصد / مبلغ ریالی (بالای ۱۰۰ → ۳ رقم ۳ رقم)
const List<TextInputFormatter> percentOrMoneyInputFormatters =
    <TextInputFormatter>[
      ThousandsSeparatorInputFormatter(minThreshold: 100),
    ];
