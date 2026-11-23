import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('foroughDeliverFileBase64')
external JSPromise<JSBoolean>? _jsDeliverFileBase64(
  JSString base64Data,
  JSString fileName,
  JSString mimeType,
  JSBoolean preferShare,
);

@JS('foroughPrintHtml')
external JSPromise<JSBoolean>? _jsPrintHtml(
  JSString html,
  JSString fileName,
  JSBoolean share,
);

@JS('foroughPlayAudioBase64')
external JSPromise<JSBoolean>? _jsPlayAudioBase64(
  JSString base64Data,
  JSString mimeType,
);

@JS('foroughStopAudio')
external void _jsStopAudio();

Future<bool> platformDeliverBytes(
  Uint8List bytes,
  String fileName,
  String mimeType, {
  bool preferShare = true,
}) async {
  try {
    final b64 = base64Encode(bytes);
    final promise = _jsDeliverFileBase64(
      b64.toJS,
      fileName.toJS,
      mimeType.toJS,
      preferShare.toJS,
    );
    if (promise == null) return false;
    final ok = await promise.toDart;
    return ok.toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> platformPrintHtml(
  String html,
  String fileName, {
  bool share = false,
}) async {
  try {
    final promise = _jsPrintHtml(html.toJS, fileName.toJS, share.toJS);
    if (promise == null) return false;
    final ok = await promise.toDart;
    return ok.toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> platformPlayAudioBytes(Uint8List bytes, String mimeType) async {
  try {
    final b64 = base64Encode(bytes);
    final promise = _jsPlayAudioBase64(b64.toJS, mimeType.toJS);
    if (promise == null) return false;
    final ok = await promise.toDart;
    return ok.toDart;
  } catch (_) {
    return false;
  }
}

Future<void> platformStopAudio() async {
  try {
    _jsStopAudio();
  } catch (_) {}
}
