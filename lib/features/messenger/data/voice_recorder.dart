// ============================================================
//  ضبط صدا برای پیام صوتی
//
//  اگر بستهٔ `record` در پروژه بود از آن استفاده می‌شود، وگرنه
//  مسیر ضبط بومی اندروید (MediaRecorder) از طریق کانال پلتفرم.
//  خروجی: فایل m4a/aac در پوشهٔ موقت برنامه.
// ============================================================

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class VoiceRecorder {
  static const _channel = MethodChannel('forough/voice');

  /// آیا ضبط صدا در این نسخه در دسترس است؟
  static Future<bool> available() async {
    try {
      final r = await _channel.invokeMethod<bool>('available');
      return r ?? false;
    } catch (_) {
      return false;
    }
  }

  /// درخواست واقعی اجازهٔ میکروفن — پنجرهٔ سیستم باز می‌شود.
  static Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// آیا اجازه از قبل داده شده است؟ (بدون باز کردن پنجره)
  static Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// باز کردن صفحهٔ تنظیمات برنامه (وقتی کاربر «هرگز اجازه نده» زده است)
  static Future<bool> openSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// آخرین خطای ضبط (برای نمایش به کاربر)
  static String? lastError;

  /// شروع ضبط؛ فایل خروجی برگردانده می‌شود.
  static Future<File?> start() async {
    lastError = null;
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ok = await _channel.invokeMethod<bool>('start', {'path': path});
      if (ok != true) {
        lastError = 'شروع ضبط صدا ناموفق بود (دسترسی میکروفن یا مشغول بودن آن).';
        return null;
      }
      return File(path);
    } on PlatformException catch (e) {
      lastError = e.message ?? 'خطای ضبط صدا';
      return null;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  /// پایان ضبط — فایل نهایی (اگر خالی/خیلی کوتاه بود null).
  static Future<File?> stop() async {
    try {
      final path = await _channel.invokeMethod<String>('stop');
      if (path == null || path.isEmpty) return null;
      final f = File(path);
      if (!await f.exists()) return null;
      final len = await f.length();
      if (len < 1024) return null; // کمتر از ~۰٫۱ ثانیه
      return f;
    } catch (_) {
      return null;
    }
  }

  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod('cancel');
    } catch (_) {}
  }
}
