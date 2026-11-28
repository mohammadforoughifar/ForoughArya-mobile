import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart';

/// موتور محلی و کاملاً آفلاین Vosk برای گفتار فارسی.
///
/// مدل «vosk-model-small-fa-0.42» داخل APK باندل می‌شود و با اولین اجرای اپ
/// از MainActivity به <filesDir>/vosk-model-small-fa-0.42 استخراج می‌شود؛
/// بعد از آن هیچ دانلود و انتظار دیگری وجود ندارد.
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

  bool _ready = false;

  Future<Directory> _dir() => getApplicationDocumentsDirectory();

  Future<String> _bundledPath() async => '${(await _dir()).path}/$_modelName';

  bool _looksValid(String dir) =>
      Directory(dir).existsSync() && File('$dir/am/final.mdl').existsSync();

  @override
  Future<String?> ensureModelPath() async {
    final bundled = await _bundledPath();
    if (_ready && _looksValid(bundled)) return bundled;
    // صبر برای استخراج در حال اجرا (اگر race شد)
    for (var i = 0; i < 16; i++) {
      if (_looksValid(bundled)) {
        _ready = true;
        return bundled;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    // پلن B — فقط وقتی APK بدون مدل باندل شده نصب شده باشد
    try {
      final path = await ModelLoader().loadFromNetwork(_modelUrl);
      if (path.isNotEmpty) {
        _ready = true;
        return path;
      }
    } catch (_) {}
    return null;
  }
}
