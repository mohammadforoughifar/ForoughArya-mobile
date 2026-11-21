// ============================================================
//  نوتیفیکیشن واقعی گوشی (مثل جی‌میل و تلگرام)
//
//  دو حالت پوشش داده می‌شود:
//    ۱) اپ باز است        → با هر poll، اعلان‌های تازه در نوار گوشی می‌نشیند
//    ۲) اپ بسته/در پس‌زمینه → سرویس پیش‌زمینهٔ بومی اندروید (PushPollingService)
//       هر ۶۰ ثانیه اعلان‌ها را می‌گیرد و بدون بالاآوردن موتور Flutter نوتیفیکیشن می‌سازد
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import '../utils/html_text.dart';
import 'background_push_channel.dart';
import 'notification_launcher.dart';

/// شناسهٔ کانال اعلان‌ها — در تنظیمات اندروید برای کاربر قابل خاموش‌کردن است.
const _channelId = 'forough_notifications';
const _channelName = 'اعلان‌های فروغ آریا';
const _channelDesc = 'نامه‌های ارجاع‌شده، دستور کارها و اعلان‌های سازمانی';

/// نام تسک پس‌زمینه — برای سازگاری قرارداد تست‌ها ثابت نگه داشته شده است.
const backgroundTaskName = 'forough-notifications-poll';

/// آخرین شناسهٔ اعلان دیده‌شده — برای اینکه یک اعلان دو بار نشان داده نشود.
const _seenKey = 'push_last_seen_id';

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  bool _started = false;
  bool _foregroundStarted = false;
  int _lastSeenId = 0;
  FlutterSecureStorage? _storage;

  /// دسترسی به GET اعلان‌ها برای بازخوانی متن اعلان‌های تحویل‌نشده.
  Future<dynamic> Function(String path, Map<String, dynamic> query)? _getApi;

  /// آماده‌سازی: کانال، مجوز، بارگذاری وضعیت و ثبت تسک پس‌زمینه.
  /// بعد از لاگین صدا زده می‌شود (نیاز به توکن دارد).
  Future<void> start(ApiClientLike api, FlutterSecureStorage storage) async {
    // نسخهٔ وب (PWA): نوتیفیکیشن بومی/پس‌زمینه ندارد؛ زنگولهٔ داخل اپ کار می‌کند
    if (kIsWeb) return;
    if (_started) return;
    _started = true;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      // کاربر روی نوتیفیکیشن زد → خودِ همان سند باز می‌شود
      onDidReceiveNotificationResponse: (resp) {
        NotificationLauncher.instance.handlePayload(resp.payload);
      },
      // کاربر از حالت بستهٔ اپ روی نوتیفیکیشن زده است
      onDidReceiveBackgroundNotificationResponse: _backgroundTap,
    );

    // اگر اپ با زدن روی اعلان باز شده باشد (cold start)
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        final payload = launch?.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          NotificationLauncher.instance.handlePayload(payload);
        }
      }
    } catch (_) {}

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

    _storage = storage;
    _getApi = (path, query) async {
      final r = await api.get(path, query: query);
      return r.data;
    };
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

    // ریشهٔ باگ «نوتیفیکیشن هست ولی چیزی نمایش داده نمی‌شود»:
    // اعلان‌هایی که در دورهٔ قبل ساخته شدند ولی گوشی آن‌ها را نشان نداد
    // (مجوز خاموش، کشته‌شدن اپ، کانال مسدود) دیگر هرگز دوباره تلاش نمی‌شدند،
    // چون «دیده‌شده» علامت خورده بودند. اینجا یک‌بار دوباره نشانده می‌شوند.
    unawaited(_redeliverPending(storage));

    // بعضی گوشی‌ها (شیائومی/سامسونگ) پس‌زمینه را می‌کشند؛ راهنمای معافیت
    // از بهینه‌سازی باتری فقط یک‌بار نشان داده می‌شود.
    await _maybeAskBattery(storage);

    _startPolling(api, storage);

    // سرویس پیش‌زمینهٔ بومی — تا پاپ‌آپ حتی وقتی اپ کاملاً بسته است بیاید
    await _startForegroundService(storage);
  }

  /// روشن‌کردن سرویس بومی و هم‌گام‌سازی داده‌هایش (توکن/سرور/شرکت/آخرین شناسه).
  Future<bool> _startForegroundService(FlutterSecureStorage storage) async {
    if (!BackgroundPushChannel.instance.supported) return false;
    try {
      final token = await storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) return false;
      final base = await storage.read(key: 'api_base_url');
      final company = await storage.read(key: 'company_id');
      final alts = (await storage.read(key: 'api_base_urls') ?? '')
          .split('\n')
          .where((e) => e.trim().isNotEmpty)
          .toList();
      final ok = await BackgroundPushChannel.instance.start(
        baseUrls: alts,
        baseUrl: (base != null && base.isNotEmpty)
            ? base
            : const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://localhost:5100',
              ),
        token: token,
        companyId: company,
        lastSeenId: _lastSeenId,
      );
      _foregroundStarted = ok;
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// آیا سرویس پیش‌زمینه در حال اجراست؟
  bool get foregroundRunning => _foregroundStarted;

  /// روشن‌کردن دوبارهٔ سرویس (اگر سیستم آن را کشته بود).
  Future<void> ensureForeground() async {
    if (kIsWeb) return;
    if (_foregroundStarted) return;
    final storage = _storage ?? const FlutterSecureStorage();
    _storage = storage;
    await _startForegroundService(storage);
  }

  /// هم‌گام‌کردن «آخرین شناسهٔ دیده‌شده» با سرویس بومی — وگرنه سرویس همان
  /// اعلان‌هایی را که اپِ باز دیده است، دوباره پاپ‌آپ می‌کند.
  Future<void> _syncSeenWithService(int id) async {
    if (!BackgroundPushChannel.instance.supported) return;
    await BackgroundPushChannel.instance.update(lastSeenId: id);
  }

  /// با تغییر شرکت فعال، «آخرین شناسهٔ دیده‌شده» بی‌معنا می‌شود (شناسه‌ها
  /// جدا هستند)؛ اگر ریست نشود، اعلان‌های شرکت جدید هرگز نشان داده نمی‌شوند.
  Future<void> onCompanyChanged() async {
    final storage = _storage;
    _lastSeenId = 0;
    if (storage != null) {
      try {
        await storage.delete(key: _seenKey);
      } catch (_) {}
    }
    // سرویس بومی هم باید شرکت جدید را بداند
    final company = await storage?.read(key: 'company_id');
    await BackgroundPushChannel.instance.update(
      companyId: company ?? '',
      lastSeenId: 0,
    );
    // یک بررسی فوری تا زنگوله/نوار گوشی با شرکت جدید هم‌گام شود.
    unawaited(pollQuietly());
  }

  /// بررسی فوری اعلان‌ها — وقتی اپ از پس‌زمینه برمی‌گردد یا شرکت عوض می‌شود.
  /// ریشهٔ باگ «نوتیفیکیشن هست ولی چیزی نمایش داده نمی‌شود»: در اندروید
  /// تایمر ۴۵ ثانیه‌ای پس از رفتن به پس‌زمینه متوقف می‌شود و اعلان‌های دورهٔ
  /// پس‌زمینه تا باز شدن دوبارهٔ اپ دیده نمی‌شدند.
  Future<int> pollQuietly() async {
    if (_getApi == null || _storage == null) return 0;
    try {
      final n = await _pollOnceImpl();
      return n;
    } catch (_) {
      return 0;
    }
  }

  /// چرخهٔ بررسی با اتصال مجدد اپ به نمایان (resumed) از بیرون صدا زده می‌شود.
  void resumePolling() {
    if (kIsWeb) return;
    if (_getApi == null || _storage == null) return;
    _restartTimer();
    unawaited(pollQuietly());
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) async {
      try {
        await _pollOnceImpl();
      } catch (_) {}
    });
  }

  /// پاک کردن همهٔ اعلان‌های نوار گوشی (بعد از «پاک کردن همه» در شیت اعلان‌ها)
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
    _foregroundStarted = false;
    // با خروج از حساب، سرویس بومی هم باید خاموش شود
    unawaited(BackgroundPushChannel.instance.stop());
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
    _storage = storage;
    _getApi ??= (path, query) async {
      final r = await api.get(path, query: query);
      return r.data;
    };
    return _pollOnceImpl();
  }

  Future<int> _pollOnceImpl() async {
    final api = _getApi;
    final storage = _storage;
    if (api == null || storage == null) return 0;
    final r = await api('/api/notifications', {'take': 30});
    var d = r;
    if (d is Map && d['items'] is List) d = d['items'];
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
      final id = (m['id'] as num?)?.toInt() ?? 0;
      final shown = await showNotification(
        id: id,
        title: m['title']?.toString() ?? 'اعلان سازمانی',
        body: [
          if ((m['fromName'] ?? '').toString().isNotEmpty)
            m['fromName'].toString(),
          if ((m['body'] ?? '').toString().isNotEmpty) htmlToText(m['body'].toString()),
        ].join(' — '),
        payload: jsonEncode(m),
      );
      // اگر نوار گوشی قبول نکرد (مجوز/کانال خاموش)، برای تلاش دوباره
      // نگه می‌داریم — وگرنه اعلان برای همیشه گم می‌شد.
      if (!shown) await _rememberUndelivered(id);
    }
    _lastSeenId = maxId;
    await _writeSeen(storage, maxId);
    await _syncSeenWithService(maxId);
    return fresh.length;
  }

  /// آیا مجوز اعلان در سطح سیستم روشن است؟ (اندروید/آی‌او‌اس)
  Future<bool> areNotificationsEnabled() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? true;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final opts = await ios.checkPermissions();
        return opts?.isEnabled ?? true;
      }
    } catch (_) {}
    return true;
  }

  /// باز کردن تنظیمات اعلان‌های همین اپ در گوشی.
  Future<void> openNotificationSettings() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// ساخت (و تأیید نمایش) یک نوتیفیکیشن.
  /// برمی‌گرداند آیا واقعاً در نوار گوشی نشست یا نه.
  Future<bool> showNotification({
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
    final safeTitle = title.trim().isEmpty ? 'اعلان سازمانی' : title.trim();
    try {
      await _plugin.show(
        id: id,
        title: safeTitle,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('push show failed: $e');
      return false;
    }
    // تأیید واقعی: بعضی دستگاه‌ها/رام‌ها بدون خطا «می‌بلعند»
    // (کانال خاموش، مجوز رد‌شده). فقط اگر در فهرست فعالان دیده شد موفق است.
    try {
      final active = await _plugin.getActiveNotifications();
      for (final a in active) {
        if (a.id == id) return true;
      }
      if (kDebugMode) debugPrint('push show swallowed: id=$id');
      return false;
    } catch (_) {
      // پلتفرمی که این API را ندارد → به فراخوانی موفق تکیه می‌کنیم.
      return true;
    }
  }

  /// نشاندن دوبارهٔ اعلان‌هایی که تلاش قبلی‌شان به نوار گوشی نرسیده است.
  /// (فقط تا سقف [maxItems] و فقط یک‌بار در هر اجرای اپ.)
  Future<int> _redeliverPending(
    FlutterSecureStorage storage, {
    int maxItems = 5,
  }) async {
    final getApi = _getApi;
    if (getApi == null) return 0;
    const key = 'push_undelivered_ids';
    try {
      final raw = await storage.read(key: key);
      if (raw == null || raw.trim().isEmpty) return 0;
      final ids = raw
          .split(',')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .where((e) => e > 0)
          .toList();
      if (ids.isEmpty) {
        await storage.delete(key: key);
        return 0;
      }
      // فهرست تازه از سرور تا متن کامل اعلان‌ها را داشته باشیم.
      final r = await getApi('/api/notifications', {'take': 30});
      var d = r;
      if (d is Map && d['items'] is List) d = d['items'];
      if (d is! List) return 0;
      final byId = <int, Map<String, dynamic>>{};
      for (final raw in d.whereType<Map>()) {
        final m = Map<String, dynamic>.from(raw);
        final id = (m['id'] as num?)?.toInt() ?? 0;
        if (id > 0) byId[id] = m;
      }
      var shown = 0;
      final still = <int>[];
      for (final id in ids.take(maxItems)) {
        final m = byId[id];
        if (m == null) continue; // از سرور پاک شده → دیگر تلاشی لازم نیست
        final ok = await showNotification(
          id: id,
          title: m['title']?.toString() ?? 'اعلان سازمانی',
          body: [
            if ((m['fromName'] ?? '').toString().isNotEmpty)
              m['fromName'].toString(),
            if ((m['body'] ?? '').toString().isNotEmpty) htmlToText(m['body'].toString()),
          ].join(' — '),
          payload: jsonEncode(m),
        );
        if (ok) {
          shown++;
        } else {
          still.add(id);
        }
      }
      if (still.isEmpty) {
        await storage.delete(key: key);
      } else {
        await storage.write(key: key, value: still.join(','));
      }
      return shown;
    } catch (_) {
      return 0;
    }
  }

  /// ثبت شناسهٔ اعلانی که به نوار گوشی نرسید تا دور بعد دوباره تلاش شود.
  Future<void> _rememberUndelivered(int id) async {
    final storage = _storage;
    if (storage == null || id <= 0) return;
    const key = 'push_undelivered_ids';
    try {
      final raw = await storage.read(key: key) ?? '';
      final ids = raw
          .split(',')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .where((e) => e > 0)
          .toSet()
        ..add(id);
      // فقط ۲۰ شناسهٔ آخر نگه داشته می‌شود
      final list = ids.toList()..sort();
      final keep = list.length > 20 ? list.sublist(list.length - 20) : list;
      await storage.write(key: key, value: keep.join(','));
    } catch (_) {}
  }

  /// راهنمای یک‌بارهٔ معافیت از بهینه‌سازی باتری (برای اعلان در حالت بسته).
  Future<void> _maybeAskBattery(FlutterSecureStorage storage) async {
    const key = 'push_battery_asked';
    if (await storage.read(key: key) == '1') return;
    await storage.write(key: key, value: '1');
    await BackgroundPushChannel.instance.requestBatteryExemption();
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
/// کاربر در حالت بسته بودن اپ روی اعلان زده — payload به صف می‌رود و
/// به‌محض باز شدن اپ و آماده شدن ناوبر، همان سند باز می‌شود.
@pragma('vm:entry-point')
void _backgroundTap(NotificationResponse resp) {
  final payload = resp.payload;
  if (payload == null || payload.isEmpty) return;
  NotificationLauncher.instance.handlePayload(payload);
}

class ApiClientPushAdapter implements ApiClientLike {
  ApiClientPushAdapter(this._api);
  final ApiClient _api;

  @override
  Future<ApiResponseLike> get(String path, {Map<String, dynamic>? query}) async {
    final r = await _api.get<dynamic>(path, query: query);
    return ApiResponseLike(r.data);
  }
}

/// ابزار تست — تبدیل json به رشته برای لاگ
String debugJson(Object? d) => jsonEncode(d);
