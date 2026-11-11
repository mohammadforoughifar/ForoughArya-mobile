// ============================================================
//  تست شمارش واقعی کارتابل‌ها (داشبورد اتوماسیون)
//  سرور در /stats فقط بخشی از کلیدها را برمی‌گرداند؛ عدد کارت هر ماژول
//  باید از خودِ endpoint هر کارتابل خوانده شود، نه از صفرِ پیش‌فرض.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/office_automation/data/office_repository.dart';
import 'package:forough_mobile/features/office_automation/models/office_common.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _Storage extends FlutterSecureStorage {
  final Map<String, String> _m = {};

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
    if (value == null) {
      _m.remove(key);
    } else {
      _m[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _m[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _m.remove(key);
}

/// آداپتور جعلی: مسیر هر کارتابل شمارش مشخصی دارد و /stats خالی است.
class _Adapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    final p = options.path;
    // /stats عمداً خالی است (مثل سرور واقعی که کلیدها را کامل نمی‌دهد)
    Object body = {};
    if (p.endsWith('/stats')) {
      body = {};
    } else if (p.contains('/inbox')) {
      body = {'totalCount': 7, 'items': []};
    } else if (p.contains('/sent')) {
      body = {'totalCount': 4, 'items': []};
    } else if (p.contains('/pishnevis')) {
      body = {'total': 2, 'items': []};
    } else if (p.contains('/archive') || p.contains('/bayegani')) {
      body = {'totalCount': 3, 'items': []};
    } else if (p.contains('/signing-inbox')) {
      body = {'totalCount': 5, 'items': []};
    } else if (p.contains('/dabirkhane')) {
      body = {'totalCount': 6, 'items': []};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
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
  test('شمارش کارتابل‌ها از endpoint خودشان خوانده می‌شود نه صفر', () async {
    final api = ApiClient(_Storage());
    final adapter = _Adapter();
    api.dio.httpClientAdapter = adapter;
    final repo = OfficeAutomationRepository(api);

    final counts = await repo.mailboxCounts(LetterKind.inner);
    expect(counts.inbox, 7);
    expect(counts.sent, 4);
    expect(counts.drafts, 2);
    expect(counts.archive, 3);
    expect(counts.signing, 0); // برای نامهٔ داخلی کارتابل امضا ندارد
    expect(adapter.requests, greaterThanOrEqualTo(4));
  });

  test('صادره: امضا و دبیرخانه هم شمرده می‌شوند', () async {
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = _Adapter();
    final repo = OfficeAutomationRepository(api);

    final counts = await repo.mailboxCounts(LetterKind.outgoing);
    expect(counts.inbox, 7);
    expect(counts.signing, 5);
    expect(counts.dabirkhane, 6);
  });

  test('ModuleMailboxCounts از stats ساخته می‌شود', () {
    final c = ModuleMailboxCounts.fromStats(
      const InboxStats(inbox: 9, sent: 3, pishnevis: 1, archive: 2),
    );
    expect(c.inbox, 9);
    expect(c.sent, 3);
    expect(c.drafts, 1);
    expect(c.archive, 2);
  });
}
