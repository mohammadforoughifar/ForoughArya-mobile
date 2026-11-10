import 'package:shamsi_date/shamsi_date.dart';

class Fa {
  static String digits(Object? value) {
    const en = '0123456789';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    return value?.toString().split('').map((c) {
          final i = en.indexOf(c);
          return i < 0 ? c : fa[i];
        }).join() ??
        '';
  }

  /// آیا رشته تاریخ شمسی است؟ (۱۴۰۴-۰۸-۱۹ یا ۱۴۰۴/۰۸/۱۹)
  static bool isJalaliString(String s) {
    final m = RegExp(r'^\s*(1[34]\d{2})[-/](\d{1,2})[-/](\d{1,2})')
        .firstMatch(s);
    if (m == null) return false;
    final y = int.tryParse(m.group(1)!) ?? 0;
    final mo = int.tryParse(m.group(2)!) ?? 0;
    final d = int.tryParse(m.group(3)!) ?? 0;
    return y >= 1300 && y <= 1500 && mo >= 1 && mo <= 12 && d >= 1 && d <= 31;
  }

  static String date(String? iso, {bool time = true}) {
    if (iso == null || iso.isEmpty) return '—';
    // اگر سرور خودش تاریخ شمسی فرستاده باشد، دوباره تبدیل نمی‌کنیم
    // (وگرنه ۱۴۰۴/۰۸/۱۹ به یک تاریخ بی‌معنی میلادی تفسیر می‌شد)
    if (isJalaliString(iso)) {
      final m = RegExp(r'^\s*(\d{4})[-/](\d{1,2})[-/](\d{1,2})(.*)$')
          .firstMatch(iso);
      if (m != null) {
        final base =
            '${digits(m.group(1))}/${digits(m.group(2)!.padLeft(2, '0'))}/${digits(m.group(3)!.padLeft(2, '0'))}';
        final clock = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(m.group(4) ?? '');
        if (time && clock != null) {
          return '$base  ${digits(clock.group(1)!.padLeft(2, '0'))}:${digits(clock.group(2)!)}';
        }
        return base;
      }
    }
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '—';
    final j = Jalali.fromDateTime(d);
    final result =
        '${digits(j.year)}/${digits(j.month.toString().padLeft(2, '0'))}/${digits(j.day.toString().padLeft(2, '0'))}';
    return time
        ? '$result  ${digits(d.hour.toString().padLeft(2, '0'))}:${digits(d.minute.toString().padLeft(2, '0'))}'
        : result;
  }

  static String priority(int p) => switch (p) {
    0 => 'کم',
    2 => 'بالا',
    3 => 'فوری',
    _ => 'عادی',
  };
  static String recurrence(int r) => switch (r) {
    1 => 'روزانه',
    2 => 'هفتگی',
    3 => 'ماهانه',
    _ => 'بدون تکرار',
  };
  /// خواندن عدد از مقدارهای ناهمگون پاسخ سرور (عدد، رشته، null)
  static int? digitInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  /// عدد با جداکنندهٔ هزارگان فارسی — مثل «۱٬۲۴۰٬۰۰۰» یا «۳٫۵»
  static String number(num value, {int decimals = 0}) {
    final s = value.toStringAsFixed(decimals);
    final dot = s.indexOf('.');
    final intPart = dot < 0 ? s : s.substring(0, dot);
    final frac = dot < 0 ? '' : s.substring(dot + 1);
    final grouped = intPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '٬',
    );
    return digits(frac.isEmpty ? grouped : '$grouped٫$frac');
  }

  static String bytes(int n) => n < 1024
      ? '${digits(n)} بایت'
      : n < 1048576
      ? '${digits((n / 1024).toStringAsFixed(1))} KB'
      : '${digits((n / 1048576).toStringAsFixed(1))} MB';
}
