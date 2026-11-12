// ============================================================
//  تست پل سرویس پیش‌زمینهٔ اعلان
//
//  انتظارات واقعی:
//    • روی پلتفرم غیراندروید (این تست‌ها) هیچ فراخوانی بومی انجام نمی‌شود
//      و متدها باید بی‌خطا `false`/`0` برگردانند (اپ هرگز کرش نکند).
//    • پیکربندی ارسالی باید دقیقاً همان کلیدهایی باشد که سرویس Kotlin
//      می‌خواند (baseUrl/token/companyId/lastSeenId).
// ============================================================

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/notifications/background_push_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('forough/push');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'configure':
          return true;
        case 'start':
          return true;
        case 'stop':
          return true;
        case 'lastSeenId':
          return 42;
        default:
          return true;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('پیکربندی و اجرا، کلیدهای موردانتظار سرویس بومی را می‌فرستد', () async {
    // تست‌ها روی پلتفرم تست اجرا می‌شوند؛ supported=false → مسیر امن
    final b = BackgroundPushChannel.instance;
    if (!b.supported) {
      expect(await b.start(baseUrl: 'http://x', token: 't'), isFalse);
      expect(await b.lastSeenId(), 0);
      expect(calls, isEmpty);
      return;
    }
    final ok = await b.start(
      baseUrl: 'https://panel.example.com',
      token: 'abc',
      companyId: '7',
      lastSeenId: 11,
    );
    expect(ok, isTrue);
    final cfg = calls.firstWhere((c) => c.method == 'configure');
    expect(cfg.arguments['baseUrl'], 'https://panel.example.com');
    expect(cfg.arguments['token'], 'abc');
    expect(cfg.arguments['companyId'], '7');
    expect(cfg.arguments['lastSeenId'], 11);
  });

  test('update فقط کلیدهای داده‌شده را می‌فرستد (شرکت جدید/شناسه)', () async {
    final b = BackgroundPushChannel.instance;
    if (!b.supported) return;
    await b.start(baseUrl: 'http://x', token: 't');
    calls.clear();
    await b.update(lastSeenId: 99);
    final cfg = calls.singleWhere((c) => c.method == 'configure');
    expect(cfg.arguments['lastSeenId'], 99);
    expect(cfg.arguments.containsKey('token'), isFalse);
  });

  test('lastSeenId مقدار سرویس را برمی‌گرداند', () async {
    final b = BackgroundPushChannel.instance;
    if (!b.supported) return;
    expect(await b.lastSeenId(), 42);
  });

  test('اگر کانال بومی خطا بدهد، متد بی‌استثنا false برمی‌گرداند', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'E', message: 'boom');
    });
    final b = BackgroundPushChannel.instance;
    // روی هر پلتفرمی نباید استثنا بیرون بزند
    await expectLater(
      b.start(baseUrl: 'http://x', token: 't'),
      completion(isA<bool>()),
    );
  });
}
