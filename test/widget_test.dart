import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/work_orders/models/work_order.dart';

void main() {
  test('work order JSON model reads backend fields', () {
    final order = WorkOrder.fromJson({
      'id': 12,
      'number': 'WO-12',
      'title': 'بررسی سرور',
      'status': 'Open',
      'priority': 3,
      'assignees': [
        {
          'id': 2,
          'userId': 4,
          'name': 'کاربر تست',
          'ownerDecision': 'Approved',
        },
      ],
      'tags': ['فوری'],
    });
    expect(order.id, 12);
    expect(order.isOpen, isTrue);
    expect(order.assignees.single.ownerDecision, 'Approved');
    expect(order.tags, contains('فوری'));
  });
}
