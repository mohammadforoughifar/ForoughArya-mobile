// ============================================================
//  تست جامع «بازطراحی فوق‌حرفه‌ای اتوماسیون اداری و دبیرخانه یکپارچه توکا»
//  پوشش‌دهندهٔ:
//    • مدل‌های جدید دبیرخانه (`DabirkhaneStats`, `LetterSendMethodSpec`,
//      `LetterNumberReservation`, `LetterStructureItem`, `PersonalArchive*`)
//    • تطابق دقیق مجوزهای وب (`OutgoingLetters.Dabirkhane`, `IncomingLetters.Dabirkhane`,
//      `PersonalSettings.ManageLetterGroups`, `LetterStructures.Read/Update`)
//    • میز فرماندهی `OfficeAutomationPage` در ۳۶۰×۸۰۰ RTL (نبض زنده، بنتو/پوشه، جستجو، تب‌ها)
//    • `OfficeDabirkhanePage` (صادره + وارده + فیلتر ۹گانه + ثبت دبیرخانه + رزرو اندیکاتور)
//    • صفحات مکمل (`LetterGroupsPage`, `LetterStructurePage`, `AmalgarsManagerPage`,
//      `PersonalArchivePage`, `OfficeGuidePage`)
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/auth/auth_controller.dart';
import 'package:forough_mobile/core/auth/auth_session.dart';
import 'package:forough_mobile/core/auth/web_access.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/office_automation/data/email_draft_store.dart';
import 'package:forough_mobile/features/office_automation/data/email_repository.dart';
import 'package:forough_mobile/features/office_automation/data/office_repository.dart';
import 'package:forough_mobile/features/office_automation/models/letter_models.dart';
import 'package:forough_mobile/features/office_automation/presentation/letter_mailbox_page.dart';
import 'package:forough_mobile/features/office_automation/presentation/office_dabirkhane_page.dart';
import 'package:forough_mobile/features/office_automation/presentation/office_home_page.dart';
import 'package:forough_mobile/features/office_automation/presentation/office_tools_pages.dart';
import 'package:provider/provider.dart';

class _MemStorage extends FlutterSecureStorage {
  final Map<String, String> _m = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _m.remove(key);
    } else {
      _m[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _m[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _m.remove(key);

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map.of(_m);

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _m.containsKey(key);

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _m.clear();
}

class _OfficeStubAdapter implements HttpClientAdapter {
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final p = options.uri.path;
    paths.add('${options.method} $p');
    Object body = const <String, dynamic>{};

    if (p.endsWith('/dabirkhane/stats')) {
      body = {'pending': 4, 'registered': 18, 'archived': 9, 'total': 22};
    } else if (p.endsWith('/dabirkhane/creators') ||
        p.endsWith('/recivers')) {
      body = [
        {'userId': 11, 'fullName': 'مهندس کریمی', 'sematTitle': 'مدیر فنی'},
        {'userId': 12, 'fullName': 'خانم رضایی', 'sematTitle': 'مسئول دبیرخانه'},
      ];
    } else if (p.endsWith('/companies')) {
      body = [
        {'id': 1, 'name': 'شرکت مهندسی فروغ آریا'},
      ];
    } else if (p.contains('/dabirkhane/bayegani/tree') ||
        p.contains('/bayegani/tree')) {
      body = [
        {
          'bayeganiId': 10,
          'title': 'پرونده قراردادهای ۱۴۰۵',
          'isFolder': true,
          'children': [],
        },
      ];
    } else if (p.endsWith('/outgoing-letters/dabirkhane')) {
      body = {
        'total': 2,
        'items': [
          {
            'letterId': 101,
            'sadereNumber': '1405/ص/101',
            'title': 'ارسال اسناد مناقصه پروژه فولاد',
            'receiverOrganization': 'شرکت فولاد مبارکه',
            'receiverName': 'مهندس موسوی',
            'companyName': 'فروغ آریا',
            'creatorName': 'مهندس کریمی',
            'mahramanegi': 'محرمانه',
            'foriat': 'فوری',
            'status': 3,
            'dabirkhaneSabt': false,
            'hasAttachment': true,
            'dateSabt': '2026-11-20T08:30:00',
          },
          {
            'letterId': 102,
            'sadereNumber': '1405/ص/102',
            'title': 'اعلام وصول صورت‌وضعیت مرحله سوم',
            'receiverOrganization': 'کارفرمای محترم',
            'companyName': 'فروغ آریا',
            'status': 3,
            'dabirkhaneSabt': true,
            'sendMethod': 'پست پیشتاز',
            'trackingCode': '2988110044',
            'dateSabt': '2026-11-19T11:00:00',
          },
        ],
      };
    } else if (p.endsWith('/incoming-letters/reservations')) {
      body = [
        {
          'id': 1,
          'reservedNumber': '1405/و/501',
          'typeForm': 3,
          'reservedByName': 'خانم رضایی',
          'reservedAt': '2026-11-20T09:00:00',
          'isUsed': false,
        },
      ];
    } else if (p.endsWith('/incoming-letters/reserve-number')) {
      body = [
        {'id': 2, 'reservedNumber': '1405/و/502', 'isUsed': false},
      ];
    } else if (p.contains('/letters/groups')) {
      body = [
        {
          'groupId': 1,
          'nameGroup': 'مدیران ارشد',
          'memberCount': 2,
          'members': [
            {'userId': 11, 'fullName': 'مهندس کریمی'},
          ],
        },
      ];
    } else if (p.contains('/amalgars')) {
      body = [
        {'amalgarId': 1, 'title': 'جهت اقدام فوری', 'requiresSign': true},
        {'amalgarId': 2, 'title': 'جهت استحضار', 'requiresSign': false},
      ];
    } else if (p.contains('/api/letter-structures')) {
      if (options.method == 'PUT') {
        body = {
          'typeForm': 1,
          'title': 'نامه داخلی',
          'parts': ['سال', 'شماره'],
        };
      } else {
        body = {
          'items': [
            {
              'typeForm': 1,
              'title': 'نامه داخلی',
              'parts': ['سال', 'واحد', 'شماره'],
            },
            {
              'typeForm': 2,
              'title': 'نامه صادره',
              'parts': ['سال', 'شماره'],
            },
            {
              'typeForm': 3,
              'title': 'نامه وارده (اندیکاتور)',
              'parts': ['سال', 'شماره'],
            },
          ],
        };
      }
    } else if (p.endsWith('/api/archive/folders')) {
      body = [
        {'id': 5, 'title': 'مکاتبات مهم من', 'itemCount': 1},
      ];
    } else if (p.contains('/api/archive/items/')) {
      body = [
        {
          'id': 90,
          'folderId': 5,
          'title': 'ابلاغیه بودجه ۱۴۰۵',
          'refNumber': '1405/د/14',
          'createdAt': '2026-11-18T10:00:00',
        },
      ];
    } else if (p.contains('/api/email/dabirkhane-accounts') ||
        p.contains('/api/email/accounts')) {
      body = [
        {
          'id': 1,
          'address': 'dabirkhane@forougharya.ir',
          'displayName': 'دبیرخانه مرکزی',
          'isDabirkhane': true,
          'isActive': true,
        },
      ];
    } else if (p.contains('/api/email/inbox')) {
      body = {'items': <dynamic>[], 'totalCount': 0, 'unreadCount': 3};
    } else if (p.contains('/inbox') ||
        p.contains('/sent') ||
        p.contains('/archive') ||
        p.contains('/signing-inbox')) {
      body = {
        'total': 1,
        'items': [
          {
            'letterId': 77,
            'erjaId': 301,
            'letterNumber': '1405/د/77',
            'title': 'هماهنگی جلسه کمیته فنی',
            'senderName': 'مهندس کریمی',
            'foriat': 'فوری',
            'mahramanegi': 'عادی',
            'isRead': false,
            'isNeshan': true,
            'hasAttachment': true,
            'dateSabt': '2026-11-21T07:45:00',
          },
        ],
      };
    } else if (p.contains('/drafts')) {
      body = {'items': <dynamic>[], 'total': 0};
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<({
  AuthController auth,
  ApiClient api,
  OfficeAutomationRepository repo,
  _OfficeStubAdapter adapter,
})> _makeEnv(List<String> permissions, {String role = 'User'}) async {
  final storage = _MemStorage();
  final session = AuthSession(
    userId: 21,
    token: 'tok-office',
    username: 'dabir',
    role: role,
    displayName: 'مسئول دبیرخانه',
    permissions: permissions,
  );
  await storage.write(key: 'auth_session', value: jsonEncode(session.toJson()));
  await storage.write(key: 'auth_token', value: session.token);
  final adapter = _OfficeStubAdapter();
  final api = ApiClient(storage)..dio.httpClientAdapter = adapter;
  final auth = AuthController(api, storage);
  await auth.initialize();
  final repo = OfficeAutomationRepository(api);
  return (auth: auth, api: api, repo: repo, adapter: adapter);
}

Widget _wrap360(
  AuthController auth,
  ApiClient api,
  OfficeAutomationRepository repo,
  Widget child,
) {
  final storage = _MemStorage();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      Provider<ApiClient>.value(value: api),
      Provider<OfficeAutomationRepository>.value(value: repo),
      Provider<EmailRepository>.value(value: EmailRepository(api)),
      Provider<EmailDraftStore>.value(value: EmailDraftStore(storage)),
    ],
    child: MaterialApp(
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  group('مدل‌ها و مجوزهای دبیرخانه یکپارچه و ابزارهای اتوماسیون', () {
    test('DabirkhaneStats، روش‌های ارسال ۷گانه، رزرو اندیکاتور و ساختار شماره', () {
      final st = DabirkhaneStats.fromJson({
        'Pending': 5,
        'Registered': 19,
        'Archived': 7,
        'Total': 24,
      });
      expect(st.pending, 5);
      expect(st.registered, 19);
      expect(st.archived, 7);
      expect(st.total, 24);

      expect(LetterSendMethodSpec.allMethods.length, 7);
      expect(
        LetterSendMethodSpec.of('پست پیشتاز').needsTrackingCode,
        isTrue,
      );
      expect(
        LetterSendMethodSpec.of('پیک').needsDelivererName,
        isTrue,
      );
      expect(
        LetterSendMethodSpec.of('ایمیل').needsDestEmail,
        isTrue,
      );
      expect(
        LetterSendMethodSpec.of('فکس').needsFax,
        isTrue,
      );

      final res = LetterNumberReservation.fromJson({
        'Id': 9,
        'NumberSabt': '1405/و/88',
        'TypeForm': 3,
        'IsUsed': false,
      });
      expect(res.numberSabt, '1405/و/88');
      expect(res.isUsed, isFalse);

      final ls = LetterStructureItem.fromJson({
        'typeForm': 1,
        'title': 'نامه داخلی',
        'parts': ['سال', 'واحد', 'شماره'],
      });
      expect(ls.parts, ['سال', 'واحد', 'شماره']);
    });

    test('تفکیک دقیق RBAC دبیرخانه صادره/وارده، گروه گیرندگان و ساختار شماره', () {
      final incomingOnly = WebAccess(
        AuthSession(
          userId: 1,
          token: 't',
          username: 'u1',
          role: 'User',
          displayName: 'کاربر وارده',
          permissions: const ['IncomingLetters.Dabirkhane'],
        ),
      );
      expect(incomingOnly.canSeeOutgoingDabirkhane, isFalse);
      expect(incomingOnly.canSeeIncomingDabirkhane, isTrue);
      expect(incomingOnly.canSeeDabirkhane, isTrue);
      expect(incomingOnly.canCreateIncomingLetter, isTrue);

      final outgoingDabir = WebAccess(
        AuthSession(
          userId: 2,
          token: 't',
          username: 'u2',
          role: 'User',
          displayName: 'کاربر دبیرخانه مرکزی',
          permissions: const [
            'OutgoingLetters.Dabirkhane',
            'PersonalSettings.ManageLetterGroups',
            'LetterStructures.Read',
          ],
        ),
      );
      expect(outgoingDabir.canSeeOutgoingDabirkhane, isTrue);
      expect(outgoingDabir.canSeeIncomingDabirkhane, isTrue);
      expect(outgoingDabir.canManageLetterGroups, isTrue);
      expect(outgoingDabir.canSeeLetterStructures, isTrue);
      expect(outgoingDabir.canUpdateLetterStructures, isFalse);
    });
  });

  group('تست ویجت ۳۶۰×۸۰۰ RTL — میز فرماندهی اتوماسیون، دبیرخانه و صفحات مکمل', () {
    testWidgets('OfficeAutomationPage در عرض ۳۶۰px بدون سرریز رندر شده و بین بنتو/پوشه و تب‌ها جابه‌جا می‌شود', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final env = await _makeEnv(const [
        'InnerLetters.View',
        'InnerLetters.Create',
        'OutgoingLetters.View',
        'OutgoingLetters.Create',
        'OutgoingLetters.Dabirkhane',
        'IncomingLetters.View',
        'IncomingLetters.Dabirkhane',
        'Email.View',
        'Email.Personal',
        'MyArchive.View',
        'LetterStructures.Read',
        'MeetingMinutes.View',
      ]);

      await tester.pumpWidget(
        _wrap360(env.auth, env.api, env.repo, const OfficeAutomationPage()),
      );
      await _settle(tester);

      expect(find.text('اتوماسیون اداری توکا'), findsOneWidget);
      expect(find.text('میز فرماندهی'), findsOneWidget);
      expect(find.text('دبیرخانه'), findsOneWidget);
      expect(find.text('دبیرخانه نامه‌های صادره'), findsOneWidget);

      // تغییر نما به حالت پوشه‌ای و بازگشت به بنتو
      await tester.tap(find.byTooltip('نمای پوشه‌ای'));
      await _settle(tester);
      expect(tester.takeException(), isNull);

      // جابه‌جایی به تب زندهٔ دبیرخانه
      await tester.ensureVisible(find.text('دبیرخانه'));
      await _settle(tester);
      await tester.tap(find.text('دبیرخانه'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OfficeDabirkhanePage هر دو حالت صادره و وارده و شیت رزرو اندیکاتور را در ۳۶۰px رندر می‌کند', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final env = await _makeEnv(const [
        'OutgoingLetters.View',
        'OutgoingLetters.Dabirkhane',
        'IncomingLetters.View',
        'IncomingLetters.Dabirkhane',
      ]);

      await tester.pumpWidget(
        _wrap360(env.auth, env.api, env.repo, const OfficeDabirkhanePage()),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);

      expect(find.text('دبیرخانه صادره'), findsOneWidget);
      expect(find.text('دبیرخانه وارده'), findsOneWidget);
      expect(find.text('ارسال اسناد مناقصه پروژه فولاد'), findsOneWidget);

      // باز کردن شیت فیلتر پیشرفته دبیرخانه
      await tester.tap(find.byTooltip('فیلتر پیشرفته دبیرخانه'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(OfficeDabirkhanePage))).pop();
      await _settle(tester);

      // سوییچ به دبیرخانه وارده و باز کردن مدیریت رزرو شماره اندیکاتور
      await tester.tap(find.text('دبیرخانه وارده'));
      await _settle(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('مدیریت و رزرو شماره اندیکاتور دبیرخانه'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('اندیکاتور'), findsWidgets);
    });

    testWidgets('کارتابل نامه‌ها و ۵ صفحهٔ ابزار مکمل بدون خطا در ۳۶۰px رندر می‌شوند', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final env = await _makeEnv(const [
        'InnerLetters.View',
        'InnerLetters.Create',
        'LetterStructures.Read',
        'LetterStructures.Update',
        'MyArchive.View',
      ]);

      for (final page in <Widget>[
        const LetterMailboxPage(kind: LetterKind.inner),
        const LetterGroupsPage(),
        const LetterStructurePage(),
        const AmalgarsManagerPage(),
        const PersonalArchivePage(),
        const OfficeGuidePage(),
      ]) {
        await tester.pumpWidget(_wrap360(env.auth, env.api, env.repo, page));
        await _settle(tester);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
