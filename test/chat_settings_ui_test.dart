// تست رابط کاربری: دکمهٔ «شناسایی خودکار مسیر چت» باید واقعاً روی صفحه باشد
// (باگ: در نسخهٔ قبل پایین شیت و بیرون از دید/بریده می‌شد)

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/messenger/data/chat_repository.dart';
import 'package:forough_mobile/features/messenger/presentation/chat_settings_sheet.dart';

class _Storage extends FlutterSecureStorage {
  final Map<String, String> m = {};
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => m[key];
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
    if (value != null) m[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => m.remove(key);
}

void main() {
  testWidgets('دکمهٔ شناسایی خودکار در شیت تنظیمات دیده می‌شود', (t) async {
    t.view.physicalSize = const Size(1080, 1920);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final storage = _Storage();
    final repo = ChatRepository(ApiClient(storage), storage: storage);

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: c,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ChatSettingsSheet(repo: repo),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    final btn = find.byKey(const Key('auto-detect-chat'));
    expect(btn, findsOneWidget);
    expect(find.text('شناسایی خودکار مسیر چت'), findsOneWidget);
    expect(find.text('آدرس سرور پیام‌رسان'), findsOneWidget);
    // پیش‌فرض: همان سرور اصلی اپ (چت روی api/chat همان سرور است)
    expect(find.text('/api/chat'), findsWidgets);

    // باید داخل کادر صفحه باشد (نه بریده/بیرون از دید)
    final screen = t.view.physicalSize.height / t.view.devicePixelRatio;
    final r = t.getRect(btn);
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(screen));
    expect(r.height, greaterThan(30));
  });
}
