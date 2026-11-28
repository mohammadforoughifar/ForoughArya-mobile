import 'vosk_service_stub.dart';

export 'vosk_service_stub.dart';

/// پیادهٔ وب/سایر: تجهیزات محلی وجود ندارد.
class VoskEngine {
  static Future<void> prewarm() async {}

  static Future<Recognizer> readyRecognizer() async =>
      throw StateError('vosk unavailable');
}
