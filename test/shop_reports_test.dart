// آزمون فاز ۷ «سامانه فروشگاهی» — کاردکس (تعدادی/ریالی) و پنل معرف
// تضمین می‌کند فیلدها، جمع‌ها و متن‌های وضعیت عیناً آینهٔ DTOهای وب باشند.

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/shop/models/report_models.dart';

void main() {
  group('KardexRow (کاردکس تعدادی)', () {
    test('نوع سند مثل TransactionType وب عنوان‌گذاری می‌شود', () {
      expect(KardexRow(date: DateTime(2026, 1, 1), type: 1).typeTitle, 'خرید');
      expect(KardexRow(date: DateTime(2026, 1, 1), type: 2).typeTitle, 'فروش');
      expect(
        KardexRow(date: DateTime(2026, 1, 1), type: 0).typeTitle,
        'اصلاح موجودی',
      );
    });

    test('fromJson سطر تعدادی را می‌خواند', () {
      final r = KardexRow.fromJson({
        'date': '2026-11-01T09:30:00Z',
        'type': 2,
        'documentNo': '1001',
        'partyName': 'فروشگاه آریا',
        'description': 'فاکتور فروش',
        'inQty': 0,
        'outQty': 4.5,
        'balance': 10.5,
        'unitPrice': 90000,
      });
      expect(r.documentNo, '1001');
      expect(r.typeTitle, 'فروش');
      expect(r.outQty, 4.5);
      expect(r.balance, 10.5);
      expect(r.partyName, 'فروشگاه آریا');
    });

    test('balance سرور (بدون balanceQty) هم خوانده می‌شود', () {
      final r = KardexRow.fromJson({'balance': 7});
      expect(r.balance, 7);
      expect(r.balanceQty, 0);
    });
  });

  group('KardexQuantityResult', () {
    test('جمع‌ها از سطرها محاسبه می‌شوند', () {
      final r1 = KardexRow(date: DateTime(2026, 1, 1), inQty: 10, balance: 10);
      final r2 = KardexRow(date: DateTime(2026, 1, 2), outQty: 4, balance: 6);
      final res = KardexQuantityResult(productName: 'کابل', rows: [r1, r2]);
      expect(res.totalIn, 10);
      expect(res.totalOut, 4);
      expect(res.finalBalance, 6);
    });

    test('کاردکس خالی ماندهٔ صفر دارد', () {
      const res = KardexQuantityResult();
      expect(res.totalIn, 0);
      expect(res.totalOut, 0);
      expect(res.finalBalance, 0);
    });
  });

  group('KardexRialResult', () {
    test('fromJson خروجی کامل کاردکس ریالی', () {
      final r = KardexRialResult.fromJson({
        'productId': 5,
        'productCode': 'P-5',
        'productName': 'کابل شبکه',
        'unit': 'متر',
        'warehouseName': 'انبار مرکزی',
        'methodTitle': 'میانگین موزون',
        'openingQty': 20,
        'openingValue': 1000000,
        'totalInQty': 10,
        'totalInValue': 600000,
        'totalOutQty': 8,
        'totalOutValue': 400000,
        'closingQty': 22,
        'closingValue': 1200000,
        'rows': [
          {
            'date': '2026-11-02T00:00:00Z',
            'type': 1,
            'documentNo': 'PO-1',
            'inQty': 10,
            'inPrice': 60000,
            'inValue': 600000,
            'balanceQty': 30,
            'balanceValue': 1600000,
          },
        ],
      });
      expect(r.productName, 'کابل شبکه');
      expect(r.methodTitle, 'میانگین موزون');
      expect(r.openingQty, 20);
      expect(r.closingValue, 1200000);
      expect(r.rows.single.inValue, 600000);
      expect(r.rows.single.balanceAvg, closeTo(53333.33, 0.1));
    });

    test('میانگین فی مانده با مقدار صفر امن است', () {
      final row = KardexRow(date: DateTime(2026, 1, 1), balanceValue: 500);
      expect(row.balanceAvg, 0);
    });
  });

  group('ReferrerDashboard (پنل معرف)', () {
    test('fromJson شاخص‌ها، فروش‌های اخیر و پرداخت‌ها', () {
      final d = ReferrerDashboard.fromJson({
        'referrerName': 'رضا کریمی',
        'companyName': 'بازاریابی کریمی',
        'phone': '09121111111',
        'canViewProducts': true,
        'goodsCommissionPercent': 5,
        'serviceCommissionPercent': 10,
        'orderCount': 12,
        'totalSales': 90000000,
        'totalCommission': 4500000,
        'totalPaid': 2000000,
        'walletBalance': 2500000,
        'monthCommission': 700000,
        'recentSales': [
          {
            'number': '1042',
            'date': '2026-11-01T00:00:00Z',
            'customerName': 'فروشگاه آریا',
            'amount': 1200000,
            'commission': 60000,
          },
        ],
        'recentPayments': [
          {
            'id': 3,
            'number': 'PAY-1',
            'amount': 500000,
            'description': 'واریز',
          },
        ],
      });
      expect(d.referrerName, 'رضا کریمی');
      expect(d.canViewProducts, isTrue);
      expect(d.walletBalance, 2500000);
      expect(d.monthCommission, 700000);
      expect(d.recentSales.single.commission, 60000);
      expect(d.recentPayments.single.number, 'PAY-1');
    });

    test('پیش‌فرض‌ها خالی و canViewProducts=false هستند', () {
      const d = ReferrerDashboard();
      expect(d.canViewProducts, isFalse);
      expect(d.recentSales, isEmpty);
      expect(d.walletBalance, 0);
    });
  });

  group('ReferrerProductItem / ReferrerPaymentRow', () {
    test('کالای موجود پنل معرف', () {
      final p = ReferrerProductItem.fromJson({
        'name': 'کابل شبکه',
        'code': 'P-5',
        'unit': 'متر',
        'category': 'شبکه',
        'inStock': true,
      });
      expect(p.name, 'کابل شبکه');
      expect(p.category, 'شبکه');
      expect(p.inStock, isTrue);
    });

    test('سند پرداخت پنل معرف', () {
      final p = ReferrerPaymentRow.fromJson({
        'id': 9,
        'number': 'PAY-1002',
        'date': '2026-11-03T00:00:00Z',
        'amount': 300000,
        'description': 'کارت به کارت',
      });
      expect(p.id, 9);
      expect(p.amount, 300000);
      expect(p.description, 'کارت به کارت');
    });
  });
}
