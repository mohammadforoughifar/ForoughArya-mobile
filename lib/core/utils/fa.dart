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

  static String date(String? iso, {bool time = true}) {
    if (iso == null || iso.isEmpty) return '—';
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
