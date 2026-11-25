import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

/// موتور محلی تبدیل گفتار فارسی به متن — بدون اینترنت، بدون گوگل، بدون سرور.
///
/// فایل مدل (ggml-base.bin ~۱۴۷MB) اولین بار به‌صورت یک فایل واحد دانلود و در
/// حافظهٔ اپ ماندگار می‌شود؛ پس از آن تمام پردازش روی خود دستگاه انجام می‌شود
/// ( whisper.cpp با ۴ رشته، زبان fa ).
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

  /// حداقل اندازهٔ معقول برای مدل base (~۱۴۷MB)؛ دانلود مخدوش پذیرفته نمی‌شود.
  static const int _minModelBytes = 120 * 1024 * 1024;

  @override
  Future<bool> isModelReady() async {
    final f = await _modelFile();
    return f.existsSync() && f.lengthSync() >= _minModelBytes;
  }

  @override
  Future<bool> prepareModel({ValueChanged<double>? onProgress}) async {
    if (await isModelReady()) return true;
    final dest = await _modelFile();
    // آینهٔ چین که از ایران هم معمولاً خوب جواب می‌دهد + مسیر اصلی به‌عنوان fallback
    const hosts = [
      'https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main',
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main',
    ];
    for (final host in hosts) {
      try {
        if (await _download(host, dest, onProgress)) return true;
      } catch (_) {
        // به آینهٔ بعدی برو
      }
    }
    // در صورت شکست پاک‌سازی فایل نیم‌کاره
    try {
      final partial = File('${dest.path}.part');
      if (partial.existsSync()) await partial.delete();
      if (dest.existsSync()) await dest.delete();
    } catch (_) {}
    return false;
  }

  Future<bool> _download(
    String host,
    File dest,
    ValueChanged<double>? onProgress,
  ) async {
    final url = Uri.parse('$host/ggml-${_model.modelName}.bin');
    final client = HttpClient();
    try {
      final req = await client.getUrl(url);
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
