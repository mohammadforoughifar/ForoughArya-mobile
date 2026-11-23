// ============================================================
//  تحویل، چاپ و پخش فایل در نسخهٔ وب / PWA (به‌ویژه iOS Safari و آیفون)
//
//  در حالت Standalone در صفحهٔ اصلی آیفون (Add to Home Screen):
//    • برای PDF / Excel / CSV / تصاویر: ابتدا از Web Share API Level 2
//      (`navigator.share({ files })`) استفاده می‌شود تا شیت بومی iOS
//      (Save to Files، AirPrint، تلگرام، واتساپ، AirDrop) باز شود؛ و در
//      دسکتاپ یا مرورگرهای فاقد Share مستقیم، دانلود Blob انجام می‌شود.
//    • برای برگه‌های چاپی HTML (فاکتور، بیجک، صورت‌حساب، رسید تعمیر):
//      رندر داخل iframe هم‌دامنه + `contentWindow.print()` انجام می‌شود تا
//      پنجرهٔ بومی AirPrint / ذخیرهٔ PDF آیفون بدون بلاک‌شدن پاپ‌آپ باز شود.
// ============================================================

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'web_files_stub.dart'
    if (dart.library.js_interop) 'web_files_web.dart';

/// روی وب فایل را تحویل کاربر می‌دهد (Share بومی در آیفون یا دانلود مرورگر)
/// و `true` برمی‌گرداند؛ روی موبایل بومی `false` برمی‌گرداند تا کد موجود اجرا شود.
Future<bool> webDeliver(
  List<int> bytes,
  String fileName, {
  String? mimeType,
  bool preferShare = true,
}) async {
  if (!kIsWeb) return false;
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final resolvedMime = mimeType ?? mimeOf(fileName) ?? 'application/octet-stream';
  final handled = await platformDeliverBytes(
    data,
    fileName,
    resolvedMime,
    preferShare: preferShare,
  );
  if (handled) return true;
  await FilePicker.saveFile(fileName: fileName, bytes: data);
  return true;
}

/// چاپ مستقیم HTML (فاکتور، پیش‌فاکتور، بیجک، صورت‌حساب، گزارش سفارش) در وب و آیفون.
/// اگر `share: true` باشد فایل HTML را به شیت اشتراک‌گذاری آیفون می‌فرستد؛
/// در غیر این صورت دیالوگ بومی چاپ / AirPrint آیفون را باز می‌کند.
Future<bool> webOpenHtmlForPrint(
  String html,
  String fileName, {
  bool share = false,
}) async {
  if (!kIsWeb) return false;
  final handled = await platformPrintHtml(html, fileName, share: share);
  if (handled) return true;
  return webDeliver(
    utf8.encode(html),
    fileName,
    mimeType: 'text/html;charset=utf-8',
    preferShare: share,
  );
}

/// پخش صوت (ویس‌های پیام‌رسان) روی مرورگر و Safari آیفون.
Future<bool> webPlayAudio(Uint8List bytes, {String? fileName}) async {
  if (!kIsWeb) return false;
  final mime = mimeOf(fileName ?? '') ?? 'audio/mp4';
  return platformPlayAudioBytes(bytes, mime);
}

Future<void> webStopAudio() async {
  if (!kIsWeb) return;
  await platformStopAudio();
}

/// بایت‌های فایل انتخاب‌شده با `FilePicker.pickFiles` را در هر دو پلتفرم می‌خواند.
Future<Uint8List?> pickedBytes(dynamic picked) async {
  try {
    final dynamic b = await picked.readAsBytes();
    if (b is Uint8List && b.isNotEmpty) return b;
  } catch (_) {}
  try {
    final dynamic x = picked.xFile;
    if (x != null) {
      final dynamic b = await x.readAsBytes();
      if (b is Uint8List && b.isNotEmpty) return b;
    }
  } catch (_) {}
  try {
    final dynamic b = picked.bytes;
    if (b is Uint8List && b.isNotEmpty) return b;
  } catch (_) {}
  return null;
}

String? mimeOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return null;
  switch (name.substring(dot + 1).toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'csv':
      return 'text/csv;charset=utf-8';
    case 'html':
    case 'htm':
      return 'text/html;charset=utf-8';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'doc':
      return 'application/msword';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
    case 'aac':
      return 'audio/mp4';
    case 'ogg':
    case 'opus':
      return 'audio/ogg';
    case 'wav':
      return 'audio/wav';
    case 'mp4':
      return 'video/mp4';
    case 'txt':
      return 'text/plain;charset=utf-8';
    case 'zip':
      return 'application/zip';
    default:
      return null;
  }
}
