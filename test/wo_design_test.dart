// ============================================================
//  تست رندر ویجت‌های طراحی جدید دستور کار
//  تضمین می‌کند کارت، تب کشویی و بلوک‌های صفحهٔ جزئیات بدون
//  خطای رندر (ErrorWidget خاکستری) ساخته می‌شوند.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forough_mobile/features/work_orders/models/work_order.dart';
import 'package:forough_mobile/features/work_orders/presentation/wo_style.dart';

WorkOrder _order({
  bool open = true,
  String due = '2026-11-20T10:00:00',
  int priority = 2,
  int checklistTotal = 4,
  int checklistDone = 1,
}) => WorkOrder.fromJson({
  'id': 1,
  'number': '1405/د-12',
  'title': 'بازبینی قرارداد توسعه نرم‌افزار',
  'description': 'بررسی بندهای مالی و حقوقی قرارداد و ارسال نظر کارشناسی.',
  'ownerUserId': 1,
  'ownerName': 'محمد فروغی',
  'dueAt': due,
  'status': open ? 'Open' : 'Closed',
  'priority': priority,
  'recurrence': 0,
  'weight': 1,
  'checklistTotal': checklistTotal,
  'checklistDone': checklistDone,
  'attachmentCount': 2,
  'commentCount': 3,
  'tags': ['قرارداد', 'مالی'],
  'assignees': [
    {'id': 1, 'userId': 7, 'name': 'علی رضایی', 'seenAt': '2026-11-01T10:00:00'},
    {'id': 2, 'userId': 8, 'name': 'مریم احمدی'},
  ],
});

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('fa'),
  supportedLocales: const [Locale('fa'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(useMaterial3: true),
  builder: (context, c) => Directionality(
    textDirection: TextDirection.rtl,
    child: c ?? const SizedBox.shrink(),
  ),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('کارت دستور کار بدون خطا رندر می‌شود', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ListView(
          children: [
            GlowWorkOrderCard(order: _order(), index: 0, onTap: () {}),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('بازبینی قرارداد'), findsOneWidget);
    expect(find.textContaining('۱۴۰۵/د-۱۲'), findsOneWidget,
        reason: 'شمارهٔ دستور با ارقام فارسی نمایش داده می‌شود');
  });

  testWidgets('کارت دیرکرد با هالهٔ قرمز رندر می‌شود', (tester) async {
    final overdue = _order(due: '2020-01-01T10:00:00');
    expect(overdue.isOverdue, isTrue);
    await tester.pumpWidget(
      _wrap(
        ListView(
          children: [GlowWorkOrderCard(order: overdue, onTap: () {})],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.text('دیرکرد'), findsOneWidget);
  });

  testWidgets('تب کشویی با بج شمارنده کار می‌کند', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) => SlidingTabs(
            showCounts: true,
            counts: const {'a': 5, 'b': 2},
            items: const [
              (label: 'اول', icon: Icons.inbox_outlined, key: 'a'),
              (label: 'دوم', icon: Icons.archive_outlined, key: 'b'),
            ],
            index: selected,
            onChanged: (i) => setState(() => selected = i),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('اول'), findsOneWidget);
    expect(find.text('۵'), findsOneWidget);

    await tester.tap(find.text('دوم'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('هدر گرادیانی و بلوک‌های جزئیات رندر می‌شوند', (tester) async {
    final o = _order();
    await tester.pumpWidget(
      _wrap(
        ListView(
          children: [
            DetailHero(
              order: o,
              child: Text(o.title, style: const TextStyle(color: Colors.white)),
            ),
            GlassCard(
              title: 'مشخصات',
              icon: Icons.badge_outlined,
              children: [
                InfoTile(
                  icon: Icons.person_outline,
                  label: 'دستوردهنده',
                  value: o.ownerName,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                RingStat(value: .25, label: 'چک‌لیست', color: WoColors.open),
                RingStat(value: 1, label: 'گفتگو', color: WoColors.seed),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.text('مشخصات'), findsOneWidget);
    expect(find.text('محمد فروغی'), findsOneWidget);
  });

  testWidgets('اسکلت بارگذاری بدون خطا ساخته می‌شود', (tester) async {
    await tester.pumpWidget(_wrap(const ShimmerList(count: 3)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  test('رنگ و گرادیان هر وضعیت متفاوت است', () {
    final open = _order();
    final overdue = _order(due: '2020-01-01T10:00:00');
    final urgent = _order(priority: 3);
    final closed = _order(open: false);
    expect(WoColors.forOrder(open), WoColors.open);
    expect(WoColors.forOrder(overdue), WoColors.overdue);
    expect(WoColors.forOrder(urgent), WoColors.urgent);
    expect(WoColors.forOrder(closed), WoColors.closed);
  });
}
