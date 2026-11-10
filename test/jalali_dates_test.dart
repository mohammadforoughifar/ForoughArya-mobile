// ============================================================
//  تست تاریخ‌های شمسی
//  • Fa.date نباید تاریخ شمسیِ آمده از سرور را دوباره تبدیل کند
//  • JaaliOrIsoToIso باید «1404/08/20» را به ISO میلادی معادل ببرد
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/utils/fa.dart';
import 'package:forough_mobile/features/work_orders/models/work_order.dart';

void main() {
  test('تاریخ شمسیِ سرور همان‌طور شمسی نمایش داده می‌شود', () {
    expect(Fa.date('1404/08/20', time: false), '۱۴۰۴/۰۸/۲۰');
    expect(Fa.date('1404-08-20', time: false), '۱۴۰۴/۰۸/۲۰');
  });

  test('تاریخ شمسی با ساعت هم درست خوانده می‌شود', () {
    final s = Fa.date('1404/08/20 14:30');
    expect(s.contains('۱۴۰۴/۰۸/۲۰'), isTrue);
    expect(s.contains('۱۴:۳۰'), isTrue);
  });

  test('ISO میلادی مثل قبل به شمسی تبدیل می‌شود', () {
    // 2026-11-10 → 1405/08/19 (تقویم شمسی)
    final s = Fa.date('2026-11-10T10:00:00Z', time: false);
    expect(s.startsWith('۱۴'), isTrue);
    expect(s.contains('/'), isTrue);
  });

  test('تاریخ شمسی سرور به ISO میلادی نرمال می‌شود', () {
    final iso = jalaliOrIsoToIso('1404/08/20');
    expect(iso, isNotNull);
    final d = DateTime.parse(iso!);
    expect(d.year, 2025); // آبان ۱۴۰۴ = نوامبر ۲۰۲۵
    expect(d.month, 11);
    expect(d.day, 11);
  });

  test('ISO دست‌نخورده می‌ماند و مقدار خالی null می‌شود', () {
    expect(jalaliOrIsoToIso('2026-11-10T08:00:00Z'), isNotNull);
    expect(jalaliOrIsoToIso(null), isNull);
    expect(jalaliOrIsoToIso(''), isNull);
    expect(jalaliOrIsoToIso('—'), isNull);
  });

  test('دستور کار با مهلت شمسی، مهلتش را درست نشان می‌دهد', () {
    final wo = WorkOrder.fromJson({
      'id': 1,
      'number': 'WO/1404/1',
      'title': 'تست',
      'dueAt': '1404/08/20',
      'createdAt': '1404/08/18 09:15',
    });
    expect(Fa.date(wo.dueAt, time: false), '۱۴۰۴/۰۸/۲۰');
    expect(Fa.date(wo.createdAt, time: false), '۱۴۰۴/۰۸/۱۸');
  });
}
