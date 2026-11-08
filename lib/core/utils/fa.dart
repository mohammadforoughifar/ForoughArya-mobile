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
  static String bytes(int n) => n < 1024
      ? '${digits(n)} بایت'
      : n < 1048576
      ? '${digits((n / 1024).toStringAsFixed(1))} KB'
      : '${digits((n / 1048576).toStringAsFixed(1))} MB';
}
