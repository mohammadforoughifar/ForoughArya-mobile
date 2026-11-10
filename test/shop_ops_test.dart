// آزمون فاز ۴ «سامانه فروشگاهی» — بیجک، تعمیرات، هزینه‌ها و گزارش‌ها
// تضمین می‌کند فیلدها و قواعد عیناً مثل DTOهای سرور و صفحات وب باشند.

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/shop/models/ops_models.dart';
import 'package:forough_mobile/features/shop/models/order_models.dart';

void main() {
  group('GoodsIssue', () {
    test('سطرهای حواله و جمع مقدار خوانده می‌شود', () {
      final g = GoodsIssue.fromJson({
        'id': 4,
        'number': 'GI-1404-000004',
        'date': '2026-02-01T08:00:00',
        'partyId': 9,
        'partyName': 'آقای احمدی',
        'description': 'تحویل با پیک',
        'lines': [
          {'id': 1, 'productId': 0, 'productName': 'کابل HDMI', 'quantity': 2},
          {'id': 2, 'productId': 0, 'productName': 'ماوس', 'quantity': 3.5},
        ],
      });
      expect(g.number, 'GI-1404-000004');
      expect(g.lineCount, 2);
      expect(g.totalQuantity, 5.5);
      expect(g.lines.first.productName, 'کابل HDMI');
    });

    test('toJson سطر فقط همان چهار فیلد سرور را می‌فرستد', () {
      final l = GoodsIssueLine(productName: ' کابل ', quantity: 1);
      expect(l.toJson().keys.toSet(), {
        'id',
        'productId',
        'productName',
        'quantity',
        'note',
      });
      expect(l.toJson()['productName'], 'کابل');
    });
  });

  group('RepairOrder', () {
    RepairOrder sample() => RepairOrder.fromJson({
      'id': 7,
      'number': 'RP-1404-000007',
      'partyId': 3,
      'partyName': 'شرکت الف',
      'partyMobile': '09120000000',
      'partyPhone': '02100000000',
      'technicianId': 2,
      'technicianName': 'استاد کریمی',
      'status': 1,
      'receivedAt': '2026-02-01T09:00:00',
      'deliveredAt': null,
      'note': 'فوری',
      'devices': [
        {
          'id': 1,
          'deviceType': 'لپ‌تاپ',
          'deviceModel': 'Lenovo T480',
          'serialNumber': 'SN1',
          'problemDescription': 'روشن نمی‌شود',
          'accessories': 'شارژر',
          'quotedPrice': 1500000,
        },
        {'id': 2, 'deviceType': 'پرینتر', 'quotedPrice': 500000},
      ],
      'items': [
        {
          'id': 1,
          'description': 'تعویض باتری',
          'productId': 5,
          'productName': 'باتری',
          'quantity': 2,
          'cost': 100000,
          'price': 200000,
        },
      ],
      'totalPrice': 400000,
      'totalCost': 200000,
      'profit': 200000,
    });

    test('دستگاه‌ها، ردیف‌ها و جمع‌ها خوانده می‌شود', () {
      final r = sample();
      expect(r.devices.length, 2);
      expect(r.devices.first.quotedPrice, 1500000);
      expect(r.items.single.rowCost, 200000);
      expect(r.items.single.rowPrice, 400000);
      expect(r.items.single.rowProfit, 200000);
      expect(r.profit, 200000);
      expect(r.hasInvoice, isFalse);
    });

    test('خلاصهٔ دستگاه و تلفن — همان منطق DeviceSummary وب', () {
      final r = sample();
      expect(r.deviceSummary, 'لپ‌تاپ Lenovo T480 و 1 دستگاه');
      // وب: موبایل اولویت دارد
      expect(r.partyTel, '09120000000');
    });

    test('برچسب وضعیت‌ها همان StatusBadge وب است', () {
      expect(RepairStatus.label(0), 'پذیرش شده');
      expect(RepairStatus.label(1), 'در حال تعمیر');
      expect(RepairStatus.label(2), 'آماده تحویل');
      expect(RepairStatus.label(3), 'تحویل شده');
      expect(RepairStatus.label(4), 'انصراف');
    });

    test('toJson فیلدهای تخت کارت اول را هم می‌فرستد (سازگاری وب)', () {
      final j = sample().toJson();
      expect(j['deviceType'], 'لپ‌تاپ');
      expect(j['deviceModel'], 'Lenovo T480');
      // جمع برآورد دستگاه‌ها
      expect(j['quotedPrice'], 2000000);
      expect((j['devices'] as List).length, 2);
      expect((j['items'] as List).length, 1);
    });
  });

  group('RepairItem', () {
    test('productId صفر حذف می‌شود (اجرت بدون کالا)', () {
      final i = RepairItem(description: 'اجرت', quantity: 1, cost: 0, price: 500);
      expect(i.toJson()['productId'], isNull);
    });
  });

  group('ShopExpense', () {
    test('سند هزینه با نام نوع و حساب خوانده می‌شود', () {
      final e = ShopExpense.fromJson({
        'id': 3,
        'number': 'EX-1404-000003',
        'categoryId': 2,
        'categoryName': 'اجاره',
        'amount': 5000000,
        'date': '2026-02-01T10:00:00',
        'payType': 1,
        'trsAccountId': 4,
        'trsAccountName': 'بانک ملت — جاری',
        'payee': 'موجر',
        'description': 'اجارهٔ بهمن',
      });
      expect(e.categoryName, 'اجاره');
      expect(e.amount, 5000000);
      expect(e.payType, CashKind.cardReader);
      expect(e.trsAccountName, 'بانک ملت — جاری');
    });

    test('toJson همان ExpenseDto را می‌سازد', () {
      final j = ShopExpense(
        categoryId: 1,
        amount: 100,
        date: DateTime(2026, 1, 1),
        payType: 0,
        payee: 'برق',
      ).toJson();
      expect(j['categoryId'], 1);
      expect(j['amount'], 100);
      expect(j['payType'], 0);
      expect(j.containsKey('number'), isFalse);
    });
  });

  group('گزارش خرید/فروش', () {
    test('شاخص‌ها، روند و رتبه‌بندی طرف حساب خوانده می‌شود', () {
      final r = OrderReport.fromJson({
        'documentCount': 12,
        'lineCount': 30,
        'totalQuantity': 45.5,
        'totalAmount': 9000000,
        'averageDocumentAmount': 750000,
        'trend': [
          {'label': 'هفته ۱', 'documentCount': 5, 'amount': 4000000},
          {'label': 'هفته ۲', 'documentCount': 7, 'amount': 5000000},
        ],
        'topParties': [
          {
            'partyId': 1,
            'partyName': 'مشتری الف',
            'documentCount': 4,
            'totalQuantity': 10,
            'totalAmount': 6000000,
          },
        ],
      });
      expect(r.documentCount, 12);
      expect(r.totalAmount, 9000000);
      expect(r.trend.length, 2);
      expect(r.trend.last.amount, 5000000);
      expect(r.topParties.single.partyName, 'مشتری الف');
    });
  });

  group('داشبورد عملیات', () {
    test('شاخص‌های تعمیرات و حاشیهٔ سود', () {
      final d = OpsDashboard.fromJson({
        'purchaseCount': 3,
        'purchaseTotal': 1000,
        'saleCount': 4,
        'saleTotal': 2000,
        'repairRevenue': 1000,
        'repairCost': 700,
        'repairPartsCost': 400,
        'repairLaborCost': 300,
        'repairProfit': 300,
        'repairCount': 5,
        'openRepairCount': 2,
        'deliveredRepairCount': 3,
        'cancelledRepairCount': 0,
        'averageRepairTurnaroundDays': 2.5,
        'bestReferrer': {
          'referrerId': 1,
          'referrerName': 'معرف الف',
          'saleCount': 2,
          'salesAmount': 1500,
        },
        'trend': [
          {
            'label': 'هفته ۱',
            'purchase': 500,
            'sale': 900,
            'repairRevenue': 400,
            'repairCost': 300,
            'repairProfit': 100,
          },
        ],
      });
      expect(d.repairProfit, 300);
      expect(d.averageRepairTurnaroundDays, 2.5);
      expect(d.bestReferrer?.referrerName, 'معرف الف');
      expect(d.trend.single.sale, 900);
      // ۳۰۰ / ۱۰۰۰ × ۱۰۰
      expect(d.repairMargin, closeTo(30, 0.001));
    });

    test('بدون درآمد، حاشیهٔ سود صفر است', () {
      expect(const OpsDashboard().repairMargin, 0);
    });
  });

  group('Technician / ExpenseCategory', () {
    test('تعمیرکار و نوع هزینه', () {
      final t = Technician.fromJson({
        'id': 2,
        'name': 'استاد کریمی',
        'phone': '0912',
        'specialty': 'لپ‌تاپ',
        'isActive': true,
        'activeRepairs': 3,
      });
      expect(t.specialty, 'لپ‌تاپ');
      expect(t.activeRepairs, 3);

      final c = ExpenseCategory.fromJson({
        'id': 5,
        'name': 'اجاره',
        'isActive': false,
        'expenseCount': 4,
        'totalAmount': 900,
      });
      expect(c.isActive, isFalse);
      expect(c.expenseCount, 4);
      expect(c.copyWith(isActive: true).isActive, isTrue);
    });
  });
}
