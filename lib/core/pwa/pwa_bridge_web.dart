import 'dart:js_interop';

@JS('foroughReadRuntimeConfigJson')
external JSString? _jsReadRuntimeConfigJson();

@JS('foroughReadEnvironmentJson')
external JSString? _jsReadEnvironmentJson();

@JS('foroughPushActionJson')
external JSPromise<JSString>? _jsPushActionJson(
  JSString action,
  JSString root,
  JSString token,
  JSNumber userId,
  JSNumber companyId,
);

@JS('foroughSetAppBadge')
external void _jsSetAppBadge(JSNumber count);

@JS('foroughUpdatePwa')
external JSPromise<JSBoolean>? _jsUpdatePwa();

@JS('foroughShowInstallBanner')
external void _jsShowInstallBanner();

String platformReadConfigJson() {
  try {
    return _jsReadRuntimeConfigJson()?.toDart ?? '{}';
  } catch (_) {
    return '{}';
  }
}

String platformReadEnvironmentJson() {
  try {
    return _jsReadEnvironmentJson()?.toDart ?? '{}';
  } catch (_) {
    return '{}';
  }
}

Future<String> platformPushActionJson(
  String action,
  String root,
  String token,
  int userId,
  int companyId,
) async {
  try {
    final promise = _jsPushActionJson(
      action.toJS,
      root.toJS,
      token.toJS,
      userId.toJS,
      companyId.toJS,
    );
    if (promise == null) {
      return '{"supported":false,"enabled":false,"message":"پل ارتباطی اعلان در مرورگر آماده نیست."}';
    }
    final res = await promise.toDart;
    return res.toDart;
  } catch (e) {
    return '{"supported":false,"enabled":false,"message":"خطا در ارتباط با سرویس اعلان مرورگر"}';
  }
}

void platformSetAppBadge(int count) {
  try {
    _jsSetAppBadge(count.toJS);
  } catch (_) {}
}

Future<bool> platformUpdatePwa() async {
  try {
    final p = _jsUpdatePwa();
    if (p == null) return false;
    final res = await p.toDart;
    return res.toDart;
  } catch (_) {
    return false;
  }
}

void platformShowIosInstallBanner() {
  try {
    _jsShowInstallBanner();
  } catch (_) {}
}
