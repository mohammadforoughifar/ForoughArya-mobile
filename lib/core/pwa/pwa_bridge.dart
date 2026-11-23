// ============================================================
//  پل یکپارچهٔ iPhone / iOS Safari PWA و اعلان وب (VAPID / APNs Web Push)
//
//  متصل به کنترلر سرور موجود (`NotificationsController.cs` و `PushService.cs`):
//    • GET  /api/notifications/push-vapid-key
//    • POST /api/notifications/push-subscribe   (پشتیبانی رسمی از web.push.apple.com)
//    • POST /api/notifications/push-unsubscribe
//    • POST /api/notifications/push-status
//    • POST /api/notifications/test-push
// ============================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'pwa_bridge_stub.dart'
    if (dart.library.js_interop) 'pwa_bridge_web.dart';

class PwaServerSeed {
  const PwaServerSeed({
    required this.name,
    required this.endpoints,
  });

  final String name;
  final List<({String label, String url})> endpoints;
}

class PwaRuntimeConfig {
  const PwaRuntimeConfig({
    this.apiBaseUrl = '',
    this.autoSameOrigin = true,
    this.serverSeeds = const [],
  });

  final String apiBaseUrl;
  final bool autoSameOrigin;
  final List<PwaServerSeed> serverSeeds;
}

class PwaEnvironment {
  const PwaEnvironment({
    this.isWeb = false,
    this.isIos = false,
    this.isIpad = false,
    this.isSafari = false,
    this.isStandalone = false,
    this.isInAppBrowser = false,
    this.isSecureContext = true,
    this.isOnline = true,
    this.pushSupported = false,
    this.permission = 'default',
    this.iosMajor = 0,
    this.origin = '',
  });

  final bool isWeb;
  final bool isIos;
  final bool isIpad;
  final bool isSafari;
  final bool isStandalone;
  final bool isInAppBrowser;
  final bool isSecureContext;
  final bool isOnline;
  final bool pushSupported;
  final String permission;
  final int iosMajor;
  final String origin;

  bool get needsIosHomeScreenForPush => isIos && !isStandalone;
}

class PwaPushStatus {
  const PwaPushStatus({
    this.supported = false,
    this.enabled = false,
    this.denied = false,
    this.insecureOrigin = false,
    this.needsStandaloneIos = false,
    this.message = '',
  });

  factory PwaPushStatus.fromJson(Map<String, dynamic> j) => PwaPushStatus(
    supported: j['supported'] == true,
    enabled: j['enabled'] == true,
    denied: j['denied'] == true,
    insecureOrigin: j['insecureOrigin'] == true,
    needsStandaloneIos: j['needsStandaloneIos'] == true,
    message: (j['message'] ?? '').toString(),
  );

  final bool supported;
  final bool enabled;
  final bool denied;
  final bool insecureOrigin;
  final bool needsStandaloneIos;
  final String message;
}

class PwaBridge {
  PwaBridge._();
  static final PwaBridge instance = PwaBridge._();

  PwaRuntimeConfig readRuntimeConfig() {
    if (!kIsWeb) return const PwaRuntimeConfig();
    try {
      final raw = jsonDecode(platformReadConfigJson());
      if (raw is! Map) return const PwaRuntimeConfig();
      final seeds = <PwaServerSeed>[];
      final rawProfiles = raw['serverProfiles'];
      if (rawProfiles is List) {
        for (final item in rawProfiles) {
          if (item is! Map) continue;
          final eps = <({String label, String url})>[];
          final rawEps = item['endpoints'];
          if (rawEps is List) {
            for (final ep in rawEps) {
              if (ep is Map) {
                final u = (ep['url'] ?? '').toString().trim();
                if (u.isNotEmpty) {
                  eps.add((
                    label: (ep['label'] ?? 'آدرس سرور').toString(),
                    url: u,
                  ));
                }
              }
            }
          }
          if (eps.isNotEmpty) {
            seeds.add(PwaServerSeed(
              name: (item['name'] ?? 'سرور سازمانی').toString(),
              endpoints: eps,
            ));
          }
        }
      }
      return PwaRuntimeConfig(
        apiBaseUrl: (raw['apiBaseUrl'] ?? '').toString().trim(),
        autoSameOrigin: raw['autoSameOrigin'] != false,
        serverSeeds: seeds,
      );
    } catch (_) {
      return const PwaRuntimeConfig();
    }
  }

  PwaEnvironment environment() {
    if (!kIsWeb) return const PwaEnvironment();
    try {
      final raw = jsonDecode(platformReadEnvironmentJson());
      if (raw is! Map) return const PwaEnvironment(isWeb: true);
      return PwaEnvironment(
        isWeb: true,
        isIos: raw['isIos'] == true,
        isIpad: raw['isIpad'] == true,
        isSafari: raw['isSafari'] == true,
        isStandalone: raw['isStandalone'] == true,
        isInAppBrowser: raw['isInAppBrowser'] == true,
        isSecureContext: raw['isSecureContext'] != false,
        isOnline: raw['isOnline'] != false,
        pushSupported: raw['pushSupported'] == true,
        permission: (raw['permission'] ?? 'default').toString(),
        iosMajor: (raw['iosMajor'] as num?)?.toInt() ?? 0,
        origin: (raw['origin'] ?? '').toString(),
      );
    } catch (_) {
      return const PwaEnvironment(isWeb: true);
    }
  }

  /// تشخیص هوشمند آدرس پیش‌فرض سرور وقتی کاربر هنوز آدرسی ذخیره نکرده است.
  String? resolveDefaultWebServerUrl() {
    if (!kIsWeb) return null;
    final cfg = readRuntimeConfig();
    if (cfg.apiBaseUrl.isNotEmpty) return cfg.apiBaseUrl;
    if (!cfg.autoSameOrigin) return null;
    final base = Uri.base;
    if ((base.scheme == 'http' || base.scheme == 'https') &&
        base.host.isNotEmpty) {
      return base.origin;
    }
    return null;
  }

  Future<PwaPushStatus> _runPush(
    String action, {
    required String apiBaseUrl,
    required String token,
    int userId = 0,
    int? companyId,
  }) async {
    if (!kIsWeb) {
      return const PwaPushStatus(
        supported: false,
        message: 'فقط در نسخهٔ وب/PWA فعال است.',
      );
    }
    try {
      final raw = await platformPushActionJson(
        action,
        apiBaseUrl,
        token,
        userId,
        companyId ?? 0,
      );
      final map = jsonDecode(raw);
      if (map is Map) {
        return PwaPushStatus.fromJson(Map<String, dynamic>.from(map));
      }
    } catch (_) {}
    return const PwaPushStatus(
      supported: false,
      message: 'خطا در بررسی وضعیت اعلان وب.',
    );
  }

  Future<PwaPushStatus> pushState({
    required String apiBaseUrl,
    required String token,
    required int userId,
    int? companyId,
  }) => _runPush(
    'state',
    apiBaseUrl: apiBaseUrl,
    token: token,
    userId: userId,
    companyId: companyId,
  );

  Future<PwaPushStatus> enablePush({
    required String apiBaseUrl,
    required String token,
    required int userId,
    int? companyId,
  }) => _runPush(
    'enable',
    apiBaseUrl: apiBaseUrl,
    token: token,
    userId: userId,
    companyId: companyId,
  );

  Future<PwaPushStatus> disablePush({
    required String apiBaseUrl,
    required String token,
    int? companyId,
  }) => _runPush(
    'disable',
    apiBaseUrl: apiBaseUrl,
    token: token,
    companyId: companyId,
  );

  Future<PwaPushStatus> testPush({
    required String apiBaseUrl,
    required String token,
    int? companyId,
  }) => _runPush(
    'test',
    apiBaseUrl: apiBaseUrl,
    token: token,
    companyId: companyId,
  );

  void setAppBadge(int count) {
    if (!kIsWeb) return;
    platformSetAppBadge(count < 0 ? 0 : count);
  }

  Future<bool> checkForUpdates() async {
    if (!kIsWeb) return false;
    return platformUpdatePwa();
  }

  void showInstallBanner() {
    if (!kIsWeb) return;
    platformShowIosInstallBanner();
  }
}
