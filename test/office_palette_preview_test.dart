// پیش‌نمایش بصری پالت «نفتی کلاسیک و طلا» برای تأیید نهایی کاربر
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/office_automation/data/office_repository.dart'
    show LetterKind;
import 'package:forough_mobile/features/office_automation/models/letter_models.dart';
import 'package:forough_mobile/features/office_automation/presentation/office_style.dart';

LetterListItem _item({
  bool unread = true,
  String foriat = 'عادی',
  DateTime? deadline,
  bool neshan = false,
}) => LetterListItem(
  letterId: 12,
  title: 'بازبینی قرارداد توسعه نرم‌افزار و الحاقیهٔ الحاقیهٔ مالی',
  letterNumber: '1405/284',
  sender: 'محمد فروغی‌فر',
  receiver: 'واحد حقوقی و قراردادها',
  date: DateTime(2026, 10, 12),
  mahramanegi: 'عادی',
  foriat: foriat,
  deadline: deadline,
  isNeshan: neshan,
  hasAttachment: true,
  isRead: !unread,
  receiverCount: 3,
  typeTaeed: 0,
);

void main() {
  setUpAll(() async {
    final vazir = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn.ttf'));
    await vazir.load();
  });

  testWidgets('render palette preview', (tester) async {
    tester.view.physicalSize = const Size(880, 1600);
    tester.view.devicePixelRatio = 1.4;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Vazirmatn'),
        home: Scaffold(
          backgroundColor: OfficeColors.bg,
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // هدر سازمانی روشن — سفید با خط طلای سوزنی
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xffffffff), Color(0xffeef4f2)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
                      border: Border(
                        bottom: BorderSide(color: Color(0xff8a6a24), width: 1.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1a0f414b),
                          blurRadius: 22,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xff155e6b), Color(0xff0f414b)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: const [
                              BoxShadow(color: Color(0x55155e6b), blurRadius: 12, offset: Offset(0, 5)),
                            ],
                          ),
                          child: const Icon(Icons.space_dashboard_rounded, color: Colors.white, size: 23),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('اتوماسیون اداری توکا', style: TextStyle(color: Color(0xff0f414b), fontSize: 17, fontWeight: FontWeight.w900)),
                              SizedBox(height: 4),
                              Text('سازمانی روشن + طلای سوزنی', style: TextStyle(color: Color(0xff8a6a24), fontSize: 11, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlowLetterCard(item: _item(foriat: 'فوری'), kind: LetterKind.inner, onTap: () {}),
                  GlowLetterCard(item: _item(unread: false), kind: LetterKind.outgoing, onTap: () {}),
                  GlowLetterCard(item: _item(unread: false, deadline: DateTime(2020, 1, 1)), kind: LetterKind.incoming, onTap: () {}),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in [
                        (OfficeColors.seed, 'نفتی اصلی'),
                        (OfficeColors.deep, 'نفتی عمیق'),
                        (OfficeColors.outgoing, 'صادره'),
                        (OfficeColors.incoming, 'وارده'),
                        (OfficeColors.signing, 'امضا'),
                        (OfficeColors.dabirkhane, 'دبیرخانه'),
                        (OfficeColors.gold, 'طلای سوزنی'),
                        (OfficeColors.danger, 'آجری هشدار'),
                      ])
                        Container(
                          width: 96,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: c.$1,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(c.$2, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/office_palette_preview.png'),
    );
  });
}
