import 'package:flutter/foundation.dart';

/// نسخهٔ غیر IO (وب): موتور محلی گفتار فارسی در دسترس نیست.
const bool kLocalWhisperSupported = false;

/// رابط موتور محلی تبدیل گفتار فارسی به متن (whisper.cpp روی خود دستگاه)
abstract class LocalWhisperEngine {
  Future<bool> isModelReady() async => false;
  Future<bool> prepareModel({ValueChanged<double>? onProgress}) async => false;
  Future<String?> transcribe(String audioPath, {String language = 'fa'}) async =>
      null;
  Future<void> discard(String path) async {}
}

class LocalWhisper {
  static final LocalWhisperEngine instance = _Stub();
}

class _Stub implements LocalWhisperEngine {
  @override
  Future<bool> isModelReady() async => false;
  @override
  Future<bool> prepareModel({ValueChanged<double>? onProgress}) async => false;
  @override
  Future<String?> transcribe(String audioPath, {String language = 'fa'}) async =>
      null;
  @override
  Future<void> discard(String path) async {}
}
