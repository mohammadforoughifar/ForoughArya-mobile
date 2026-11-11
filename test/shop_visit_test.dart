// آزمون فاز ۶ «سامانه فروشگاهی» — فروش و ویزیتوری + معرف‌ها
// تضمین می‌کند مدل‌ها، نقشهٔ وضعیت، محاسبات تخفیف و قواعد وب عیناً آینه شوند.

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/shop/models/visit_models.dart';

void main() {
  group('VisStatus', () {
    test('عنوان‌ها دقیقاً مثل VisOrderStatus وب', () {
      expect(VisStatus.title(0), 'پیش‌نویس');
      expect(VisStatus.title(1), 'در انتظار تأیید');
      expect(VisStatus.title(2), 'تأییدشده');
      expect(VisStatus.title(3), 'برگشتی برای اصلاح');
      expect(VisStatus.title(4), 'رد‌شده');
      expect(VisStatus.title(5), 'فاکتورشده');
      expect(VisStatus.title(6), 'بسته‌شده');
      expect(VisStatus.title(7), 'ابطال‌شده');
    });

    test('ویرایش فقط پیش‌نویس/ارسال‌شده/برگشتی؛ ابطال همان سه (وب)', () {
      expect(VisStatus.canEdit(0), isTrue);
      expect(VisStatus.canEdit(1), isTrue);
      expect(VisStatus.canEdit(3), isTrue);
      expect(VisStatus.canEdit(2), isFalse);
      expect(VisStatus.canEdit(5), isFalse);
      expect(VisStatus.canCancel(0), isTrue);
      expect(VisStatus.canCancel(3), isTrue);
      expect(VisStatus.canCancel(1), isTrue);
      expect(VisStatus.canCancel(2), isFalse);
    });
  });

  group('VisLine', () {
    test('تخفیف ریالی از جمع سطر کم می‌شود و منفی نمی‌شود', () {
      final l = VisLine(
        quantity: 3,
        unitPrice: 100,
        discountAmount: 250,
        discountIsAmount: true,
      );
      expect(l.gross, 300);
      expect(l.computeTotal(), 50);

      final z = VisLine(
        quantity: 1,
        unitPrice: 100,
        discountAmount: 300,
        discountIsAmount: true,
      );
      expect(z.computeTotal(), 0);
    });

    test('تخفیف درصدی روی جمع سطر اعمال می‌شود', () {
      final l = VisLine(quantity: 2, unitPrice: 500, discountPercent: 10);
      expect(l.computeTotal(), 900);
      expect(l.discountText, '10٪');
    });

    test('متن تخفیف ریالی بر حسب ریال است (DiscountText وب)', () {
      final l = VisLine(discountAmount: 1234, discountIsAmount: true);
      expect(l.discountText, '1234 ریال');
    });

    test('fromJson فیلدهای سطر سرور را می‌خواند', () {
      final l = VisLine.fromJson({
        'id': 9,
        'productId': 44,
        'productCode': 'P-44',
        'productName': 'کابل شبکه',
        'unit': 'متر',
        'quantity': 12.5,
        'unitPrice': 80000,
        'discountPercent': 5,
        'lineTotal': 950000,
        'note': 'رنگ آبی',
      });
      expect(l.productId, 44);
      expect(l.quantity, 12.5);
      expect(l.lineTotal, 950000);
      expect(l.note, 'رنگ آبی');
      expect(l.toJson()['productId'], 44);
      expect(l.toJson()['quantity'], 12.5);
    });
  });

  group('VisOrder', () {
    test('روش پرداخت ویزیتوری: نقدی/نسیه/چک/اقساطی', () {
      expect(VisOrder(paymentMethod: 0).paymentMethodTitle, 'نقدی');
      expect(VisOrder(paymentMethod: 1).paymentMethodTitle, 'نسیه');
      expect(VisOrder(paymentMethod: 2).paymentMethodTitle, 'چک');
      expect(VisOrder(paymentMethod: 3).paymentMethodTitle, 'اقساطی');
    });

    test('تاریخ تحویل مؤثر و تشخیص تغییر تاریخ مدیر', () {
      final d1 = DateTime(2026, 5, 1);
      final d2 = DateTime(2026, 5, 6);
      final o = VisOrder(deliveryDate: d1, finalDeliveryDate: d2);
      expect(o.effectiveDeliveryDate, d2);
      expect(o.finalDateChanged, isTrue);

      final same = VisOrder(deliveryDate: d1, finalDeliveryDate: d1);
      expect(same.finalDateChanged, isFalse);

      final onlyV = VisOrder(deliveryDate: d1);
      expect(onlyV.effectiveDeliveryDate, d1);
      expect(onlyV.finalDateChanged, isFalse);
    });

    test('تعداد سطر و جمع مقدار', () {
      final o = VisOrder(
        lines: [
          VisLine(quantity: 2),
          VisLine(quantity: 3.5),
        ],
      );
      expect(o.lineCount, 2);
      expect(o.totalQuantity, 5.5);
    });

    test('fromJson سفارش کامل با سطر، گردش و هشدار کسری', () {
      final o = VisOrder.fromJson({
        'id': 12,
        'number': '1042',
        'date': '2026-11-01T08:00:00Z',
        'deliveryDate': '2026-11-05T00:00:00Z',
        'finalDeliveryDate': '2026-11-08T00:00:00Z',
        'referrerId': 7,
        'referrerName': 'رضا کریمی',
        'partyId': 31,
        'partyName': 'فروشگاه آریا',
        'partyMobile': '09120000000',
        'warehouseId': 2,
        'warehouseName': 'انبار مرکزی',
        'status': 1,
        'paymentMethod': 2,
        'totalGross': 1000,
        'totalDiscount': 100,
        'totalNet': 900,
        'note': 'تحویل صبح',
        'createdByName': 'رضا کریمی',
        'returnCount': 1,
        'discountOverLimit': true,
        'invoiceNumber': 0,
        'lines': [
          {'productId': 1, 'productName': 'کالا', 'quantity': 2, 'lineTotal': 900},
        ],
        'history': [
          {'toStatus': 1, 'userName': 'رضا کریمی'},
        ],
        'stockWarnings': [
          {'productId': 1, 'productName': 'کالا', 'required': 5, 'available': 2},
        ],
      });
      expect(o.id, 12);
      expect(o.statusTitle, 'در انتظار تأیید');
      expect(o.paymentMethodTitle, 'چک');
      expect(o.partyMobile, '09120000000');
      expect(o.returnCount, 1);
      expect(o.discountOverLimit, isTrue);
      expect(o.finalDateChanged, isTrue);
      expect(o.lines.single.lineTotal, 900);
      expect(o.history.single.toStatus, 1);
      expect(o.stockWarnings.single.shortage, 3);
    });
  });

  group('VisStockWarning', () {
    test('کسری = نیاز − موجودی (وب)', () {
      final w = VisStockWarning(required: 10, available: 4);
      expect(w.shortage, 6);
      expect(VisStockWarning(required: 2, available: 2).shortage, 0);
    });
  });

  group('VisActor', () {
    test('سقف تخفیف فقط برای غیرمدیر و بدون مجوز تأیید اعمال می‌شود', () {
      expect(
        VisActor(maxDiscountPercent: 10).enforcesDiscountCap,
        isTrue,
      );
      expect(
        VisActor(maxDiscountPercent: 10, canApprove: true).enforcesDiscountCap,
        isFalse,
      );
      expect(
        VisActor(maxDiscountPercent: 10, isAdmin: true).enforcesDiscountCap,
        isFalse,
      );
      expect(VisActor().enforcesDiscountCap, isFalse);
    });

    test('fromJson توان‌ها و شرکت جاری', () {
      final a = VisActor.fromJson({
        'userId': 5,
        'userName': 'مدیر فروش',
        'canCreate': true,
        'canApprove': true,
        'canFinance': false,
        'maxDiscountPercent': 0,
        'companyId': 2,
        'companyName': 'فروشگاه مرکزی',
        'warehouseCount': 3,
        'productCount': 120,
        'defaultWarehouseId': 4,
      });
      expect(a.canApprove, isTrue);
      expect(a.companyName, 'فروشگاه مرکزی');
      expect(a.warehouseCount, 3);
      expect(a.defaultWarehouseId, 4);
    });
  });

  group('VisApprovalItem', () {
    test('هشدار کسری و اعتبار روی ردیف صف تأیید', () {
      final it = VisApprovalItem.fromJson({
        'order': {'id': 3, 'number': '900', 'status': 1, 'totalNet': 500},
        'stockWarnings': [
          {'productId': 1, 'required': 5, 'available': 1},
        ],
        'creditOverLimit': true,
        'customerBalance': 12000,
        'creditLimit': 10000,
      });
      expect(it.order.id, 3);
      expect(it.stockWarnings.single.shortage, 4);
      expect(it.creditOverLimit, isTrue);
      expect(it.customerBalance, 12000);
      expect(it.creditLimit, 10000);
    });
  });

  group('VisStats', () {
    test('شمارنده‌ها و مبالغ کارتابلی', () {
      final s = VisStats.fromJson({
        'draft': 1,
        'submitted': 2,
        'approved': 3,
        'returned': 1,
        'invoiced': 4,
        'rejected': 0,
        'canceled': 1,
        'approvedAmount': 5000.5,
        'invoicedAmount': 9000,
        'commissionEstimate': 120,
      });
      expect(s.draft, 1);
      expect(s.submitted, 2);
      expect(s.invoiced, 4);
      expect(s.approvedAmount, 5000.5);
      expect(s.commissionEstimate, 120);
    });
  });

  group('ShopReferrer', () {
    test('فیلدهای پورسانت، سقف تخفیف و کیف پول', () {
      final r = ShopReferrer.fromJson({
        'id': 7,
        'name': 'رضا کریمی',
        'companyName': 'بازاریابی کریمی',
        'phone': '09121111111',
        'goodsCommissionPercent': 5,
        'serviceCommissionPercent': 10,
        'cardNumber': '6037000000000000',
        'iban': '120000000000000000000000',
        'canViewProducts': true,
        'maxDiscountPercent': 15,
        'isActive': true,
        'orderCount': 12,
        'totalCommission': 900000,
        'totalPaid': 400000,
        'walletBalance': 500000,
      });
      expect(r.goodsCommissionPercent, 5);
      expect(r.serviceCommissionPercent, 10);
      expect(r.maxDiscountPercent, 15);
      expect(r.canViewProducts, isTrue);
      expect(r.walletBalance, 500000);
      expect(r.toJson()['maxDiscountPercent'], 15);
      expect(r.toJson()['canViewProducts'], isTrue);
      expect(r.toJson()['id'], 7);
    });

    test('isActive پیش‌فرض true است (سمت سرور هم همین است)', () {
      expect(ShopReferrer().isActive, isTrue);
    });
  });

  group('ReferrerPayment', () {
    test('fromJson و toJson سند پرداخت پورسانت', () {
      final p = ReferrerPayment.fromJson({
        'id': 4,
        'referrerId': 7,
        'referrerName': 'رضا کریمی',
        'number': 'PAY-1001',
        'amount': 250000,
        'date': '2026-11-02T00:00:00Z',
        'description': 'واریز کارت به کارت',
      });
      expect(p.number, 'PAY-1001');
      expect(p.amount, 250000);
      expect(p.description, 'واریز کارت به کارت');
      final j = p.toJson();
      expect(j['referrerId'], 7);
      expect(j['amount'], 250000);
    });
  });

  group('VisCustomer / VisProduct / VisWarehouse', () {
    test('مشتری سبک ویزیتور', () {
      final c = VisCustomer.fromJson({
        'id': 31,
        'name': 'فروشگاه آریا',
        'mobile': '09120000000',
        'balance': 1200,
        'ownedByMe': true,
      });
      expect(c.name, 'فروشگاه آریا');
      expect(c.balance, 1200);
      expect(c.ownedByMe, isTrue);
    });

    test('کالا با موجودی همان انبار و کالای خدماتی', () {
      final p = VisProduct.fromJson({
        'id': 5,
        'code': 'SRV-1',
        'name': 'نصب و راه‌اندازی',
        'unit': 'سرویس',
        'salePrice': 5000000,
        'stock': 0,
        'isService': true,
      });
      expect(p.salePrice, 5000000);
      expect(p.isService, isTrue);
      expect(p.stock, 0);
    });

    test('انبار سبک', () {
      expect(VisWarehouse.fromJson({'id': 2, 'name': 'انبار مرکزی'}).id, 2);
    });
  });
}
