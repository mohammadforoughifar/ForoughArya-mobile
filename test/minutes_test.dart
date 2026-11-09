// ============================================================
//  تست‌های واحد و رندر ماژول «فرم‌های متفرقه» و «صورتجلسه»
//  شامل بررسی ارسال خودکار هدر X-Company-Id، خطاهای ۴۰۳/۴۰۰،
//  لیست، جزئیات، ثبت صورتجلسه و کاشی صفحهٔ اصلی
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/auth/auth_controller.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/misc/data/minutes_repository.dart';
import 'package:forough_mobile/features/misc/models/minutes_models.dart';
import 'package:forough_mobile/features/misc/presentation/minutes_detail_page.dart';
import 'package:forough_mobile/features/misc/presentation/minutes_editor_page.dart';
import 'package:forough_mobile/features/misc/presentation/minutes_list_page.dart';
import 'package:forough_mobile/features/misc/presentation/misc_forms_page.dart';
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
}

class _MinutesMockAdapter implements HttpClientAdapter {
  _MinutesMockAdapter({this.forceStatus, this.forceMessage, this.emptyList = false});

  final int? forceStatus;
  final String? forceMessage;
  final bool emptyList;

  final List<RequestOptions> captured = [];
  Map<String, dynamic>? savedPayload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    final p = options.path;

    if (p.contains('/api/company-context')) {
      return _json(200, {
        'activeCompanyId': 1001,
        'companies': [
          {'id': 1001, 'name': 'شرکت فروغ آریا', 'isActive': true},
          {'id': 1002, 'name': 'شرکت حمل‌ونقل آریا', 'isActive': true},
        ],
      });
    }

    if (forceStatus != null) {
      return _json(forceStatus!, {
        'message': forceMessage ?? 'خطای شبیه‌سازی‌شده',
      });
    }

    // سرور واقعی بدون هدر X-Company-Id خطای ۴۰۰ می‌دهد
    final cid = options.headers['X-Company-Id']?.toString();
    if (p.contains('/api/meeting-minutes') &&
        !p.endsWith('/user-options') &&
        (cid == null || cid.isEmpty)) {
      return _json(400, {'message': 'شرکت فعال انتخاب نشده است.'});
    }

    if (p.endsWith('/api/meeting-minutes/user-options')) {
      return _json(200, [
        {'id': 1, 'name': 'محمد فروغی‌فر'},
        {'id': 2, 'name': 'سارا رضایی'},
        {'id': 3, 'name': 'علی کریمی'},
      ]);
    }

    if (p.endsWith('/api/meeting-minutes') && options.method == 'POST') {
      savedPayload = options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : null;
      return _json(200, {'id': 42});
    }

    if (p.endsWith('/api/meeting-minutes') && options.method == 'GET') {
      if (emptyList) {
        return _json(200, {'items': <dynamic>[], 'total': 0});
      }
      return _json(200, {
        'items': [
          {
            'id': 15,
            'title': 'جلسه هماهنگی انبار و فروش',
            'meetingDate': '2026-11-08T09:30:00',
            'dateRegistered': '2026-11-08T10:00:00',
            'status': 'InReview',
            'createdByUserId': 1,
            'createdByName': 'محمد فروغی‌فر',
            'attendeeCount': 3,
            'absentCount': 1,
            'itemCount': 2,
            'itemDoneCount': 1,
            'attachmentCount': 1,
          },
        ],
        'total': 1,
      });
    }

    if (p.contains('/api/meeting-minutes/15') && options.method == 'GET') {
      return _json(200, {
        'id': 15,
        'title': 'جلسه هماهنگی انبار و فروش',
        'meetingDate': '2026-11-08T09:30:00',
        'dateRegistered': '2026-11-08T10:00:00',
        'status': 'InReview',
        'createdByUserId': 1,
        'createdByName': 'محمد فروغی‌فر',
        'participants': [
          {
            'id': 101,
            'userId': 1,
            'name': 'محمد فروغی‌فر',
            'kind': 'Attendee',
            'signatureData': null,
            'signedAt': null,
          },
          {
            'id': 102,
            'userId': 3,
            'name': 'علی کریمی',
            'kind': 'Absent',
          },
        ],
        'items': [
          {
            'id': 201,
            'rowNo': 1,
            'description': 'تطبیق موجودی کالاهای تندگردش تا پایان هفته',
            'dueDate': '2026-11-12T00:00:00',
            'responsibleUserId': 2,
            'responsibleName': 'سارا رضایی',
            'followUpDate': '2026-11-14T00:00:00',
            'followUpUserId': 1,
            'followUpName': 'محمد فروغی‌فر',
            'itemStatus': 'InProgress',
            'respApproved': true,
            'respNote': 'شمارش اولیه انجام شد',
            'followUpDecision': null,
          },
        ],
      });
    }

    if (p.contains('/api/attachments/MeetingMinutes/15')) {
      return _json(200, [
        {
          'id': 501,
          'fileName': 'گزارش-جلسه.pdf',
          'uploaderName': 'محمد فروغی‌فر',
          'size': 20480,
          'canDownload': true,
          'canDelete': true,
        },
      ]);
    }

    return _json(200, {'ok': true});
  }

  ResponseBody _json(int code, Object data) => ResponseBody.fromString(
    jsonEncode(data),
    code,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

Widget _wrap(Widget child, ApiClient api, _MemStorage storage) {
  final auth = AuthController(api, storage);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      Provider<ApiClient>.value(value: api),
      Provider<MinutesRepository>(create: (_) => MinutesRepository(api)),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('ApiClient X-Company-Id & MinutesModels', () {
    test('ensureCompanyId شرکت فعال را می‌خواند و هدر X-Company-Id را می‌فرستد', () async {
      final storage = _MemStorage();
      final api = ApiClient(storage);
      final adapter = _MinutesMockAdapter();
      api.dio.httpClientAdapter = adapter;

      final repo = MinutesRepository(api);
      final res = await repo.fetchList();

      expect(api.companyId, 1001);
      expect(res.total, 1);
      expect(res.items.first.title, 'جلسه هماهنگی انبار و فروش');

      final listReq = adapter.captured.firstWhere(
        (r) => r.path.endsWith('/api/meeting-minutes'),
      );
      expect(listReq.headers['X-Company-Id'], '1001');
    });

    test('پارس مدل جزئیات صورتجلسه با کلیدهای PascalCase و camelCase', () {
      final d = MinutesDetail.fromJson({
        'Id': 9,
        'Title': 'نشست فنی',
        'Status': 'Closed',
        'CreatedByUserId': 5,
        'CreatedByName': 'مدیر سیستم',
        'Participants': [
          {'Id': 1, 'UserId': 5, 'Name': 'مدیر سیستم', 'Kind': 'Attendee'},
        ],
        'Items': [
          {
            'Id': 7,
            'RowNo': 1,
            'Description': 'نهایی‌سازی سرور',
            'ItemStatus': 'Done',
            'RespApproved': true,
            'FollowUpDecision': 'Approved',
          },
        ],
      });
      expect(d.isClosed, isTrue);
      expect(d.doneCount, 1);
      expect(d.progress, 1.0);
      expect(d.attendees.length, 1);
    });
  });

  group('رندر صفحات فرم‌های متفرقه و صورتجلسه', () {
    testWidgets('MiscFormsPage کارت صورتجلسه و برچسب‌های به‌زودی را نشان می‌دهد', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final storage = _MemStorage();
      final api = ApiClient(storage)..dio.httpClientAdapter = _MinutesMockAdapter();

      await tester.pumpWidget(_wrap(const MiscFormsPage(), api, storage));
      await tester.pumpAndSettle();

      expect(find.text('صورتجلسه و فرم‌های متفرقه'), findsOneWidget);
      expect(find.text('صورتجلسه'), findsOneWidget);
      expect(find.text('۱ مورد'), findsOneWidget);
      expect(find.text('به‌زودی'), findsNWidgets(4));

      await tester.tap(find.text('صورتجلسه'));
      await tester.pumpAndSettle();

      expect(find.text('صورتجلسه‌ها'), findsOneWidget);
      expect(find.text('جلسه هماهنگی انبار و فروش'), findsOneWidget);
    });

    testWidgets('MinutesListPage وضعیت خالی را صریح و راهنمادار نشان می‌دهد', (
      tester,
    ) async {
      final storage = _MemStorage();
      final api = ApiClient(storage)
        ..dio.httpClientAdapter = _MinutesMockAdapter(emptyList: true);

      await tester.pumpWidget(_wrap(const MinutesListPage(), api, storage));
      await tester.pumpAndSettle();

      expect(find.text('صورتجلسه‌ای در گردش شما یافت نشد'), findsOneWidget);
      expect(find.text('ثبت صورتجلسه جدید'), findsOneWidget);
      expect(find.text('تغییر شرکت فعال'), findsOneWidget);
    });

    testWidgets('MinutesListPage خطای ۴۰۳ عدم مجوز MeetingMinutes.View را شفاف نشان می‌دهد', (
      tester,
    ) async {
      final storage = _MemStorage();
      final api = ApiClient(storage)
        ..dio.httpClientAdapter = _MinutesMockAdapter(
          forceStatus: 403,
          forceMessage: 'شما به این بخش دسترسی ندارید.',
        );

      await tester.pumpWidget(_wrap(const MinutesListPage(), api, storage));
      await tester.pumpAndSettle();

      expect(find.textContaining('عدم دسترسی به ماژول صورتجلسه'), findsOneWidget);
      expect(find.textContaining('MeetingMinutes.View'), findsOneWidget);
    });

    testWidgets('MinutesDetailPage تمامی جزئیات، حاضرین، بندها و پیوست‌ها را نمایش می‌دهد', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final storage = _MemStorage();
      final api = ApiClient(storage)..dio.httpClientAdapter = _MinutesMockAdapter();

      await tester.pumpWidget(
        _wrap(const MinutesDetailPage(minutesId: 15), api, storage),
      );
      await tester.pumpAndSettle();

      expect(find.text('جلسه هماهنگی انبار و فروش'), findsOneWidget);
      expect(find.text('چاپ PDF با سربرگ'), findsOneWidget);
      expect(find.text('ارسال به گردش'), findsOneWidget);
      expect(
        find.text('تطبیق موجودی کالاهای تندگردش تا پایان هفته'),
        findsOneWidget,
      );
      expect(find.textContaining('شمارش اولیه انجام شد'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(find.text('گزارش-جلسه.pdf'), findsOneWidget);
    });

    testWidgets('MinutesEditorPage صورتجلسه جدید را با حاضرین ثبت می‌کند', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final storage = _MemStorage();
      final adapter = _MinutesMockAdapter();
      final api = ApiClient(storage)..dio.httpClientAdapter = adapter;

      await tester.pumpWidget(_wrap(const MinutesEditorPage(), api, storage));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'جلسه بررسی عملکرد ماهانه',
      );
      await tester.tap(find.text('انتخاب').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('محمد فروغی‌فر'));
      await tester.pump();
      await tester.tap(find.text('تأیید انتخاب'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ثبت'));
      await tester.pumpAndSettle();

      expect(adapter.savedPayload?['title'], 'جلسه بررسی عملکرد ماهانه');
      expect(adapter.savedPayload?['attendeeUserIds'], [1]);
    });
  });
}
