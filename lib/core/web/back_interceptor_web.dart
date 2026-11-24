import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

bool _registered = false;

/// دکمهٔ «بازگشت» مرورگر را مثل دکمهٔ بازگشت اندروید وارد ناوبری Flutter می‌کند.
///
/// شیم JS در `web/ios-pwa-helper.js` هر بک را می‌گیرد، یک گارد جدید در History
/// می‌گذارد (تا کاربر از اپ بیرون نرود) و رویداد `forough-back-pressed` را می‌فرستد.
/// اینجا همان رویداد را به `Navigator.maybePop()` وصل می‌کنیم:
/// صفحات جزئی one مرحله عقب می‌روند، دیالوگ‌ها بسته می‌شوند و در ریشه،
/// PopScope خانه دیالوگ «خروج از برنامه» را نشان می‌دهد.
void registerWebBackInterceptor(GlobalKey<NavigatorState> navigatorKey) {
  if (_registered) return;
  _registered = true;
  web.window.addEventListener(
    'forough-back-pressed',
    ((web.Event _) {
      navigatorKey.currentState?.maybePop();
    }).toJS,
  );
}
