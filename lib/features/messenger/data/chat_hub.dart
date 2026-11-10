// ============================================================
//  اتصال زندهٔ چت (SignalR)
//
//  سرور شما چت را realtime سرو می‌کند (SignalR). پیاده‌سازی پروتکل
//  SignalR JSON در این فایل است:
//    • ابتدا POST  {hub}/negotiate?negotiateVersion=1
//        - اگر connectionToken برگرداند: transport=WebSockets با
//          آدرس ?id=<token>
//        - اگر خالی بود (Negotiation=false روی سرور): مستقیم ws
//    • سپس فریم‌های JSON با \u001e جدا می‌شوند
//    • Handshake: {"protocol":"json","version":1}
//    • Invoke: {"type":1,"target":"SendMessage","arguments":[...]}
//    • دریافت: {"type":1,"target":"ReceiveMessage","arguments":[...]}
//
//  نام‌های target قابل تغییر است (لیست [sendTargets]) تا با هر
//  نامی که سرور گذاشته کار کند.
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatHub {
  ChatHub(this._dio, this._baseUrl);

  final Dio _dio;
  final String _baseUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _ping;
  bool _ready = false;

  /// رویدادهای دریافتی: {target, args}
  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isReady => _ready;

  /// نام‌های احتمالی متد ارسال پیام — اولین موفق استفاده می‌شود.
  static const sendTextTargets = <String>[
    'SendMessage',
    'SendChatMessage',
    'Send',
    'PostMessage',
    'SendText',
  ];

  static const sendVoiceTargets = <String>[
    'SendVoice',
    'SendAudio',
    'SendVoiceMessage',
    'UploadVoice',
  ];

  /// تلاش برای اتصال به hub؛ اگر آدرس کار نکند null برمی‌گردد.
  Future<bool> connect(String hubPath, {String? token}) async {
    await disconnect();
    final httpBase = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final hubHttp = '$httpBase$hubPath';

    Uri? wsUri;
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
      // سرور Negotiate ندارد → اتصال مستقیم
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
        onError: (_) => _ready = false,
        onDone: () => _ready = false,
      );

      // handshake
      _sendRaw({'protocol': 'json', 'version': 1});
      // پینگ دوره‌ای برای زنده نگه‌داشتن
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 15), (_) {
        _sendRaw({'type': 6});
      });
      _ready = true;
      return true;
    } catch (_) {
      _ready = false;
      return false;
    }
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
      // Invocation
      _events.add({
        'target': m['target']?.toString() ?? '',
        'args': m['arguments'] ?? const [],
      });
    } else if (type == 3) {
      // Completion
      _events.add({'target': '__completion', 'args': m});
    } else if (type == 7) {
      _events.add({'target': '__close', 'args': const []});
      _ready = false;
    }
  }

  /// فراخوانی متد روی hub (بدون انتظار برای نتیجهٔ سرور)
  void invoke(String target, List<dynamic> args) {
    if (!_ready) return;
    _sendRaw({'type': 1, 'target': target, 'arguments': args});
  }

  /// فراخوانی و انتظار نتیجه (برای هندشیک/ورود به گروه)
  Future<Map<String, dynamic>?> invokeAndWait(
    String target,
    List<dynamic> args, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!_ready) return null;
    final invocationId = DateTime.now().microsecondsSinceEpoch.toString();
    final done = Completer<Map<String, dynamic>>();
    late StreamSubscription<Map<String, dynamic>> sub;
    sub = events.listen((e) {
      if (e['target'] == '__completion') {
        final payload = e['args'];
        if (payload is Map && payload['id'] == invocationId && !done.isCompleted) {
          done.complete(Map<String, dynamic>.from(payload));
        }
      }
    });
    _sendRaw({
      'type': 1,
      'invocationId': invocationId,
      'target': target,
      'arguments': args,
    });
    try {
      return await done.future.timeout(timeout);
    } catch (_) {
      return null;
    } finally {
      await sub.cancel();
    }
  }

  Future<void> disconnect() async {
    _ping?.cancel();
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _ready = false;
  }
}
