// ============================================================
//  تست صف آپلود: ارسال نباید به عمر صفحهٔ چت وابسته باشد
//  (باگ: با بیرون رفتن از چت، آپلود فایل حجیم کنسل می‌شد)
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/messenger/data/upload_queue.dart';

class _Storage extends FlutterSecureStorage {
  final Map<String, String> m = {};
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => m[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) m[key] = value;
  }
}

/// سرور شبیه‌سازی‌شده که آپلود پیوست را با تأخیر جواب می‌دهد
class _SlowServer implements HttpClientAdapter {
  _SlowServer({this.delay = const Duration(milliseconds: 400)});
  final Duration delay;
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.uri.path}');
    if (options.uri.path.endsWith('/attachments')) {
      await Future<void>.delayed(delay);
      return ResponseBody.fromString(
        jsonEncode({
          'id': 'att-1',
          'fileUrl': '/api/chat/attachments/att-1/download',
          'fileName': 'big.pdf',
          'fileSizeBytes': 1024,
          'fileContentType': 'application/pdf',
          'messageType': 3,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'id': 99, 'conversationId': 5, 'messageType': 3}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File file;
  late _SlowServer server;
  late ApiClient api;

  setUp(() async {
    UploadQueue.instance.reset();
    final dir = await Directory.systemTemp.createTemp('uq');
    file = File('${dir.path}/big.pdf');
    await file.writeAsBytes(List.filled(2048, 7));

    api = ApiClient(_Storage());
    await api.setBaseUrl('https://office.forough.ir');
    server = _SlowServer();
    api.dio.httpClientAdapter = server;
  });

  test('enqueue فوری برمی‌گردد و آپلود در پس‌زمینه تمام می‌شود', () async {
    UploadQueue.instance.attach(api);
    final sw = Stopwatch()..start();
    final task = UploadQueue.instance.enqueue(
      conversationId: 5,
      file: file,
      isImage: false,
    );
    // نباید منتظر آپلود بماند
    expect(sw.elapsedMilliseconds, lessThan(200));
    // ممکن است بلافاصله وارد حالت uploading شود (اجرای میکروتسک)
    expect(
      task.state == UploadState.queued || task.state == UploadState.uploading,
      isTrue,
    );
    expect(UploadQueue.instance.activeCount, 1);

    // صبر تا پایان (بدون هیچ وابستگی به صفحه)
    await UploadQueue.instance.changes.firstWhere(
      (list) => list.any(
        (t) => t.localId == task.localId && t.state == UploadState.sent,
      ),
    );
    expect(task.state, UploadState.sent);
    expect(UploadQueue.instance.activeCount, 0);

    // هم آپلود و هم ارسال پیام انجام شده است
    expect(server.calls.any((c) => c.contains('/attachments')), isTrue);
    expect(server.calls.any((c) => c.contains('/messages')), isTrue);
  });

  test('خطای شبکه وضعیت failed می‌دهد و retry دوباره تلاش می‌کند', () async {
    final failing = ApiClient(_Storage());
    await failing.setBaseUrl('https://office.forough.ir');
    failing.dio.httpClientAdapter = _Broken();
    UploadQueue.instance.attach(failing);

    final task = UploadQueue.instance.enqueue(
      conversationId: 5,
      file: file,
      isImage: true,
    );
    await UploadQueue.instance.changes.firstWhere(
      (list) => list.any(
        (t) => t.localId == task.localId && t.state == UploadState.failed,
      ),
    );
    expect(task.state, UploadState.failed);
    expect(task.error, isNotNull);

    // سرور سالم را وصل کن و دوباره تلاش کن
    UploadQueue.instance.attach(api);
    UploadQueue.instance.retry(task);
    await UploadQueue.instance.changes.firstWhere(
      (list) => list.any(
        (t) => t.localId == task.localId && t.state == UploadState.sent,
      ),
    );
    expect(task.state, UploadState.sent);
  });

  test('درصد پیشرفت بین ۰ و ۱ گزارش می‌شود', () async {
    UploadQueue.instance.attach(api);
    final task = UploadQueue.instance.enqueue(
      conversationId: 5,
      file: file,
      isImage: false,
    );
    await UploadQueue.instance.changes.firstWhere(
      (list) => list.any(
        (t) => t.localId == task.localId && t.state == UploadState.sent,
      ),
    );
    expect(task.progress, 1.0);
    expect(UploadQueue.instance.progressOf(task.localId), 1.0);
  });
}

class _Broken implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
  );
  @override
  void close({bool force = false}) {}
}
