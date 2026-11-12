// ============================================================
//  پل به سرویس پیش‌زمینهٔ بومی اندروید
//
//  چرا لازم است: تایمرهای Dart وقتی اپ بسته است اجرا نمی‌شوند و WorkManager
//  حداقل ۱۵ دقیقه فاصله دارد. برای اینکه پاپ‌آپ اعلان حتی با اپِ بسته هم
//  بیاید، یک Foreground Service بومی هر ۶۰ ثانیه سرور را می‌خواند و اعلان
//  را در نوار اندروید می‌نشاند.
//
//  این فایل:
//    • اطلاعات لازم (آدرس سرور، توکن، شرکت، آخرین شناسهٔ دیده‌شده) را به
//      SharedPreferences سرویس می‌نویسد (`configure`)
//    • سرویس را روشن/خاموش می‌کند (`start`/`stop`)
//    • آخرین شناسهٔ دیده‌شده را برای هم‌گامی با تایمر Dart می‌خواند/می‌نویسد
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundPushChannel {
  BackgroundPushChannel._();

  static final BackgroundPushChannel instance = BackgroundPushChannel._();

  static const _channel = MethodChannel('forough/push');

  bool _configured = false;
  bool get isRunning => _configured;

  /// آیا پلتفرم این قابلیت را دارد؟ (فقط اندروید)
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// نوشتن اطلاعات لازم و روشن‌کردن سرویس.
  Future<bool> start({
    required String baseUrl,
    required String token,
    String? companyId,
    int lastSeenId = 0,
    List<String> baseUrls = const [],
  }) async {
    if (!supported) return false;
    try {
      await _channel.invokeMethod<bool>('configure', {
        'baseUrl': baseUrl,
        // آدرس‌های جایگزین همان سرور (سوییچ شبکه در سرویس بومی)
        'baseUrls': baseUrls.join('\n'),
        'token': token,
        'companyId': companyId ?? '',
        'lastSeenId': lastSeenId,
      });
      final ok = await _channel.invokeMethod<bool>('start') ?? false;
      _configured = ok;
      return ok;
    } catch (_) {
      // روی اندرویدِ قدیمی یا اگر سرویس اجازه نداشت — اپ بدون آن هم کار می‌کند
      return false;
    }
  }

  /// به‌روزکردن فقط بخشی از اطلاعات (مثلاً بعد از تغییر شرکت یا خواندن اعلان)
  Future<void> update({
    String? baseUrl,
    String? token,
    String? companyId,
    int? lastSeenId,
    List<String>? baseUrls,
  }) async {
    if (!supported || !_configured) return;
    try {
      await _channel.invokeMethod<bool>('configure', {
        if (baseUrl != null) 'baseUrl': baseUrl,
        if (baseUrls != null) 'baseUrls': baseUrls.join('\n'),
        if (token != null) 'token': token,
        if (companyId != null) 'companyId': companyId,
        if (lastSeenId != null) 'lastSeenId': lastSeenId,
      });
    } catch (_) {}
  }

  /// آخرین شناسه‌ای که سرویس بومی «نمایش داده» است.
  Future<int> lastSeenId() async {
    if (!supported) return 0;
    try {
      return await _channel.invokeMethod<int>('lastSeenId') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> stop() async {
    if (!supported) return;
    _configured = false;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
  }

  /// درخواست معافیت از بهینه‌سازی باتری (برای اینکه سیستم سرویس را نکشد).
  Future<void> requestBatteryExemption() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }
}
