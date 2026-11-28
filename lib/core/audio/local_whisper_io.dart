import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

/// موتور محلی تبدیل گفتار فارسی به متن — بدون اینترنت، بدون گوگل، بدون سرور.
///
/// مدل whisper.cpp (ggml-base-q5_1 ≈ ۵۷MB) **داخل خود APK باندل شده** و با اولین
/// اجرای اپ به حافظهٔ داخلی کپی می‌شود (MainActivity.seedWhisperModelIfNeeded).
/// بعد از آن هیچ دانلود و تأخیری وجود ندارد.
/// (اگر جایی اپ بدون مدل باندل شده نصب شد، prepareModel به‌عنوان پلن B آن را
/// از آینهٔ سریع دانلود می‌کند — فقط در آن حالت یک‌بار.)
const bool kLocalWhisperSupported = true;

abstract class LocalWhisperEngine {
  Future<bool> isModelReady();
  Future<bool> prepareModel({ValueChanged<double>? onProgress});
  Future<String?> transcribe(String audioPath, {String language = 'fa'});
  Future<void> discard(String path);
}

class LocalWhisper {
  static final LocalWhisperEngine instance = _IosAndroidEngine();
}

class _IosAndroidEngine implements LocalWhisperEngine {
  static const WhisperModel _model = WhisperModel.base;

  Future<Directory> _dir() => getApplicationSupportDirectory();

  String get _fileName => 'ggml-${_model.modelName}.bin';

  Future<File> _modelFile() async => File('${(await _dir()).path}/$_fileName');

  /// حداقل اندازهٔ معقول برای مدل base نسخهٔ q5_1 (~۵۷MB)
  static const int _minModelBytes = 45 * 1024 * 1024;

  @override
  Future<bool> isModelReady() async {
    final f = await _modelFile();
    return f.existsSync() && f.lengthSync() >= _minModelBytes;
  }

  @override
  Future<bool> prepareModel({ValueChanged<double>? onProgress}) async {
    if (await isModelReady()) return true;
    // کپی مدل از assets کمی طول می‌کشد (اگر Race شده باشد)
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (await isModelReady()) return true;
    }
    // پلن B — فقط وقتی APK بدون مدل باندل شده نصب شده باشد: دانلود یک‌بارهٔ q5_1
    final dest = await _modelFile();
    const hosts = [
      'https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main',
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main',
    ];
    for (final host in hosts) {
      try {
        if (await _download('$host/ggml-base-q5_1.bin', dest, onProgress)) {
          return true;
        }
      } catch (_) {
        // آینهٔ بعدی
      }
    }
    try {
      final partial = File('${dest.path}.part');
      if (partial.existsSync()) await partial.delete();
      if (dest.existsSync() && dest.lengthSync() < _minModelBytes) {
        await dest.delete();
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _download(
    String url,
    File dest,
    ValueChanged<double>? onProgress,
  ) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('user-agent', 'ForoughAryaApp/1.0 (Android)');
      final res = await req.close();
      if (res.statusCode != 200) return false;
      final total = res.contentLength;
      final tmp = File('${dest.path}.part');
      if (tmp.existsSync()) await tmp.delete();
      final raf = tmp.openSync(mode: FileMode.write);
      var written = 0;
      await for (final chunk in res) {
        raf.writeFromSync(chunk);
        written += chunk.length;
        if (total > 0) onProgress?.call(written / total);
      }
      await raf.close();
      if (written < _minModelBytes) return false;
      await tmp.rename(dest.path);
      return true;
    } finally {
      client.close();
    }
  }

  @override
  Future<String?> transcribe(String audioPath, {String language = 'fa'}) async {
    final whisper = Whisper(
      model: _model,
      modelDir: (await _dir()).path,
      downloadHost: 'https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main',
    );
    final response = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: audioPath,
        language: language,
        isNoTimestamps: true,
        isTranslate: false,
        threads: 4,
      ),
    );
    return response.text;
  }

  @override
  Future<void> discard(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }
}
