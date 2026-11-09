// ============================================================
//  تست ماژول پست الکترونیک (ایمیل سازمانی و شخصی)
//  نگاشت DTOهای سرور، متن HTML، پاسخ/ارجاع، کارت ایمیل و
//  رندر کامل صفحه با چهار کارتابل — بدون نیاز به سرور.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:forough_mobile/core/auth/auth_controller.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/core/utils/fa.dart';
import 'package:forough_mobile/features/office_automation/data/email_draft_store.dart';
import 'package:forough_mobile/features/office_automation/data/email_repository.dart';
import 'package:forough_mobile/features/office_automation/models/email_models.dart';
import 'package:forough_mobile/features/office_automation/presentation/email_page.dart';
import 'package:forough_mobile/features/office_automation/presentation/email_widgets.dart';
import 'package:forough_mobile/features/office_automation/presentation/office_style.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('fa', 'IR'),
  supportedLocales: const [Locale('fa', 'IR')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

void main() {
  // ------------------------------------------------------------
  //  نگاشت دادهٔ سرور (EmailDtos.cs)
  // ------------------------------------------------------------

  group('نگاشت حساب ایمیل', () {
    test('EmailAccountDto → EmailAccount', () {
      final a = EmailAccount.fromJson({
        'emailId': 12,
        'emailAddress': 'office@forough.example',
        'displayName': 'دبیرخانه',
        'isDabirkhane': true,
        'isActive': true,
        'messageCount': 240,
        'lastSync': '2026-10-30T09:15:00',
        'smtp': 'mail.forough.example',
        'smtpPort': 587,
        'imap': 'mail.forough.example',
        'imapPort': 993,
      });
      expect(a.id, 12);
      expect(a.title, 'دبیرخانه');
      expect(a.isDabirkhane, isTrue);
      expect(a.messageCount, 240);
      expect(a.lastSync, isNotNull);
      expect(a.imapPort, 993);
    });

    test('بدون نام نمایشی، آدرس عنوان می‌شود', () {
      final a = EmailAccount.fromJson({'emailId': 3, 'emailAddress': 'me@x.com'});
      expect(a.title, 'me@x.com');
      expect(a.isDabirkhane, isFalse);
      expect(a.smtpPort, 587);
      expect(a.imapPort, 993);
    });
  });

  group('نگاشت فهرست ایمیل', () {
    test('EmailListPageDto → EmailListResult با شمارنده‌ها', () {
      final page = EmailListResult.fromJson({
        'items': [
          {
            'id': 5,
            'box': 'Inbox',
            'emailId': 12,
            'accountAddress': 'office@forough.example',
            'fromOrTo': 'شرکت الف <a@b.com>',
            'subject': 'پیش‌فاکتور',
            'date': '2026-10-31T08:00:00',
            'isRead': false,
            'isNeshan': true,
            'isAttachment': true,
            'isInFolder': 4,
            'folderTitle': 'مالی',
          },
        ],
        'totalCount': 130,
        'unreadCount': 7,
        'spamCount': 2,
        'page': 1,
        'pageSize': 25,
      });
      expect(page.items, hasLength(1));
      expect(page.totalCount, 130);
      expect(page.unreadCount, 7);
      expect(page.spamCount, 2);
      expect(page.hasNext, isTrue);

      final m = page.items.first;
      expect(m.box, EmailBox.inbox);
      expect(m.hasAttachment, isTrue);
      expect(m.isArchived, isTrue);
      expect(m.folderTitle, 'مالی');
      expect(m.isNeshan, isTrue);
      expect(m.isRead, isFalse);
    });

    test('پاسخ آرایه‌ای ساده هم خوانده می‌شود', () {
      final page = EmailListResult.fromJson([
        {'id': 1, 'subject': 'سلام'},
      ]);
      expect(page.items, hasLength(1));
      expect(page.totalCount, 1);
      expect(page.hasNext, isFalse);
    });
  });

  group('جزئیات و پیوست', () {
    test('EmailMessageDetailDto → مدل با پیوست‌ها', () {
      final d = EmailMessageDetail.fromJson({
        'id': 9,
        'box': 'Inbox',
        'emailId': 12,
        'accountAddress': 'office@forough.example',
        'fromOrTo': 'مالی <finance@b.com>',
        'subject': 'Re: گزارش',
        'body': '<p>سلام<br>خط دوم</p>',
        'date': '2026-10-31T10:30:00',
        'attachments': [
          {'attachmentId': 77, 'realName': 'gozaresh.pdf', 'size': 2048},
        ],
      });
      expect(d.replyAddress, 'finance@b.com');
      expect(d.attachments, hasLength(1));
      expect(d.attachments.first.name, 'gozaresh.pdf');
      expect(d.attachments.first.sizeLabel, contains('کیلوبایت'));
      expect(d.plainBody, contains('سلام'));
      expect(d.plainBody, contains('خط دوم'));
      expect(d.plainBody, isNot(contains('<p>')));
    });
  });

  // ------------------------------------------------------------
  //  متن ایمیل
  // ------------------------------------------------------------

  group('متن ایمیل', () {
    test('HTML → متن خوانا', () {
      const html =
          '<html><head><style>p{color:red}</style></head><body>'
          '<p>بند اول</p><p>بند دوم&nbsp;با&zwnj;نیم‌فاصله</p>'
          '<ul><li>مورد الف</li></ul><table><tr><td>سلول</td></tr></table>'
          '</body></html>';
      final text = htmlToPlain(html);
      expect(text, contains('بند اول'));
      expect(text, contains('بند دوم'));
      expect(text, contains('• مورد الف'));
      expect(text, contains('سلول'));
      expect(text, isNot(contains('color:red')));
      expect(text, isNot(contains('<td>')));
    });

    test('موجودیت‌های عددی و متنی', () {
      expect(htmlToPlain('&#1587;لام'), 'سلام');
      expect(htmlToPlain('a &amp; b &lt;c&gt;'), 'a & b <c>');
      expect(htmlToPlain(''), '');
    });

    test('استخراج آدرس از نام و آدرس', () {
      expect(extractAddress('علی رضایی <ali@test.ir>'), 'ali@test.ir');
      expect(extractAddress('info@test.ir'), 'info@test.ir');
      expect(extractAddress(''), '');
    });

    test('پاسخ: موضوع Re و نقل‌قول', () {
      expect(replySubject('گزارش ماهانه'), 'Re: گزارش ماهانه');
      expect(replySubject('Re: گزارش ماهانه'), 'Re: گزارش ماهانه');
      final d = EmailMessageDetail.fromJson({
        'id': 1,
        'box': 'Inbox',
        'fromOrTo': 'a@b.com',
        'subject': 'x',
        'body': 'خط یک\nخط دو',
      });
      final q = quotedBody(d);
      expect(q, contains('a@b.com نوشت'));
      expect(q, contains('> خط یک'));
      expect(q, contains('> خط دو'));
    });
  });

  group('پیش‌نویس محلی', () {
    test('رفت‌وبرگشت JSON', () {
      final d = EmailDraft(
        localId: 'u-1',
        accountId: 12,
        to: 'a@b.com',
        cc: 'c@d.com',
        subject: 'پیش‌نویس',
        body: 'متن',
        createdAt: DateTime(2026, 10, 30, 12),
      );
      final back = EmailDraft.fromJson(d.toJson());
      expect(back.localId, 'u-1');
      expect(back.accountId, 12);
      expect(back.cc, 'c@d.com');
      expect(back.createdAt?.hour, 12);
    });
  });

  group('دامنهٔ حساب', () {
    test('برچسب و رنگ سازمانی/شخصی جدا هستند', () {
      expect(EmailScope.corporate.label, 'سازمانی');
      expect(EmailScope.personal.label, 'شخصی');
      expect(EmailScope.corporate.color, OfficeColors.email);
      expect(EmailScope.personal.color, OfficeColors.emailPersonal);
      expect(EmailScope.corporate.isPersonal, isFalse);
      expect(EmailScope.personal.isPersonal, isTrue);
    });
  });

  group('کارتابل‌ها', () {
    test('چهار کارتابل با برچسب و آیکون', () {
      expect(
        [EmailTab.inbox, EmailTab.sent, EmailTab.archive, EmailTab.draft]
            .map((t) => t.label),
        ['دریافتی', 'ارسالی', 'بایگانی', 'پیش‌نویس'],
      );
      for (final t in EmailTab.values) {
        expect(emailTabIcon(t), isNotNull);
        expect(emailTabColor(t), isNotNull);
      }
    });

    test('برچسب حساب سازمانی/شخصی', () {
      final corporate = EmailAccount.fromJson({
        'emailId': 1,
        'emailAddress': 'a@b.com',
        'isDabirkhane': true,
      });
      final personal = EmailAccount.fromJson({'emailId': 2, 'emailAddress': 'c@d.com'});
      expect(emailScopeLabel(corporate), 'سازمانی');
      expect(emailScopeLabel(personal), 'شخصی');
    });
  });

  // ------------------------------------------------------------
  //  رندر کارت ایمیل
  // ------------------------------------------------------------

  group('رندر کارت ایمیل', () {
    EmailMessage sample({
      bool isRead = false,
      bool isNeshan = false,
      bool hasAttachment = false,
      String subject = 'پیش‌فاکتور شمارهٔ ۱۲۳',
      String box = EmailBox.inbox,
    }) => EmailMessage(
      id: 1,
      box: box,
      accountId: 12,
      accountAddress: 'office@forough.example',
      fromOrTo: 'مالی شرکت الف',
      subject: subject,
      date: DateTime(2026, 10, 31, 9, 30),
      isRead: isRead,
      isNeshan: isNeshan,
      hasAttachment: hasAttachment,
    );

    testWidgets('کارت دریافتی: موضوع، فرستنده، آدرس حساب و تاریخ', (tester) async {
      await tester.pumpWidget(_wrap(EmailCard(message: sample(), tab: EmailTab.inbox)));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('پیش‌فاکتور شمارهٔ ۱۲۳'), findsOneWidget);
      expect(find.text('مالی شرکت الف'), findsOneWidget);
      expect(find.text('office@forough.example'), findsOneWidget);
      expect(
        find.text(Fa.date(DateTime(2026, 10, 31, 9, 30).toIso8601String(), time: false)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('نشان‌شده ستارهٔ طلایی و پیوست نشان داده می‌شود', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EmailCard(
            message: sample(isNeshan: true, hasAttachment: true),
            tab: EmailTab.archive,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('پیوست'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('کارت ارسالی گیرنده را با آیکون ارسال نشان می‌دهد', (tester) async {
      await tester.pumpWidget(
        _wrap(EmailCard(message: sample(box: EmailBox.sent), tab: EmailTab.sent)),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byIcon(Icons.send_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('کارت خالی/آزمایشی خطا نمی‌دهد', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EmailCard(
            message: const EmailMessage(
              id: 2,
              box: EmailBox.inbox,
              accountId: 0,
              accountAddress: '',
              fromOrTo: '',
              subject: '(بدون موضوع)',
              date: null,
            ),
            tab: EmailTab.draft,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('(بدون موضوع)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('نوار انتخاب حساب همهٔ حساب‌ها را نشان می‌دهد', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EmailAccountStrip(
            accounts: [
              EmailAccount.fromJson({
                'emailId': 1,
                'emailAddress': 'office@x.com',
                'isDabirkhane': true,
              }),
              EmailAccount.fromJson({'emailId': 2, 'emailAddress': 'me@x.com'}),
            ],
            selectedId: 2,
            color: OfficeColors.email,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('همهٔ حساب‌ها'), findsOneWidget);
      expect(find.text('office@x.com'), findsOneWidget);
      expect(find.text('me@x.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ------------------------------------------------------------
  //  رندر کامل صفحه
  // ------------------------------------------------------------

  group('رندر صفحهٔ ایمیل', () {
    Future<void> pumpPage(
      WidgetTester tester, {
      EmailScope scope = EmailScope.corporate,
      bool embedded = false,
    }) async {
      const storage = FlutterSecureStorage();
      final api = ApiClient(storage);
      final auth = AuthController(api, storage);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider.value(value: api),
            Provider(create: (_) => EmailRepository(api)),
            Provider(create: (_) => EmailDraftStore(storage)),
          ],
          child: MaterialApp(
            locale: const Locale('fa', 'IR'),
            supportedLocales: const [Locale('fa', 'IR')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(useMaterial3: true),
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            ),
            home: EmailPage(initialScope: scope, embedded: embedded),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('سربرگ، دامنه و چهار کارتابل دیده می‌شوند', (tester) async {
      await pumpPage(tester);
      expect(find.text('پست الکترونیک'), findsOneWidget);
      expect(find.text('ایمیل سازمانی'), findsWidgets);
      expect(find.text('ایمیل شخصی'), findsWidgets);
      expect(find.text('دریافتی'), findsWidgets);
      expect(find.text('ارسالی'), findsWidgets);
      expect(find.text('بایگانی'), findsWidgets);
      expect(find.text('پیش‌نویس'), findsWidgets);
      expect(find.text('ایمیل جدید'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('دامنهٔ شخصی هم بدون خطا رندر می‌شود', (tester) async {
      await pumpPage(tester, scope: EmailScope.personal);
      expect(find.text('پست الکترونیک'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('جابه‌جایی کارتابل‌ها خطا نمی‌دهد', (tester) async {
      await pumpPage(tester);
      for (final label in ['ارسالی', 'بایگانی', 'پیش‌نویس', 'دریافتی']) {
        await tester.tap(find.text(label).first);
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(ErrorWidget), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('حالت جاسازی‌شده داخل اتوماسیون بدون هدر تکراری رندر می‌شود', (tester) async {
      await pumpPage(tester, scope: EmailScope.corporate, embedded: true);
      expect(find.text('پست الکترونیک'), findsNothing);
      expect(find.text('دریافتی'), findsWidgets);
      expect(find.text('ارسالی'), findsWidgets);
      expect(find.text('بایگانی'), findsWidgets);
      expect(find.text('پیش‌نویس'), findsWidgets);
      expect(find.text('ایمیل جدید'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
