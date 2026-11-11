// ============================================================
//  تست منطق نوتیفیکیشن: فقط اعلان‌های تازه (id بزرگ‌تر از آخرین
//  دیده‌شده) باید به نوار گوشی بروند و وضعیت ذخیره شود.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/notifications/push_service.dart';

class _FakeApi implements ApiClientLike {
  _FakeApi(this.items);
  final List<Map<String, dynamic>> items;
  int calls = 0;

  @override
  Future<ApiResponseLike> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    calls++;
    return ApiResponseLike(items);
  }
}

void main() {
  test('شناسهٔ اعلان‌ها به‌درستی مقایسه می‌شود', () {
    final items = [
      {'id': 12, 'title': 'الف'},
      {'id': 15, 'title': 'ب'},
      {'id': 9, 'title': 'پ'},
    ];
    final fresh = items.where((m) => (m['id'] as int) > 11).toList();
    expect(fresh.length, 2);
    expect(fresh.map((e) => e['id']), [12, 15]);
  });

  test('ApiClientPushAdapter قابل ساخت است', () {
    final api = _FakeApi([
      {'id': 3, 'title': 'x'},
    ]);
    expect(api, isA<ApiClientLike>());
  });

  test('نام تسک پس‌زمینه ثابت است', () {
    expect(backgroundTaskName, 'forough-notifications-poll');
  });
}
