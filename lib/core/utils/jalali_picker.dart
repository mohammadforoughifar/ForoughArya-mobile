// ============================================================
//  ابزارهای تاریخ شمسی مشترک همهٔ ماژول‌ها
//  • انتخابگر تاریخ شمسی (تک‌تاریخ)
//  • انتخابگر بازهٔ تاریخ شمسی (برای فیلترهای تاریخ)
//  • قالب‌بندی شمسی کوتاه/بلند با اعداد فارسی
//  هیچ‌جای اپ نباید تقویم میلادی نشان داده شود.
// ============================================================

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'fa.dart';

const List<String> _months = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

/// نام ماه شمسی (۱..۱۲)
String jalaliMonthName(int month) =>
    month >= 1 && month <= 12 ? _months[month - 1] : '—';

/// ۱۴۰۴/۰۸/۱۹ — با اعداد فارسی
String jalaliShort(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return Fa.digits(
    '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}',
  );
}

/// ۱۹ آبان ۱۴۰۴
String jalaliLong(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return '${Fa.digits(j.day)} ${_months[j.month - 1]} ${Fa.digits(j.year)}';
}

/// ۱۹ آبان ۱۴۰۴ - ۲۱ آبان ۱۴۰۴
String jalaliRangeLabel(DateTime? from, DateTime? to) {
  if (from == null && to == null) return 'همهٔ تاریخ‌ها';
  if (from != null && to != null) {
    return '${jalaliShort(from)} تا ${jalaliShort(to)}';
  }
  return from != null ? 'از ${jalaliShort(from)}' : 'تا ${jalaliShort(to!)}';
}

/// انتخاب یک تاریخ شمسی. مقدار بازگشتی یک [DateTime] میلادی است تا برای
/// ارسال به سرور آماده باشد، ولی چیزی که کاربر می‌بیند کاملاً شمسی است.
Future<DateTime?> showJalaliDatePicker(
  BuildContext context, {
  DateTime? initial,
  String title = 'انتخاب تاریخ',
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final initJ = Jalali.fromDateTime(initial ?? DateTime.now());
  int year = initJ.year;
  int month = initJ.month;
  int day = initJ.day;

  final minJ = Jalali.fromDateTime(firstDate ?? DateTime(2000));
  final maxJ = Jalali.fromDateTime(lastDate ?? DateTime(2100));

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setS) {
          final monthLen = Jalali(year, month, 1).monthLength;
          if (day > monthLen) day = monthLen;
          final years = [
            for (var y = minJ.year; y <= maxJ.year; y++) y,
          ];
          if (!years.contains(year)) {
            years.add(year);
            years.sort();
          }
          return AlertDialog(
            title: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: year,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'سال',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final y in years)
                            DropdownMenuItem(
                              value: y,
                              child: Text(Fa.digits(y)),
                            ),
                        ],
                        onChanged: (v) => setS(() => year = v ?? year),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        initialValue: month,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'ماه',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (var m = 1; m <= 12; m++)
                            DropdownMenuItem(
                              value: m,
                              child: Text(_months[m - 1]),
                            ),
                        ],
                        onChanged: (v) => setS(() => month = v ?? month),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 84,
                      child: DropdownButtonFormField<int>(
                        initialValue: day,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'روز',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (var d = 1; d <= monthLen; d++)
                            DropdownMenuItem(
                              value: d,
                              child: Text(Fa.digits(d)),
                            ),
                        ],
                        onChanged: (v) => setS(() => day = v ?? day),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xfff4f7fb),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${Fa.digits(day)} ${_months[month - 1]} ${Fa.digits(year)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () {
                  final j = Jalali(year, month, day);
                  Navigator.pop(ctx, j.toDateTime());
                },
                child: const Text('تأیید'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// نتیجهٔ بازهٔ تاریخ (میلادی برای ارسال به سرور)
typedef JalaliRange = ({DateTime start, DateTime end});

/// انتخاب بازهٔ تاریخ شمسی — جایگزین showDateRangePicker میلادی
Future<JalaliRange?> showJalaliDateRangePicker(
  BuildContext context, {
  DateTime? initialStart,
  DateTime? initialEnd,
  String title = 'بازهٔ تاریخ',
}) async {
  var start = initialStart;
  var end = initialEnd;

  return showDialog<JalaliRange>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pick(bool isStart) async {
            final picked = await showJalaliDatePicker(
              ctx,
              initial: isStart ? start : end,
              title: isStart ? 'از تاریخ' : 'تا تاریخ',
            );
            if (picked == null) return;
            setS(() {
              if (isStart) {
                start = picked;
                if (end != null && end!.isBefore(picked)) end = picked;
              } else {
                end = picked;
                if (start != null && start!.isAfter(picked)) start = picked;
              }
            });
          }

          Widget tile({
            required String label,
            required DateTime? value,
            required VoidCallback onTap,
          }) => InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffe4eaf3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    value == null ? 'انتخاب کنید' : jalaliShort(value),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: value == null
                          ? const Color(0xff94a3b8)
                          : const Color(0xff2547a8),
                    ),
                  ),
                ],
              ),
            ),
          );

          return AlertDialog(
            title: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tile(
                  label: 'از تاریخ',
                  value: start,
                  onTap: () => pick(true),
                ),
                const SizedBox(height: 8),
                tile(label: 'تا تاریخ', value: end, onTap: () => pick(false)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _quick('امروز', () {
                      final now = DateTime.now();
                      final d = DateTime(now.year, now.month, now.day);
                      return (start: d, end: now);
                    }, setS, (v) {
                      start = v.start;
                      end = v.end;
                    }),
                    _quick('۷ روز اخیر', () {
                      final now = DateTime.now();
                      return (
                        start: DateTime(now.year, now.month, now.day)
                            .subtract(const Duration(days: 7)),
                        end: now,
                      );
                    }, setS, (v) {
                      start = v.start;
                      end = v.end;
                    }),
                    _quick('۳۰ روز اخیر', () {
                      final now = DateTime.now();
                      return (
                        start: DateTime(now.year, now.month, now.day)
                            .subtract(const Duration(days: 30)),
                        end: now,
                      );
                    }, setS, (v) {
                      start = v.start;
                      end = v.end;
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  jalaliRangeLabel(start, end),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('انصراف'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('پاک‌کردن'),
              ),
              FilledButton(
                onPressed: start == null || end == null
                    ? null
                    : () => Navigator.pop(ctx, (start: start!, end: end!)),
                child: const Text('اعمال'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Widget _quick(
  String label,
  JalaliRange Function() make,
  StateSetter setS,
  void Function(JalaliRange) assign,
) => ActionChip(
  label: Text(label, style: const TextStyle(fontSize: 11.5)),
  onPressed: () => setS(() => assign(make())),
);
