// ============================================================
//  تست‌های رندر زبان طراحی اتوماسیون اداری
//  تضمین می‌کند هیچ ویجتی به ErrorWidget خاکستری تبدیل نشود
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/office_automation/data/office_repository.dart'
    show LetterKind;
import 'package:forough_mobile/features/office_automation/models/letter_models.dart';
import 'package:forough_mobile/features/office_automation/presentation/office_style.dart';

LetterListItem _item({
  bool unread = true,
  String foriat = 'عادی',
  String mahramanegi = 'عادی',
  DateTime? deadline,
  bool neshan = false,
  bool attachment = false,
  String? matnErja,
  int typeTaeed = 0,
}) => LetterListItem(
  letterId: 12,
  title: 'بازبینی قرارداد توسعه نرم‌افزار',
  letterNumber: '1405/284',
  sender: 'محمد فروغی',
  receiver: 'واحد حقوقی',
  date: DateTime(2026, 10, 12),
  mahramanegi: mahramanegi,
  foriat: foriat,
  deadline: deadline,
  isNeshan: neshan,
  hasAttachment: attachment,
  isRead: !unread,
  receiverCount: 3,
  typeTaeed: typeTaeed,
  matnErja: matnErja,
);

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('fa'),
  home: Scaffold(
    body: Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(child: child),
    ),
  ),
);

void main() {
  testWidgets('کارت نامه بدون خطای رندر با بج‌ها و شمارهٔ فارسی', (tester) async {
    await tester.pumpWidget(
      _wrap(
        GlowLetterCard(
          item: _item(
            foriat: 'فوری',
            mahramanegi: 'محرمانه',
            attachment: true,
            neshan: true,
            matnErja: 'بررسی و اعلام نظر تا پایان هفته',
          ),
          kind: LetterKind.inner,
          onTap: () {},
          onNeshan: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.text('بازبینی قرارداد توسعه نرم‌افزار'), findsOneWidget);
    // ارقام باید فارسی‌شده باشند
    expect(find.textContaining('۱۴۰۵/۲۸۴'), findsOneWidget);
    expect(find.text('فوری'), findsOneWidget);
    expect(find.text('محرمانه'), findsOneWidget);
    expect(find.text('پیوست'), findsOneWidget);
  });

  testWidgets('کارت با مهلت گذشته برچسب دیرکرد می‌گیرد', (tester) async {
    await tester.pumpWidget(
      _wrap(
        GlowLetterCard(
          item: _item(deadline: DateTime(2020, 1, 1)),
          kind: LetterKind.outgoing,
          onTap: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('دیرکرد'), findsOneWidget);
  });

  testWidgets('تب کشویی با شمارنده رندر و تپ می‌شود', (tester) async {
    var index = 0;
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) => OfficeSlidingTabs(
            items: const [
              (label: 'داخلی', icon: Icons.edit_note, key: 'in'),
              (label: 'صادره', icon: Icons.north_east, key: 'out'),
              (label: 'وارده', icon: Icons.south_west, key: 'inc'),
            ],
            index: index,
            onChanged: (i) => setState(() => index = i),
            showCounts: true,
            counts: const {'in': 12, 'out': 5},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('داخلی'), findsOneWidget);
    expect(find.text('۱۲'), findsOneWidget); // شمارندهٔ فارسی‌شده

    await tester.tap(find.text('صادره'));
    await tester.pumpAndSettle();
    expect(index, 1);
  });

  testWidgets('کارت بخش، ردیف اطلاعات و حلقهٔ آمار رندر می‌شوند', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            OfficeCard(
              title: 'مشخصات نامه',
              icon: Icons.badge_outlined,
              children: const [
                OfficeInfoTile(
                  icon: Icons.person_outline,
                  label: 'فرستنده',
                  value: 'محمد فروغی',
                ),
              ],
            ),
            OfficeRing(value: .65, label: 'خوانده‌شده', color: OfficeColors.seed),
            const MiniStat(icon: Icons.attach_file, value: '۲', label: 'پیوست'),
            const HeroBadge(label: 'شماره ۱۴۰۵/۲۸۴', icon: Icons.tag),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1000));

    expect(tester.takeException(), isNull);
    expect(find.text('مشخصات نامه'), findsOneWidget);
    expect(find.text('محمد فروغی'), findsOneWidget);
    expect(find.text('۶۵٪'), findsOneWidget);
  });

  testWidgets('اسکلت بارگذاری و انیمیشن ورود رندر می‌شوند', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            const SizedBox(height: 400, child: OfficeShimmer(count: 2)),
            const OFadeSlideIn(
              index: 1,
              child: Text('آیتم انیمیشنی'),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    expect(find.text('آیتم انیمیشنی'), findsOneWidget);
  });

  testWidgets('رنگ نوع نامه و وضعیت درست انتخاب می‌شود', (tester) async {
    expect(OfficeColors.forKind(LetterKind.inner), OfficeColors.inner);
    expect(OfficeColors.forKind(LetterKind.outgoing), OfficeColors.outgoing);
    expect(OfficeColors.forKind(LetterKind.incoming), OfficeColors.incoming);
    expect(OfficeColors.forKind(null), OfficeColors.inner);

    // نامهٔ دیرکرد باید رنگ خطر بگیرد
    expect(
      OfficeColors.forItem(_item(deadline: DateTime(2020, 1, 1))),
      OfficeColors.danger,
    );
    // خوانده‌نشده رنگ اصلی
    expect(OfficeColors.forItem(_item()), OfficeColors.seed);
  });
}
