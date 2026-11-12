// ============================================================
//  فایل‌ها در نسخهٔ وب (PWA)
//  در وب «پوشهٔ موقت» و OpenFilex وجود ندارد؛ فایل مستقیم از مرورگر
//  دانلود/باز می‌شود و برای آپلود، بایت‌های فایل خوانده می‌شود.
// ============================================================

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// در وب فایل را از مرورگر دانلود می‌کند و `true` برمی‌گرداند؛
/// در موبایل کاری نمی‌کند و `false` برمی‌گرداند (مسیر معمول ادامه می‌یابد).
Future<bool> webDeliver(List<int> bytes, String fileName) async {
  if (!kIsWeb) return false;
  final safe = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  await FilePicker.saveFile(
    fileName: safe.isEmpty ? 'file' : safe,
    bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    mimeType: mimeOf(safe),
  );
  return true;
}

/// بایت‌های فایل انتخاب‌شده (در وب مسیر فایل وجود ندارد)
Future<Uint8List?> pickedBytes(PlatformFile f) async {
  try {
    return await f.readAsBytes();
  } catch (_) {
    return null;
  }
}

String mimeOf(String name) {
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'xls' => 'application/vnd.ms-excel',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'doc' => 'application/msword',
    'csv' => 'text/csv',
    'txt' => 'text/plain',
    'zip' => 'application/zip',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'mp4' => 'video/mp4',
    _ => 'application/octet-stream',
  };
}
