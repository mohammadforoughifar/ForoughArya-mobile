import 'dart:typed_data';

Future<bool> platformDeliverBytes(
  Uint8List bytes,
  String fileName,
  String mimeType, {
  bool preferShare = true,
}) async => false;

Future<bool> platformPrintHtml(
  String html,
  String fileName, {
  bool share = false,
}) async => false;

Future<bool> platformPlayAudioBytes(Uint8List bytes, String mimeType) async =>
    false;

Future<void> platformStopAudio() async {}
