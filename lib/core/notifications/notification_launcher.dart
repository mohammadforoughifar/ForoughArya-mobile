// ============================================================
//  باز کردن «خودِ سند» از روی اعلان گوشی
//
//  مسیر کار:
//    ۱) PushService هنگام ساخت نوتیفیکیشن، کل رکورد اعلان را (json) داخل
//       payload می‌گذارد.
//    ۲) کاربر روی اعلان می‌زند → این کلاس payload را می‌گیرد و با
//       NotificationResolver همان نامه/دستور کار/صورت‌جلسه را پیدا می‌کند.
//    ۳) صفحهٔ جزئیات همان سند روی Navigator اصلی باز می‌شود — چه اپ
//       باز باشد (foreground) و چه کاربر با زدن روی اعلان اپ را باز کرده
//       باشد (cold start از getNotificationAppLaunchDetails).
//
//  اگر اپ هنوز آماده نبود (لاگین/مونت‌نشدن ناوبر)، درخواست در صف می‌ماند
//  و به‌محض attach شدن، باز می‌شود.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';

import '../network/api_client.dart';
import '../../features/home/data/notification_target.dart';
import '../../features/home/models/home_models.dart';
import '../../features/misc/presentation/minutes_detail_page.dart';
import '../../features/office_automation/data/office_repository.dart';
import '../../features/office_automation/presentation/letter_detail_page.dart';
import '../../features/work_orders/presentation/work_order_detail_page.dart';

/// کلید Navigator سراسری — برای باز کردن صفحه از بیرونِ درخت ویجت‌ها.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class NotificationLauncher {
  NotificationLauncher._();

  static final NotificationLauncher instance = NotificationLauncher._();

  ApiClient? _api;

  /// payloadهایی که هنوز نتوانسته‌ایم باز کنیم.
  final List<Map<String, dynamic>> _queue = [];

  /// آخرین payload باز‌شده — جلوگیری از باز شدن تکراری با دو لمس.
  String? _lastPayload;
  DateTime? _lastAt;

  bool get isReady => _api != null && appNavigatorKey.currentState != null;

  /// از داخل اپ صدا زده می‌شود؛ به‌محض آماده شدن، صف باز می‌شود.
  void attach(ApiClient api) {
    _api = api;
    if (_queue.isNotEmpty) {
      final pending = List<Map<String, dynamic>>.from(_queue);
      _queue.clear();
      for (final m in pending) {
        openFromJson(m);
      }
    }
  }

  void detach() {
    _api = null;
  }

  /// ورودیِ callback نوتیفیکیشن (رشتهٔ payload).
  Future<void> handlePayload(String? payload) async {
    if (payload == null || payload.trim().isEmpty) return;
    final raw = payload.trim();
    Map<String, dynamic>? json;
    if (raw.startsWith('{')) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) json = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    // payloadهای قدیمی فقط لینک بودند
    json ??= <String, dynamic>{'link': raw, 'title': ''};

    final stamp = '${json['id']}-${json['link']}';
    final now = DateTime.now();
    if (_lastPayload == stamp &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastPayload = stamp;
    _lastAt = now;

    if (!isReady) {
      _queue.add(json);
      return;
    }
    await openFromJson(json);
  }

  /// باز کردن سندِ متناظر با یک اعلان.
  Future<void> openFromJson(Map<String, dynamic> json) async {
    final nav = appNavigatorKey.currentState;
    final api = _api;
    if (nav == null || api == null) {
      _queue.add(json);
      return;
    }
    final item = NotificationItem.fromJson(json);

    NotificationTarget target;
    try {
      target = await NotificationResolver(api).resolve(item);
    } catch (_) {
      target = NotificationTarget(
        kind: item.entityKind ?? 'none',
        id: item.entityId,
        reason: 'خطا در شناسایی',
      );
    }

    final ctx = nav.context;
    final messenger = ScaffoldMessenger.maybeOf(ctx);

    switch (target.kind) {
      case 'wo':
        if (target.isResolved) {
          await nav.push(
            MaterialPageRoute<void>(
              builder: (_) => WorkOrderDetailPage(id: target.id!),
            ),
          );
          return;
        }
        break;
      case 'minutes':
        if (target.isResolved) {
          await nav.push(
            MaterialPageRoute<void>(
              builder: (_) => MinutesDetailPage(minutesId: target.id!),
            ),
          );
          return;
        }
        break;
      case 'letter':
        if (target.isResolved) {
          await nav.push(
            MaterialPageRoute<void>(
              builder: (_) => LetterDetailPage(
                kind: target.letterKind ?? LetterKind.inner,
                letterId: target.id!,
                erjaId: target.erjaId ?? item.entityId,
              ),
            ),
          );
          return;
        }
        break;
    }

    // پیدا نشد → پیام روشن به‌جای باز کردن صفحهٔ خالی ماژول
    final title = item.title.trim().isEmpty ? 'مورد مرتبط' : item.title.trim();
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('«$title» پیدا نشد؛ ممکن است حذف یا بایگانی شده باشد.'),
      ),
    );
  }
}
