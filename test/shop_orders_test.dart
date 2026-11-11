// آزمون فاز ۳ «سامانه فروشگاهی» — مدل سند فروش/خرید و منطق پرداخت ترکیبی
// تضمین می‌کند فیلدها و قواعد عیناً مثل DTOهای سرور و OrderForm.razor وب باشند.

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/shop/data/order_calc.dart';
import 'package:forough_mobile/features/shop/models/order_models.dart';
import 'package:forough_mobile/features/shop/models/shop_models.dart';

void main() {
  group('OrderLine', () {
    test('مبلغ سطر = مقدار×قیمت − تخفیف و از صفر کمتر نمی‌شود', () {
      final l = OrderLine(
        productId: 1,
        quantity: 2.5,
        price: 1000,
        discountAmount: 500,
        discountPercent: 20,
        discountIsAmount: true,
      );
      expect(l.total, 2000);
      final wide = OrderLine(productId: 1, quantity: 1, price: 100, discountAmount: 400);
      expect(wide.total, 0);
    });

    test('toInput فقط شش فیلد OrderLineInput را می‌فرستد', () {
      final l = OrderLine(
        id: 7,
        productId: 3,
        quantity: 1.25,
        price: 400,
        discountPercent: 5,
        discountAmount: 25,
        discountIsAmount: false,
      );
      expect(l.toInput().keys.toSet(), {
        'id',
        'productId',
        'quantity',
        'price',
        'discountPercent',
        'discountAmount',
        'discountIsAmount',
      });
      expect(l.toInput()['quantity'], 1.25);
    });

    test('fromJson فیلدهای سود/بهای تمام‌شده/پورسانت را می‌خواند', () {
      final l = OrderLine.fromJson({
        'id': 2,
        'productId': 9,
        'productName': 'روغن',
        'unit': 'لیتر',
        'quantity': 2,
        'price': 500,
        'discountPercent': 0,
        'discountAmount': 0,
        'discountIsAmount': false,
        'isService': false,
        'unitCost': 300,
        'profit': 400,
        'commission': 40,
      });
      expect(l.productName, 'روغن');
      expect(l.unitCost, 300);
      expect(l.profit, 400);
      expect(l.commission, 40);
      expect(l.total, 1000);
    });
  });

  group('ShopOrder', () {
    test('پاسخ کامل سرور (اقلام، چک، اقساط، سود) خوانده می‌شود', () {
      final o = ShopOrder.fromJson({
        'id': 12,
        'warehouseId': 1,
        'warehouseName': 'مرکزی',
        'partyId': 4,
        'partyName': 'آقای رضایی',
        'type': 2,
        'number': 'S-1404-000012',
        'date': '2026-02-01T09:30:00',
        'description': 'فروش نقدی',
        'lines': [
          {'id': 1, 'productId': 5, 'quantity': 3, 'price': 1000},
        ],
        'totalAmount': 3000,
        'referrerId': 2,
        'referrerName': 'معرف الف',
        'totalProfit': 900,
        'commissionAmount': 90,
        'netProfit': 810,
        'paymentMethod': 4,
        'cashType': 0,
        'cashAmount': 1000,
        'trsAccountId': 3,
        'trsAccountName': 'بانک ملت — جاری',
        'dueDate': '2026-03-01T00:00:00',
        'settledAmount': 0,
        'cheques': [
          {
            'id': 1,
            'number': '123456',
            'bankName': 'ملت',
            'ownerName': 'رضایی',
            'amount': 1000,
            'dueDate': '2026-03-05T00:00:00',
            'isCleared': false,
          },
        ],
        'installments': [
          {'id': 1, 'no': 1, 'amount': 1000, 'dueDate': '2026-04-05T00:00:00', 'isPaid': false},
        ],
        'isPosted': true,
        'canDelete': true,
      });
      expect(o.number, 'S-1404-000012');
      expect(o.isSale, isTrue);
      expect(o.isPurchase, isFalse);
      expect(o.lines.single.total, 3000);
      expect(o.cheques.single.number, '123456');
      expect(o.installments.single.no, 1);
      expect(o.totalProfit, 900);
      expect(o.netProfit, 810);
      expect(o.trsAccountName, 'بانک ملت — جاری');
      expect(o.payLabel, 'ترکیبی');
    });

    test('برچسب پرداخت همان PayBadge وب است', () {
      String label(int m) => ShopOrder(paymentMethod: m).payLabel;
      expect(label(PayMethod.cash), 'نقدی');
      expect(label(PayMethod.credit), 'نسیه');
      expect(label(PayMethod.cheque), 'چک');
      expect(label(PayMethod.installment), 'اقساطی');
      expect(label(PayMethod.mixed), 'ترکیبی');
    });
  });

  group('PaymentMethod اعلامی — DeclaredMethod وب', () {
    test('بدون جزء غیرنقدی = نقدی', () {
      expect(
        OrderCalc.declaredMethod(
          useCheque: false,
          useInstallment: false,
          useCredit: false,
        ),
        PayMethod.cash,
      );
    });
    test('اولویت چک → اقساط → نسیه', () {
      expect(
        OrderCalc.declaredMethod(
          useCheque: true,
          useInstallment: true,
          useCredit: true,
        ),
        PayMethod.cheque,
      );
      expect(
        OrderCalc.declaredMethod(
          useCheque: false,
          useInstallment: true,
          useCredit: true,
        ),
        PayMethod.installment,
      );
      expect(
        OrderCalc.declaredMethod(
          useCheque: false,
          useInstallment: false,
          useCredit: true,
        ),
        PayMethod.credit,
      );
    });
  });

  group('پرداخت ترکیبی', () {
    test('اگر جزء غیرنقدی فعال نباشد تمام مبلغ نقدی است', () {
      expect(
        OrderCalc.cashPart(grandTotal: 5000, cashText: 0, hasNonCash: false),
        5000,
      );
      expect(
        OrderCalc.cashPart(grandTotal: 5000, cashText: 1200, hasNonCash: true),
        1200,
      );
    });

    test('باقی‌ماندهٔ نهایی = مبلغ سند − نقد − چک − اقساط', () {
      expect(
        OrderCalc.finalRemaining(
          grandTotal: 10000,
          cash: 2000,
          chequeSum: 3000,
          instSum: 3500,
        ),
        1500,
      );
    });

    test('مازاد پرداخت منفی برمی‌گردد (سود مدت‌دار)', () {
      expect(
        OrderCalc.finalRemaining(
          grandTotal: 1000,
          cash: 1000,
          chequeSum: 500,
          instSum: 0,
        ),
        -500,
      );
    });
  });

  group('BuildInstallments — همان فرمول وب', () {
    test('تقسیم مساوی با قسط آخرِ اصلاح‌شده', () {
      final list = OrderCalc.buildInstallments(totalDue: 1000, count: 3);
      expect(list, [333, 333, 334]);
      expect(list.reduce((a, b) => a + b), 1000);
    });

    test('مبلغ صفر یا تعداد نامعتبر → بدون قسط', () {
      expect(OrderCalc.buildInstallments(totalDue: 0, count: 3), isEmpty);
      expect(OrderCalc.buildInstallments(totalDue: 900, count: 0), isEmpty);
    });

    test('یک قسط = تمام مبلغ', () {
      expect(OrderCalc.buildInstallments(totalDue: 777, count: 1), [777]);
    });
  });

  group('محاسبهٔ اقساط با سود', () {
    test('سود سادهٔ ماهانه', () {
      expect(
        OrderCalc.interest(base: 1000, monthlyPercent: 2, months: 3),
        60,
      );
    });
    test('بدون سود یا بدون مبلغ → صفر', () {
      expect(OrderCalc.interest(base: 1000, monthlyPercent: 0, months: 3), 0);
      expect(OrderCalc.interest(base: 0, monthlyPercent: 2, months: 3), 0);
    });
  });

  group('Referrer', () {
    test('درصد پورسانت کالا و خدمات خوانده می‌شود', () {
      final r = Referrer.fromJson({
        'id': 3,
        'name': 'معرف',
        'companyName': 'شرکت',
        'goodsCommissionPercent': 5,
        'serviceCommissionPercent': 10,
      });
      expect(r.goodsCommissionPercent, 5);
      expect(r.serviceCommissionPercent, 10);
      expect(r.label, 'معرف (شرکت)');
    });
  });
}
