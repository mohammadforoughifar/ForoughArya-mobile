// ============================================================
//  اتصال زندهٔ داشبورد سخت‌افزار (SignalR) — فاز ۹-الف
//
//  سرور: `Inventory.Api/Hubs/System/DashboardHub.cs` → مسیر `/hubs/dashboard`
//    • ورود کاربر باید مجوز `Dashboards.Hardware` داشته باشد وگرنه سرور
//      اتصال را با HubException می‌بندد:
//      «شما به هیچ‌یک از داشبوردهای بلادرنگ دسترسی ندارید.»
//    • پس از اتصال، سرور بلافاصله `ReceiveHardwareStats` را می‌فرستد.
//    • `HardwareMonitor` هر ۳۰ ثانیه (و پس از «بررسی فوری») همان رویداد را
//      برای گروه `Dashboard_Hardware` پخش می‌کند.
//    • متد سمت سرور: `RequestHardwareCheck()` — معادل دکمهٔ «بررسی فوری».
//
//  پیاده‌سازی پروتکل JSON بدون وابستگی به بستهٔ signalr_netcore، مثل
//  `messenger/data/chat_hub.dart`.
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HardwareHub {
  HardwareHub(this._dio, this._baseUrl);

  final Dio _dio;
  final String _baseUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _state = StreamController<bool>.broadcast();
  Timer? _ping;
  bool _ready = false;
  bool _closedByApp = false;

  /// رویدادهای دریافتی سرور: `{target, args}`
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// وضعیت اتصال (برای نشان «🟢 برخط (SignalR)» / «⚪ در حال اتصال…»)
  Stream<bool> get connection => _state.stream;
  bool get isConnected => _ready;

  static const hubPath = '/hubs/dashboard';

  /// اتصال به هاب داشبورد؛ در موفقیت `true` برمی‌گرداند.
  Future<bool> connect({String? token}) async {
    await disconnect();
    _closedByApp = false;
    final httpBase = _baseUrl.replaceAll(RegExp(r'/+$'), '');
    final hubHttp = '$httpBase${hubPath.startsWith('/') ? '' : '/'}$hubPath';

    Uri wsUri;
    try {
      final neg = await _dio.post<dynamic>(
        '$hubHttp/negotiate',
        queryParameters: {'negotiateVersion': '1'},
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );
      final d = neg.data;
      final connToken = (d is Map)
          ? (d['connectionToken'] ?? d['connectionId'])?.toString()
          : null;
      final wsBase = hubHttp.replaceFirst(RegExp(r'^http'), 'ws');
      wsUri = Uri.parse(
        connToken == null || connToken.isEmpty
            ? wsBase
            : '$wsBase?id=$connToken',
      );
    } catch (_) {
      wsUri = Uri.parse(hubHttp.replaceFirst(RegExp(r'^http'), 'ws'));
    }

    try {
      _channel = IOWebSocketChannel.connect(
        wsUri,
        headers: {
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        pingInterval: const Duration(seconds: 20),
      );
      await _channel!.ready.timeout(const Duration(seconds: 12));

      _sub = _channel!.stream.listen(
        _onData,
        onError: (_) => _setReady(false),
        onDone: () => _setReady(false),
      );

      _sendRaw({'protocol': 'json', 'version': 1});
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 15), (_) {
        _sendRaw({'type': 6});
      });
      _setReady(true);
      return true;
    } catch (_) {
      _setReady(false);
      return false;
    }
  }

  void _setReady(bool value) {
    if (_ready == value) return;
    _ready = value;
    if (!_state.isClosed) _state.add(value);
  }

  void _sendRaw(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add('${jsonEncode(msg)}\u001e');
    } catch (_) {}
  }

  void _onData(dynamic raw) {
    final text = raw is String ? raw : utf8.decode(raw as List<int>);
    for (final frame in text.split('\u001e')) {
      if (frame.trim().isEmpty) continue;
      try {
        final m = jsonDecode(frame);
        if (m is Map) _dispatch(Map<String, dynamic>.from(m));
      } catch (_) {}
    }
  }

  void _dispatch(Map<String, dynamic> m) {
    final type = m['type'];
    if (type == 1) {
      if (!_events.isClosed) {
        _events.add({
          'target': m['target']?.toString() ?? '',
          'args': m['arguments'] ?? const [],
        });
      }
    } else if (type == 7) {
      // Close — سرور اتصال را بست (مثلاً نبود مجوز)
      _setReady(false);
      if (!_closedByApp) _scheduleReconnect();
    }
  }

  Timer? _retry;
  void _scheduleReconnect() {
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 20), () async {
      if (_closedByApp) return;
      if (_ready) return;
      await connect(token: _lastToken);
    });
  }

  String? _lastToken;
  String? _lastBase;

  /// اتصال با نگه‌داشتن توکن برای تلاش مجدد خودکار.
  Future<bool> connectWithToken(String baseUrl, String token) {
    _lastToken = token;
    _lastBase = baseUrl;
    return connect(token: token);
  }

  String get _baseUrlOrLast =>
      _lastBase == null || _lastBase!.isEmpty ? _baseUrl : _lastBase!;

  /// «بررسی فوری» — همان دکمهٔ وب (`RequestHardwareCheck`)
  void requestHardwareCheck() =>
      _sendRaw({'type': 1, 'target': 'RequestHardwareCheck', 'arguments': []});

  /// درخواست ارسال وضعیت فعلی از سرور (Hub: `RequestHardwareStats`)
  void requestStats() =>
      _sendRaw({'type': 1, 'target': 'RequestStats', 'arguments': []});

  String get effectiveBaseUrl => _baseUrlOrLast;

  Future<void> disconnect() async {
    _closedByApp = true;
    _retry?.cancel();
    _ping?.cancel();
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setReady(false);
  }

  void dispose() {
    disconnect();
    _events.close();
    _state.close();
  }
}
