// ============================================================
//  تست رگرسیون باگ «نوتیفیکیشن هست ولی چیزی نمایش داده نمی‌شود»
//
//  علت‌های واقعی که پوشش داده می‌شود:
//    ۱) شیت اعلان‌ها فهرست را هیچ‌جا رندر نمی‌کرد (فقط سربرگ) — هرچند
//       شمارندهٔ زنگوله عدد نشان می‌داد.
//    ۲) اگر سرور فیلدهای PascalCase بفرستد، همهٔ کارت‌ها خالی می‌شدند.
//    ۳) اعلان بدون عنوان (title خالی) کارتِ بی‌متن می‌ساخت.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/home/models/home_models.dart';
import 'package:forough_mobile/features/home/presentation/notifications_sheet.dart';
import 'package:forough_mobile/features/home/data/home_repository.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// repository جعلی که فهرست ثابتی برمی‌گرداند (بدون شبکه).
class _FakeRepo extends HomeRepository {
  _FakeRepo(this.items) : super(ApiClient(const FlutterSecureStorage()));

  final List<NotificationItem> items;
  int markReadCalls = 0;

  @override
  Future<List<NotificationItem>> fetchNotifications({int take = 50}) async =>
      items;

  @override
  Future<void> markRead(int id) async => markReadCalls++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationItem — هرگز کارت خالی', () {
    test('عنوان خالی با formName و بعد body جایگزین می‌شود', () {
      expect(
        const NotificationItem(id: 1, title: '', formName: 'کارتابل نامه').displayTitle,
        'کارتابل نامه',
      );
      expect(
        const NotificationItem(id: 1, title: '  ', body: 'ارجاع شد').displayTitle,
        'ارجاع شد',
      );
      expect(
        const NotificationItem(id: 1, title: '').displayTitle,
        'اعلان سازمانی',
      );
    });

    test('بدنهٔ خالی به نام فرستنده برمی‌گردد و اگر نبود null', () {
      expect(
        const NotificationItem(id: 1, title: 'x', fromName: 'مدیر').displayBody,
        'مدیر',
      );
      expect(const NotificationItem(id: 1, title: 'x').displayBody, isNull);
    });

    test('کلیدهای PascalCase سرور هم خوانده می‌شوند', () {
      final n = NotificationItem.fromJson(const {
        'Id': 7,
        'Title': 'نامه وارده',
        'Body': 'ارجاع به واحد مالی',
        'FromName': 'دبیرخانه',
        'IsRead': true,
        'CreatedAt': '2026-11-01T08:00:00',
      });
      expect(n.id, 7);
      expect(n.title, 'نامه وارده');
      expect(n.body, 'ارجاع به واحد مالی');
      expect(n.fromName, 'دبیرخانه');
      expect(n.isRead, isTrue);
      expect(n.createdAt, isNotNull);
    });

    test('asRead فقط وضعیت خوانده‌شدن را عوض می‌کند و شناسه ثابت می‌ماند', () {
      const n = NotificationItem(
        id: 12,
        title: 'دستور کار ۴۴',
        body: 'ارجاع',
        entityKind: 'wo',
        entityId: 44,
      );
      final r = n.asRead();
      expect(r.isRead, isTrue);
      expect(r.id, 12);
      expect(r.entityKind, 'wo');
      expect(r.entityId, 44);
    });
  });

  group('NotificationsSheet — فهرست واقعاً رندر می‌شود', () {
    testWidgets('هر اعلان یک کارت با عنوان دیده می‌شود', (tester) async {
      final repo = _FakeRepo([
        const NotificationItem(
          id: 3,
          title: 'ارجاع نامه ۱۴۰۴/۲۱۸۷',
          body: 'به واحد مالی',
          fromName: 'دبیرخانه',
        ),
        const NotificationItem(id: 2, title: '', formName: 'صورت‌جلسه'),
      ]);

      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationsSheet(
              repository: repo,
              onOpen: (_) => opened++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ۱) کارت اول (عنوان + بدنه + فرستنده)
      expect(find.text('ارجاع نامه ۱۴۰۴/۲۱۸۷'), findsOneWidget);
      expect(find.text('به واحد مالی'), findsOneWidget);
      // ۲) کارت دوم با عنوان جایگزین (formName) — نه کارت خالی
      expect(find.text('صورت‌جلسه'), findsWidgets);

      // شمارندهٔ «خواندن همه» برای دو اعلان نخوانده
      expect(find.textContaining('خواندن همه'), findsOneWidget);
    });

    testWidgets('فهرست خالی پیام روشن می‌دهد (نه شیت بی‌متن)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationsSheet(repository: _FakeRepo(const [])),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('اعلان تازه‌ای ندارید.'), findsOneWidget);
    });

    testWidgets('زدن روی اعلان، onOpen را صدا می‌زند و آن را خوانده می‌کند', (
      tester,
    ) async {
      final repo = _FakeRepo([
        const NotificationItem(id: 9, title: 'دستور کار ۹۲', body: 'ارجاع'),
      ]);
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationsSheet(
              repository: repo,
              onOpen: (_) => opened++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('دستور کار ۹۲'));
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(repo.markReadCalls, 1);
    });
  });
}
