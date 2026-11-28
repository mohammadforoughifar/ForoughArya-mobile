import 'dart:async';

import 'package:flutter/foundation.dart';

/// نسخهٔ غیر IO (وب): موتور محلی گفتار فارسی در دسترس نیست.
const bool kLocalVoskSupported = false;

/// رابط موتور محلی Vosk (فقط اندروید).
abstract class LocalVoskEngine {
  /// مدل را مطمين می‌کند و مسیر پوشهٔ آمادهٔ آن را برمی‌گرداند (یا null).
  Future<String?> ensureModelPath();
}

class LocalVosk {
  static final LocalVoskEngine instance = _Stub();
}

class _Stub implements LocalVoskEngine {
  @override
  Future<String?> ensureModelPath() async => null;
}
