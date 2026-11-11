// آزمون نمایش ساعت در پیام‌رسان — عیناً مثل `FormatTime` وب:
// امروز → ساعت، دیروز → «دیروز»، قبل‌تر → تاریخ شمسی.
// همچنین ساعتی که سرور بدون پسوند منطقه می‌فرستد نباید جابه‌جا شود.

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/utils/fa.dart';

void main() {
  group('Fa.parseServerDate', () {
    test('مقدار UTC با Z درست خوانده می‌شود', () {
      final d = Fa.parseServerDate('2026-11-10T08:30:00Z');
      expect(d, isNotNull);
      expect(d!.toUtc().hour, 8);
      expect(d.toUtc().minute, 30);
    });

    test('مقدار بدون پسوند منطقه به‌عنوان UTC خوانده می‌شود (نه ساعت محلی)', () {
      final d = Fa.parseServerDate('2026-11-10T08:30:00');
      expect(d!.toUtc().hour, 8);
      expect(d!.toUtc().minute, 30);
    });

    test('پسوند ئی‌اس‌پی با فاصله هم پشتیبانی می‌شود', () {
      final a = Fa.parseServerDate('2026-11-10T08:30:00Z');
      final b = Fa.parseServerDate('2026-11-10 08:30:00');
      expect(a!.toUtc(), b!.toUtc());
    });

    test('مقدار خالی و نامعتبر نال برمی‌گرداند', () {
      expect(Fa.parseServerDate(null), isNull);
      expect(Fa.parseServerDate(''), isNull);
      expect(Fa.parseServerDate('null'), isNull);
      expect(Fa.parseServerDate('۱۴۰۴/۰۸/۱۹'), isNull);
    });
  });

  group('Fa.chatTime', () {
    final now = DateTime(2026, 11, 10, 15, 0);

    test('پیام امروز فقط ساعت را نشان می‌دهد', () {
      final at = DateTime(2026, 11, 10, 9, 5);
      expect(Fa.chatTime(at, now: now), '۰۹:۰۵');
    });

    test('پیام دیروز «دیروز» است', () {
      expect(Fa.chatTime(DateTime(2026, 11, 9, 23, 50), now: now), 'دیروز');
    });

    test('پیام قدیمی‌تر تاریخ شمسی است', () {
      final t = Fa.chatTime(DateTime(2026, 11, 2, 10, 0), now: now);
      expect(t, '۱۴۰۵/۰۸/۱۱');
    });

    test('تاریخ نال رشتهٔ خالی می‌دهد', () {
      expect(Fa.chatTime(null, now: now), '');
    });
  });
}
