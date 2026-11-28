import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'vosk_service_io.dart';

/// موتور محلی و کاملاً آفلاین Vosk برای گفتار فارسی.
///
/// مدل «vosk-model-small-fa-0.42» داخل APK باندل می‌شود و با **اجرای پس‌زمینهٔ
/// اپ** از MainActivity به <filesDir>/vosk-model-small-fa-0.42 استخراج می‌شود
/// (filesDir همان چیزی است که getApplicationSupportDirectory() برمی‌گرداند).
/// (پلن B: اگر APK بدون مدل ساخته شده باشد، یک‌بار از اینترنت دانلود می‌کند.)
const bool kLocalVoskSupported = true;

abstract class LocalVoskEngine {
  Future<String?> ensureModelPath();
}

class LocalVosk {
  static final LocalVoskEngine instance = _VoskIoEngine();
}

class _VoskIoEngine implements LocalVoskEngine {
  static const String _modelName = 'vosk-model-small-fa-0.42';
  static const String _modelUrl =
      'https://alphacephei.com/vosk/models/vosk-model-small-fa-0.42.zip';

  Future<Directory> _dir() => getApplicationSupportDirectory();

  bool _looksValid(String dir) =>
      Directory(dir).existsSync() && File('$dir/am/final.mdl').existsSync();

  @override
  Future<String?> ensureModelPath() async {
    final bundled = '${(await _dir()).path}/$_modelName';
    // MainActivity استخراج را در ترد پس‌زمینه انجام می‌دهد؛ با فلول کوتاه منتظر می‌مانیم
    for (var i = 0; i < 80; i++) {
      if (_looksValid(bundled)) return bundled;
      await Future<void>.delayed(const Duration(milliseconds: 75));
    }
    // پلن B — فقط وقتی APK بدون مدل باندل شده نصب شده باشد
    try {
      final path = await ModelLoader().loadFromNetwork(_modelUrl);
      if (path.isNotEmpty) return path;
    } catch (_) {}
    return null;
  }
}
