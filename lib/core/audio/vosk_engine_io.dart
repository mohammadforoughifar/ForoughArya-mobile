export 'vosk_service_io.dart';

import 'dart:async';

import 'local_vosk.dart';
import 'vosk_service_io.dart';

/// موتور کش‌شده: مدل و recognizer فقط یک‌بار ساخته می‌شوند؛
/// [prewarm] از شروع اپ صدا زده می‌شود تا لمس دکمهٔ میکروفن «آنی» باشد.
class VoskEngine {
  VoskEngine._();

  static final VoskFlutterPlugin _plugin = VoskFlutterPlugin.instance();
  static Future<void>? _warming;
  static Model? _model;
  static Recognizer? _recognizer;

  /// گرم‌کردن پس‌زمینهٔ موتور (ایمن برای چندبار صدا زدن).
  static Future<void> prewarm() => _warming ??= _warm();

  static Future<void> _warm() async {
    try {
      final path = await LocalVosk.instance.ensureModelPath();
      if (path == null) return;
      _model ??= await _plugin.createModel(path);
      _recognizer ??= await _plugin.createRecognizer(
        model: _model!,
        sampleRate: 16000,
      );
    } catch (_) {
      // بازیابی در بار بعدی: نتیجهٔ شکست کش نمی‌شود
      _warming = null;
    }
  }

  /// recognizer آماده را برمی‌گرداند (اگر گرم نشده بود، منتظر تکمیل گرمایش می‌شود).
  static Future<Recognizer> readyRecognizer() async {
    await prewarm();
    final r = _recognizer;
    if (r == null) {
      throw StateError('vosk model unavailable');
    }
    return r;
  }
}
