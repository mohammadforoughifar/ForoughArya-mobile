// ============================================================
//  نوتیفیکیشن واقعی گوشی (مثل جی‌میل و تلگرام)
//
//  دو حالت پوشش داده می‌شود:
//    ۱) اپ باز است        → با هر poll، اعلان‌های تازه در نوار گوشی می‌نشیند
//    ۲) اپ بسته/در پس‌زمینه → یک سرویس پس‌زمینه (Workmanager) هر ۱۵ دقیقه
//       (حداقلِ مجاز اندروید) اعلان‌ها را می‌گیرد و نوتیفیکیشن می‌سازد
//
//  محدودیت واقعی: بدون FCM سمت سرور، اندروید اجازهٔ بیدارکردن فوری در حالت
//  «Force stop» یا حالت خواب عمیق را نمی‌دهد؛ بازهٔ ۱۵ دقیقه‌ای همان کاری
//  است که واتس‌اپ/تلگرام بدون پوش سرور انجام می‌دهند. اگر سرور FCM اضافه کرد،
//  فقط همین فایل جایگزین می‌شود و بقیهٔ اپ دست نمی‌خورد.
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

/// شناسهٔ کانال اعلان‌ها — در تنظیمات اندروید برای کاربر قابل خاموش‌کردن است.
const _channelId = 'forough_notifications';
const _channelName = 'اعلان‌های فروغ آریا';
const _channelDesc = 'نامه‌های ارجاع‌شده، دستور کارها و اعلان‌های سازمانی';

/// نام تسک پس‌زمینه — نباید تغییر کند (در اندروید ثبت می‌شود).
const backgroundTaskName = 'forough-notifications-poll';

/// آخرین شناسهٔ اعلان دیده‌شده — برای اینکه یک اعلان دو بار نشان داده نشود.
const _seenKey = 'push_last_seen_id';

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  bool _started = false;
  int _lastSeenId = 0;

  /// آماده‌سازی: کانال، مجوز، بارگذاری وضعیت و ثبت تسک پس‌زمینه.
  /// بعد از لاگین صدا زده می‌شود (نیاز به توکن دارد).
  Future<void> start(ApiClientLike api, FlutterSecureStorage storage) async {
    if (_started) return;
    _started = true;

    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (_) {},
    );

    // کانال با اهمیت بالا تا در حالت سایلنت/روی صفحه هم نمایش داده شود.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    // مجوز اعلان اندروید ۱۳+ — اگر کاربر رد کند، اعلان ساخته نمی‌شود.
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _lastSeenId = await _readSeen(storage);

    // اولین بار: اعلان‌های موجود را «دیده‌شده» علامت می‌زنیم تا با ورود
    // به اپ، ناگهان چند نوتیفیکیشن قدیمی نیاید.
    if (_lastSeenId == 0) {
      final newest = await _newestId(api);
      if (newest > 0) {
        _lastSeenId = newest;
        await _writeSeen(storage, _lastSeenId);
      }
    }

    // بعضی گوشی‌ها (شیائومی/سامسونگ) پس‌زمینه را می‌کشند؛ راهنمای معافیت
    // از بهینه‌سازی باتری فقط یک‌بار نشان داده می‌شود.
    await _maybeAskBattery(storage);

    _startPolling(api, storage);
    await _registerBackground(api, storage);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// چرخهٔ ۴۵ ثانیه‌ای فقط وقتی اپ باز است (سبک: فقط unread-count و سپس
  /// در صورت تغییر، فهرست اعلان‌ها).
  void _startPolling(ApiClientLike api, FlutterSecureStorage storage) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) async {
      try {
        await pollOnce(api, storage);
      } catch (_) {
        // شبکه قطع است؛ دور بعد تلاش می‌شود.
      }
    });
  }

  /// یک بار بررسی اعلان‌های تازه و ساخت نوتیفیکیشن برای هرکدام.
  Future<int> pollOnce(
    ApiClientLike api,
    FlutterSecureStorage storage,
  ) async {
    final r = await api.get('/api/notifications', query: {'take': 20});
    final d = r.data;
    if (d is! List) return 0;
    final fresh = <Map<String, dynamic>>[];
    var maxId = _lastSeenId;
    for (final raw in d.whereType<Map>()) {
      final m = Map<String, dynamic>.from(raw);
      final id = (m['id'] as num?)?.toInt() ?? 0;
      if (id > maxId) maxId = id;
      if (id > _lastSeenId) fresh.add(m);
    }
    if (fresh.isEmpty) return 0;
    // قدیمی‌ترها اول، تا ترتیب نوار اعلان طبیعی باشد.
    fresh.sort(
      (a, b) => ((a['id'] as num?)?.toInt() ?? 0)
          .compareTo((b['id'] as num?)?.toInt() ?? 0),
    );
    for (final m in fresh) {
      await showNotification(
        id: (m['id'] as num?)?.toInt() ?? 0,
        title: m['title']?.toString() ?? 'اعلان جدید',
        body: [
          if ((m['fromName'] ?? '').toString().isNotEmpty)
            m['fromName'].toString(),
          if ((m['body'] ?? '').toString().isNotEmpty) m['body'].toString(),
        ].join(' — '),
        payload: m['link']?.toString(),
      );
    }
    _lastSeenId = maxId;
    await _writeSeen(storage, maxId);
    return fresh.length;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    String? body,
    String? payload,
  }) async {
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body ?? ''),
      // دکمه‌های سریع مثل پیام‌رسان‌ها
      actions: const [
        AndroidNotificationAction('open', 'مشاهده', showsUserInterface: true),
      ],
      category: AndroidNotificationCategory.message,
    );
    final details = NotificationDetails(
      android: android,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('push show failed: $e');
    }
  }

  /// راهنمای یک‌بارهٔ معافیت از بهینه‌سازی باتری (برای اعلان در حالت بسته).
  Future<void> _maybeAskBattery(FlutterSecureStorage storage) async {
    const key = 'push_battery_asked';
    if (await storage.read(key: key) == '1') return;
    await storage.write(key: key, value: '1');
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      // درخواست مجوز اعلان دقیق/آلارم؛ خطا در نسخه‌های قدیمی مهم نیست
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  Future<int> _newestId(ApiClientLike api) async {
    try {
      final r = await api.get('/api/notifications', query: {'take': 1});
      final d = r.data;
      if (d is List && d.isNotEmpty) {
        final m = d.first;
        if (m is Map) return (m['id'] as num?)?.toInt() ?? 0;
      }
      if (d is Map) {
        final items = d['items'];
        if (items is List && items.isNotEmpty) {
          final m = items.first;
          if (m is Map) return (m['id'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (_) {}
    return 0;
  }

  Future<int> _readSeen(FlutterSecureStorage storage) async =>
      int.tryParse(await storage.read(key: _seenKey) ?? '') ?? 0;

  Future<void> _writeSeen(FlutterSecureStorage storage, int id) =>
      storage.write(key: _seenKey, value: id.toString());

  // ------------------------------------------------------------
  //  پس‌زمینه — هر ۱۵ دقیقه (حداقل مجاز WorkManager)
  // ------------------------------------------------------------
  Future<void> _registerBackground(
    ApiClientLike api,
    FlutterSecureStorage storage,
  ) async {
    try {
      await Workmanager().initialize(backgroundCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        backgroundTaskName,
        backgroundTaskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('workmanager init failed: $e');
    }
  }
}

/// سطح حداقلی از ApiClient که این سرویس لازم دارد
/// (برای اینکه تست بدون شبکه هم بتواند اجرا شود).
abstract class ApiClientLike {
  Future<ApiResponseLike> get(String path, {Map<String, dynamic>? query});
}

class ApiResponseLike {
  ApiResponseLike(this.data);
  final dynamic data;
}

/// پل بین ApiClient واقعی و سطح حداقلی بالا
class ApiClientPushAdapter implements ApiClientLike {
  ApiClientPushAdapter(this._api);
  final ApiClient _api;

  @override
  Future<ApiResponseLike> get(String path, {Map<String, dynamic>? query}) async {
    final r = await _api.get<dynamic>(path, query: query);
    return ApiResponseLike(r.data);
  }
}

// ============================================================
//  ورودی سرویس پس‌زمینه
// ============================================================

/// @pragma برای اینکه R8 این تابع را حذف نکند (اندروید از طریق نام صدا می‌زند)
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) return true;
      final base = await _resolveBaseUrl(storage);

      final dio = Dio(
        BaseOptions(
          baseUrl: base,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
      final company = await storage.read(key: 'company_id');
      if (company != null && company.isNotEmpty) {
        dio.options.headers['X-Company-Id'] = company;
      }

      final plugin = FlutterLocalNotificationsPlugin();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await plugin.initialize(
        settings: const InitializationSettings(android: android),
      );

      final seen = int.tryParse(await storage.read(key: _seenKey) ?? '') ?? 0;
      final r = await dio.get<dynamic>(
        '/api/notifications',
        queryParameters: {'take': 20},
      );
      final data = r.data;
      if (data is! List) return true;

      var maxId = seen;
      final fresh = <Map<String, dynamic>>[];
      for (final raw in data.whereType<Map>()) {
        final m = Map<String, dynamic>.from(raw);
        final id = (m['id'] as num?)?.toInt() ?? 0;
        if (id > maxId) maxId = id;
        if (id > seen) fresh.add(m);
      }
      fresh.sort(
        (a, b) => ((a['id'] as num?)?.toInt() ?? 0)
            .compareTo((b['id'] as num?)?.toInt() ?? 0),
      );
      for (final m in fresh) {
        final body = [
          if ((m['fromName'] ?? '').toString().isNotEmpty)
            m['fromName'].toString(),
          if ((m['body'] ?? '').toString().isNotEmpty) m['body'].toString(),
        ].join(' — ');
        await plugin.show(
          id: (m['id'] as num?)?.toInt() ?? 0,
          title: m['title']?.toString() ?? 'اعلان جدید',
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: m['link']?.toString(),
        );
      }
      if (maxId > seen) {
        await storage.write(key: _seenKey, value: maxId.toString());
      }
      return true;
    } catch (_) {
      return true; // شکست شبکه نباید تسک را برای همیشه لغو کند
    }
  });
}

Future<String> _resolveBaseUrl(FlutterSecureStorage storage) async {
  final saved = await storage.read(key: 'api_base_url');
  if (saved != null && saved.isNotEmpty) return saved;
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5100',
  );
}

/// ابزار تست — تبدیل json به رشته برای لاگ
String debugJson(Object? d) => jsonEncode(d);
