import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/notifications/notification_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('payload خالی هیچ کاری نمی‌کند', () async {
    await NotificationLauncher.instance.handlePayload(null);
    await NotificationLauncher.instance.handlePayload('   ');
    expect(NotificationLauncher.instance.isReady, isFalse);
  });

  test('payload اعلان قبل از آماده شدن اپ در صف می‌ماند', () async {
    final l = NotificationLauncher.instance;
    await l.handlePayload('{"id":5,"title":"ارجاع نامه 1404/2187","link":"/letters/inner?id=88"}');
    // ناوبر و کلاینت وصل نیست → نباید خطا بدهد
    expect(l.isReady, isFalse);
  });

  test('payload لینک‌محورِ قدیمی هم پذیرفته می‌شود', () async {
    await NotificationLauncher.instance.handlePayload('/workorders/92');
    expect(NotificationLauncher.instance.isReady, isFalse);
  });
}
