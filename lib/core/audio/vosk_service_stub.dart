/// API هم‌شکل با vosk_flutter_service برای وب — هیچ‌کدام واقعاً صدا زده نمی‌شوند
/// چون مسیر اندروید/iOS فقط در غیر-وب فعال است.
class Model {
  const Model();
}

class Recognizer {
  Future<String> getFinalResult() async => '';
}

class SpeechService {
  Stream<String> onPartial() => const Stream<String>.empty();
  Stream<String> onResult() => const Stream<String>.empty();
  Future<void> start() async {}
  Future<void> stop() async {}
  Future<void> cancel() async {}
  Future<void> dispose() async {}
}

class VoskFlutterPlugin {
  VoskFlutterPlugin._();
  static final VoskFlutterPlugin _instance = VoskFlutterPlugin._();
  static VoskFlutterPlugin instance() => _instance;

  Future<Model> createModel(String path) async => const Model();

  Future<Recognizer> createRecognizer({
    required Model model,
    required int sampleRate,
    List<String>? grammar,
  }) async =>
      Recognizer();

  Future<SpeechService> initSpeechService(Recognizer recognizer) async =>
      SpeechService();
}
