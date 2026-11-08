import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/auth/auth_session.dart';
import 'package:forough_mobile/core/utils/fa.dart';
import 'package:forough_mobile/features/work_orders/models/work_order.dart';

void main() {
  test('auth session maps roles and permissions', () {
    final session = AuthSession.fromJson({
      'userId': 5,
      'token': 'jwt',
      'username': 'operator',
      'displayName': 'اپراتور',
      'role': 'Operator',
      'roleNames': ['کارشناس'],
      'permissions': ['WorkOrders.View', 'WorkOrders.Create'],
    });
    expect(session.userId, 5);
    expect(session.has('WorkOrders.View'), isTrue);
    expect(session.has('WorkOrders.Delete'), isFalse);
  });

  test('paged response and assignee decision are decoded', () {
    final page = WorkOrderPageData.fromJson({
      'totalCount': 21,
      'page': 1,
      'pageSize': 20,
      'items': [
        {
          'id': 1,
          'number': 'WO-1',
          'title': 'تست',
          'status': 'Open',
          'assignees': [
            {'id': 8, 'userId': 2, 'name': 'گیرنده', 'ownerDecision': 'Rejected'}
          ]
        }
      ]
    });
    expect(page.pages, 2);
    expect(page.items.single.assignees.single.ownerDecision, 'Rejected');
  });

  test('Persian digits and labels are stable', () {
    expect(Fa.digits('1405/08/15'), '۱۴۰۵/۰۸/۱۵');
    expect(Fa.priority(3), 'فوری');
    expect(Fa.recurrence(2), 'هفتگی');
  });
}
