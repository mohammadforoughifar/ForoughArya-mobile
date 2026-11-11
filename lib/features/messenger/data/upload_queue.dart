// ============================================================
//  صف ارسال پیوست در پس‌زمینه
//
//  مسئله: قبلاً آپلود فایل داخل خودِ صفحهٔ گفت‌وگو انجام می‌شد؛ اگر کاربر
//  از چت بیرون می‌رفت، ویجت dispose می‌شد و ارسال عملاً «کنسل» می‌شد.
//
//  راه‌حل: آپلود به یک سرویس سطح‌اپ (singleton) سپرده می‌شود که به عمر
//  صفحه وابسته نیست. کارها به ترتیب انجام می‌شوند، وضعیت هرکدام
//  (در انتظار/در حال ارسال/ارسال‌شده/خطا + درصد) در Stream منتشر می‌شود
//  و در هر جای اپ (صفحهٔ پیام‌رسان و داخل گفت‌وگو) قابل مشاهده است.
//  اگر خطا بدهد، دکمهٔ «تلاش دوباره» در دسترس است.
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/chat_models.dart';
import 'chat_repository.dart';

enum UploadState { queued, uploading, sent, failed }

/// یک پیوست در صف ارسال
class UploadTask {
  UploadTask({
    required this.localId,
    required this.conversationId,
    required this.file,
    required this.fileName,
    required this.isImage,
    required this.threadTitle,
  });

  final int localId;
  final int conversationId;
  final File file;
  final String fileName;
  final bool isImage;
  final String threadTitle;

  UploadState state = UploadState.queued;
  double progress = 0; // 0..1
  String? error;
  ChatMessage? sent;

  bool get isActive =>
      state == UploadState.queued || state == UploadState.uploading;
}

class UploadQueue {
  UploadQueue._();
  static final UploadQueue instance = UploadQueue._();

  final List<UploadTask> _tasks = [];
  final _changes = StreamController<List<UploadTask>>.broadcast();
  ApiClient? _api;
  bool _running = false;

  /// همهٔ کارهای فعال/اخیر (کپی) — برای نمایش
  List<UploadTask> get tasks => List.unmodifiable(_tasks);

  /// تغییرات صف
  Stream<List<UploadTask>> get changes => _changes.stream;

  /// درخواست‌های در انتظار یا در حال ارسال
  List<UploadTask> get active =>
      _tasks.where((t) => t.isActive).toList(growable: false);

  int get activeCount => active.length;

  /// از داخل اپ (بعد از لاگین) صدا زده می‌شود
  void attach(ApiClient api) => _api = api;

  /// درصد پیشرفت آپلود برای یک پیوست مشخص (از صفحهٔ گفت‌وگو)
  double progressOf(int localId) {
    for (final t in _tasks) {
      if (t.localId == localId) return t.progress;
    }
    return 0;
  }

  UploadTask? taskOf(int localId) {
    for (final t in _tasks) {
      if (t.localId == localId) return t;
    }
    return null;
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(List.unmodifiable(_tasks));
  }

  /// افزودن فایل به صف — بلافاصله برمی‌گردد، آپلود در پس‌زمینه انجام می‌شود.
  UploadTask enqueue({
    required int conversationId,
    required File file,
    required bool isImage,
    String threadTitle = '',
  }) {
    final task = UploadTask(
      localId: -DateTime.now().microsecondsSinceEpoch,
      conversationId: conversationId,
      file: file,
      fileName: file.uri.pathSegments.last,
      isImage: isImage,
      threadTitle: threadTitle,
    );
    _tasks.add(task);
    _emit();
    // بدون await — ارسال به عمر صفحه وابسته نیست
    unawaited(_pump());
    return task;
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final next = _tasks.firstWhereOrNull(
          (t) => t.state == UploadState.queued,
        );
        if (next == null) break;
        await _run(next);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _run(UploadTask t) async {
    final api = _api;
    if (api == null) {
      t.state = UploadState.failed;
      t.error = 'اتصال برنامه آماده نیست.';
      _emit();
      return;
    }
    t.state = UploadState.uploading;
    t.progress = 0;
    _emit();

    final repo = ChatRepository(api);
    try {
      final size = await t.file.length();
      final up = await repo.erp.uploadAttachmentWithProgress(
        t.conversationId,
        t.file,
        onProgress: (sent, total) {
          final denom = total > 0 ? total : size;
          if (denom <= 0) return;
          t.progress = (sent / denom).clamp(0, 1).toDouble();
          _emit();
        },
      );
      final msg = await repo.erp.sendMessage(
        t.conversationId,
        messageType: up.messageType,
        fileUrl: up.fileUrl,
        fileName: up.fileName,
        fileSizeBytes: up.fileSizeBytes,
        fileContentType: up.fileContentType,
      );
      t.progress = 1;
      t.state = UploadState.sent;
      t.sent = msg;
      _emit();
    } catch (e) {
      t.state = UploadState.failed;
      t.error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
      _emit();
    }
  }

  /// تلاش دوباره برای یک کار ناموفق
  void retry(UploadTask t) {
    if (t.state != UploadState.failed) return;
    t
      ..state = UploadState.queued
      ..error = null
      ..progress = 0;
    _emit();
    unawaited(_pump());
  }

  /// پاک‌کردن کارهای تمام‌شدهٔ قدیمی (بعد از نمایش)
  void clearFinished() {
    _tasks.removeWhere((t) => t.state == UploadState.sent);
    _emit();
  }

  @visibleForTesting
  void reset() {
    _tasks.clear();
    _running = false;
    _emit();
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
