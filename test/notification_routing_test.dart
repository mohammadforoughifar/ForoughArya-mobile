// ============================================================
//  تست مسیریابی اعلان: شناسهٔ رکورد مقصد باید استخراج شود تا کلیک روی
//  اعلان، خودِ همان دستور کار / صورت‌جلسه / نامه را باز کند.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/home/models/home_models.dart';

void main() {
  test('شناسه از کلیدهای صریح', () {
    expect(parseEntityId({'workOrderId': 42}), 42);
    expect(parseEntityId({'minutesId': '7'}), 7);
    expect(parseEntityId({'entityId': 9}), 9);
  });

  test('شناسه از انتهای link', () {
    expect(parseEntityId({'link': '/workorders/315'}), 315);
    expect(parseEntityId({'link': '/meeting-minutes/88'}), 88);
    expect(parseEntityId({'link': '/letters/12?tab=inbox'}), 12);
    expect(parseEntityId({'link': '/x?erjaId=5&id=6'}), 5);
  });

  test('نوع مقصد از متن اعلان', () {
    expect(
      parseEntityKind({'title': 'دستور کار جدید برای شما'}),
      'wo',
    );
    expect(
      parseEntityKind({'title': 'صورت‌جلسهٔ جلسهٔ فنی'}),
      'minutes',
    );
    expect(
      parseEntityKind({'formName': 'کارتابل نامهٔ داخلی', 'body': 'ارجاع شد'}),
      'letter',
    );
    expect(parseEntityKind({'title': 'ایمیل تازه'}), 'email');
  });

  test('NotificationItem شناسه و نوع را نگه می‌دارد', () {
    final n = NotificationItem.fromJson({
      'id': 1,
      'title': 'ارجاع دستور کار',
      'link': '/workorders/77',
    });
    expect(n.entityId, 77);
    expect(n.entityKind, 'wo');
  });
}
