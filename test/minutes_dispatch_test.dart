// ============================================================
//  تست عکس‌العمل شیت ارسال: حالت «کل صورتجلسه» در برابر «یک بند»
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/misc/models/minutes_models.dart';
import 'package:forough_mobile/features/misc/presentation/minutes_dispatch_sheet.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

MinutesItem _item() => const MinutesItem(
  id: 77,
  rowNo: 3,
  description: 'تهیه گزارش عملکرد ماهانه و ارسال به مدیرعامل',
);

Widget _host(Widget child, ApiClient api) => MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
  ],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  final api = ApiClient(const FlutterSecureStorage());

  testWidgets('شیت ارسال برای یک بند، حالت «فقط بند» را نشان می‌دهد', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MinutesDispatchSheet(
          minutesId: 15,
          item: _item(),
          minutesTitle: 'جلسهٔ هیئت‌مدیره',
        ),
        api,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('فقط بند'), findsOneWidget);
    expect(find.textContaining('بدون پیوست کل صورتجلسه'), findsOneWidget);
    // دکمهٔ ادامه هم به همان بند اشاره می‌کند (ادامه و ارسال)
    expect(find.textContaining('ادامه و ارسال'), findsOneWidget);
    // هیچ گزینه‌ای برای پیوست PDF کل صورتجلسه در حالت بند وجود ندارد
    expect(find.textContaining('پیوست PDF کامل صورتجلسه'), findsNothing);
  });

  testWidgets('شیت ارسال برای کل صورتجلسه، پیوست PDF کامل دارد', (tester) async {
    await tester.pumpWidget(
      _host(
        MinutesDispatchSheet(minutesId: 15, minutesTitle: 'جلسهٔ هیئت‌مدیره'),
        api,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('کل صورتجلسه'), findsWidgets);
    expect(find.textContaining('پیوست PDF کامل'), findsWidgets);
    // در حالت کل صورتجلسه، هیچ اشاره‌ای به «فقط بند» نباید باشد
    expect(find.textContaining('فقط بند'), findsNothing);
  });
}
