// آزمون فاز ۵ «سامانه فروشگاهی» — خزانه، چک، اقساط و مانده‌های اولیه
// تضمین می‌کند فیلدها، قواعد انتقال وضعیت چک و پیام‌ها عیناً آینهٔ وب باشند.

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/shop/models/treasury_models.dart';

void main() {
  group('TrsAccount', () {
    test('مانده‌ها و عنوان‌ها مثل DTO سرور خوانده می‌شود', () {
      final a = TreasuryAccount.fromJson({
        'id': 3,
        'code': 'BNK-MELLAT',
        'name': 'جاری اصلی',
        'kind': 1,
        'bankName': 'بانک ملت',
        'branchName': 'شعبه مرکزی',
        'accountNumber': '1234567890',
        'iban': '120000000000000000000000',
        'openingBalance': 1000,
        'totalIn': 5000,
        'totalOut': 2000,
        'balance': 4000,
        'moveCount': 7,
        'isDefault': true,
        'accountId': 22,
        'accountCode': '1010',
        'accountName': 'موجودی نزد بانک‌ها',
      });
      expect(a.kindTitle, 'بانک');
      expect(a.displayName, 'جاری اصلی — بانک ملت');
      expect(a.balance, 4000);
      expect(a.moveCount, 7);
      expect(a.isDefault, isTrue);
      expect(a.hasAccounting, isTrue);
    });

    test('صندوق و تنخواه عنوان درست دارند (وب)', () {
      expect(TreasuryAccount(kind: 0).kindTitle, 'صندوق');
      expect(TreasuryAccount(kind: 2).kindTitle, 'کارتخوان');
      expect(TreasuryAccount(kind: 3).kindTitle, 'تنخواه‌گردان');
    });

    test('toJson همان فیلدهای TrsAccount را می‌فرستد', () {
      final j = TreasuryAccount(
        name: ' صندوق مرکزی ',
        kind: 0,
        openingBalance: 500,
        isActive: true,
      ).toJson();
      expect(j['name'], 'صندوق مرکزی');
      expect(j['kind'], 0);
      expect(j['openingBalance'], 500);
      expect(j.containsKey('balance'), isFalse);
    });
  });

  group('TrsVoucher', () {
    TreasuryVoucher sample() => TreasuryVoucher.fromJson({
      'id': 11,
      'number': 42,
      'kind': 0,
      'date': '2026-02-01T10:00:00',
      'partyId': 5,
      'partyName': 'مشتری الف',
      'description': 'تسویه فاکتور',
      'refNumber': 'REF-1',
      'status': 0,
      'totalAmount': 1500,
      'cashAmount': 1000,
      'chequeAmount': 500,
      'lines': [
        {'rowNo': 1, 'method': 0, 'trsAccountId': 2, 'amount': 1000},
        {
          'rowNo': 2,
          'method': 3,
          'amount': 500,
          'chequeNumber': '889911',
          'dueDate': '2026-03-01T00:00:00',
        },
      ],
      'invoiceAllocations': [
        {
          'invoiceId': 7,
          'invoiceNumber': 700,
          'invoiceKind': 2,
          'amount': 1500,
          'remainingBeforeSettlement': 2000,
        },
      ],
    });

    test('جمع‌ها، سطرها و تخصیص فاکتور خوانده می‌شود', () {
      final v = sample();
      expect(v.kindTitle, 'سند دریافت');
      expect(v.statusTitle, 'پیش‌نویس');
      expect(v.lines.length, 2);
      expect(v.lines.first.methodTitle, 'نقد');
      expect(v.lines.last.methodTitle, 'چک');
      expect(v.invoiceAllocations.single.invoiceNumber, 700);
      expect(v.isEditable, isTrue);
      expect(v.isConfirmed, isFalse);
      expect(v.isIncoming, isTrue);
    });

    test('قطعی قابل ویرایش نیست و ابطال هم', () {
      final v = TreasuryVoucher(status: TrsState.confirmed);
      expect(v.isEditable, isFalse);
      expect(v.statusTitle, 'قطعی');
      expect(TreasuryVoucher(status: TrsState.cancelled).statusTitle, 'ابطال شده');
      expect(TreasuryVoucher(kind: TrsKind.transfer).kindTitle, 'انتقال بین حساب‌ها');
    });

    test('toJson سطر چک فقط فیلدهای لازم سرور را دارد', () {
      final l = VoucherLine(
        method: TrsMethod.cheque,
        amount: 500,
        chequeNumber: '889911',
        dueDate: DateTime(2026, 3, 1),
      );
      final j = l.toJson();
      expect(j['method'], 3);
      expect(j['chequeNumber'], '889911');
      expect(j.containsKey('issueDate'), isTrue);
      expect(l.needsAccount, isFalse);
      expect(VoucherLine(method: TrsMethod.cash).needsAccount, isTrue);
    });

    test('ابزارها همان PayMethod وب‌اند', () {
      expect(TrsMethod.title(0), 'نقد');
      expect(TrsMethod.title(1), 'کارتخوان');
      expect(TrsMethod.title(2), 'حواله بانکی');
      expect(TrsMethod.title(3), 'چک');
      expect(TrsMethod.title(4), 'تخفیف و کسورات');
      expect(TrsMethod.needsAccount(4), isFalse);
    });
  });

  group('چرخهٔ عمر چک — همان EnsureTransition سرور', () {
    test('چک دریافتی: نزد صندوق → واگذاری/وصول/خرج/ابطال', () {
      expect(
        TrsChequeState.canGo(
          ChequeKind.received,
          TrsChequeState.inHand,
          TrsChequeState.inCollection,
        ),
        isTrue,
      );
      expect(
        TrsChequeState.canGo(
          ChequeKind.received,
          TrsChequeState.inHand,
          TrsChequeState.cleared,
        ),
        isTrue,
      );
      expect(
        TrsChequeState.canGo(
          ChequeKind.received,
          TrsChequeState.inHand,
          TrsChequeState.bounced,
        ),
        isFalse,
      );
      expect(
        TrsChequeState.canGo(
          ChequeKind.received,
          TrsChequeState.inHand,
          TrsChequeState.endorsed,
        ),
        isTrue,
      );
    });

    test('چک در جریان: وصول/برگشت/بازگشت به صندوق', () {
      expect(
        TrsChequeState.canGo(
          ChequeKind.received,
          TrsChequeState.inCollection,
          TrsChequeState.bounced,
        ),
        isTrue,
      );
      expect(
        TrsChequeState.canGo(
          ChequeKind.received,
          TrsChequeState.inCollection,
          TrsChequeState.inHand,
        ),
        isTrue,
      );
      expect(
        TrsChequeState.canGo(
          ChequeKind.received,
          TrsChequeState.inCollection,
          TrsChequeState.endorsed,
        ),
        isFalse,
      );
    });

    test('چک برگشتی: واگذاری/وصول/ابطال', () {
      expect(
        TrsChequeState.canGo(
          ChequeKind.received,
          TrsChequeState.bounced,
          TrsChequeState.inCollection,
        ),
        isTrue,
      );
      expect(
        TrsChequeState.canGo(
          ChequeKind.received,
          TrsChequeState.bounced,
          TrsChequeState.inHand,
        ),
        isFalse,
      );
    });

    test('چک صادره: خرج چک معنا ندارد', () {
      expect(
        TrsChequeState.canGo(
          ChequeKind.issued,
          TrsChequeState.inHand,
          TrsChequeState.endorsed,
        ),
        isFalse,
      );
      expect(
        TrsChequeState.canGo(
          ChequeKind.issued,
          TrsChequeState.inHand,
          TrsChequeState.cleared,
        ),
        isTrue,
      );
      expect(
        TrsChequeState.canGo(
          ChequeKind.issued,
          TrsChequeState.inCollection,
          TrsChequeState.cleared,
        ),
        isFalse,
      );
    });

    test('تعیین‌تکلیف نهایی شده: هیچ عملیاتی مجاز نیست', () {
      for (final final_ in [
        TrsChequeState.cleared,
        TrsChequeState.endorsed,
        TrsChequeState.cancelled,
      ]) {
        expect(
          TrsChequeState.canGo(
            ChequeKind.received,
            final_,
            TrsChequeState.inHand,
          ),
          isFalse,
        );
      }
      expect(
        TrsChequeState.canGo(
          ChequeKind.received,
          TrsChequeState.inHand,
          TrsChequeState.inHand,
        ),
        isFalse,
      );
    });

    test('عنوان وضعیت‌ها مثل StatusTitle وب', () {
      expect(TrsChequeState.title(0), 'نزد صندوق');
      expect(TrsChequeState.title(0, kind: ChequeKind.issued), 'تحویل شده');
      expect(TrsChequeState.title(1), 'در جریان وصول');
      expect(TrsChequeState.title(2), 'وصول شده');
      expect(TrsChequeState.title(2, kind: ChequeKind.issued), 'پاس شده');
      expect(TrsChequeState.title(3), 'برگشتی');
      expect(TrsChequeState.title(4), 'خرج شده');
      expect(TrsChequeState.title(5), 'ابطال شده');
    });
  });

  group('TreasuryCheque', () {
    test('پروندهٔ چک و تاریخچه عملیات', () {
      final c = TreasuryCheque.fromJson({
        'id': 9,
        'kind': 0,
        'number': '889911',
        'sayadId': '1234567890123456',
        'amount': 2500000,
        'issueDate': '2026-01-01T00:00:00',
        'dueDate': '2026-03-01T00:00:00',
        'bankName': 'بانک صادرات',
        'branchName': 'شعبه ونک',
        'partyName': 'مشتری ب',
        'status': 2,
        'trsVoucherNumber': 88,
        'actions': [
          {
            'id': 1,
            'status': 0,
            'date': '2026-01-01T00:00:00',
            'trsAccountName': 'صندوق مرکزی',
          },
          {
            'id': 2,
            'status': 2,
            'date': '2026-03-02T00:00:00',
            'voucherNumber': 102,
          },
        ],
      });
      expect(c.amount, 2500000);
      expect(c.kindTitle, 'چک دریافتی');
      expect(c.statusTitle, 'وصول شده');
      expect(c.isCleared, isTrue);
      expect(c.isOpen, isFalse);
      expect(c.trsVoucherNumber, 88);
      expect(c.actions.length, 2);
      expect(c.actions.first.statusTitle, 'ثبت اولیه');
      expect(c.actions.last.statusTitle, 'وصول');
      expect(c.actions.last.voucherNumber, 102);
    });

    test('toJson فیلدهای لازم چک را می‌فرستد', () {
      final j = TreasuryCheque(
        kind: ChequeKind.issued,
        number: ' 112233 ',
        amount: 900,
        bankName: 'بانک ملی',
        trsAccountId: 4,
      ).toJson();
      expect(j['number'], '112233');
      expect(j['kind'], 1);
      expect(j['trsAccountId'], 4);
      expect(j.containsKey('status'), isFalse);
    });
  });

  group('گزارش‌های خزانه', () {
    test('گردش حساب با مانده تجمعی', () {
      final f = FlowResult.fromJson({
        'trsAccountId': 3,
        'accountName': 'صندوق مرکزی',
        'accountKindTitle': 'صندوق',
        'openingBalance': 1000,
        'totalIn': 2000,
        'totalOut': 500,
        'closingBalance': 2500,
        'rows': [
          {
            'date': '2026-02-01T00:00:00',
            'trsVoucherId': 5,
            'number': 1,
            'kind': 0,
            'method': 'نقد',
            'partyName': 'مشتری الف',
            'in': 2000,
            'out': 0,
            'balance': 3000,
          },
          {
            'number': 2,
            'kind': 1,
            'method': 'چک',
            'in': 0,
            'out': 500,
            'balance': 2500,
          },
        ],
      });
      expect(f.accountName, 'صندوق مرکزی');
      expect(f.openingBalance, 1000);
      expect(f.rows.length, 2);
      expect(f.rows.first.inAmount, 2000);
      expect(f.rows.last.out, 500);
      expect(f.closingBalance, 2500);
    });

    test('داشبورد خزانه شامل چک‌های نزدیک سررسید', () {
      final d = TreasuryDashboard.fromJson({
        'totalBalance': 9000,
        'totalCashBalance': 4000,
        'totalBankBalance': 5000,
        'periodIn': 1000,
        'periodOut': 700,
        'receiptCount': 3,
        'paymentCount': 2,
        'draftCount': 1,
        'receivedChequeTotal': 2000,
        'issuedChequeTotal': 800,
        'receivedChequeCount': 2,
        'issuedChequeCount': 1,
        'overdueChequeCount': 1,
        'overdueChequeTotal': 300,
        'accounts': [
          {'id': 1, 'name': 'صندوق', 'kind': 0, 'balance': 4000},
        ],
        'upcomingCheques': [
          {'id': 2, 'number': '555', 'amount': 700, 'kind': 1},
        ],
      });
      expect(d.totalBalance, 9000);
      expect(d.accounts.single.kindTitle, 'صندوق');
      expect(d.upcomingCheques.single.kindTitle, 'چک پرداختی');
      expect(d.overdueChequeCount, 1);
    });
  });

  group('مدیریت چک و اقساط فروشگاهی', () {
    test('خلاصه — کارت چهارم = چک وصول‌شده + قسط پرداخت‌شده', () {
      final s = ShopCreditSummary.fromJson({
        'inHandChequesCount': 2,
        'inHandChequesTotal': 1000,
        'clearedChequesCount': 3,
        'clearedChequesTotal': 2000,
        'bouncedChequesCount': 1,
        'bouncedChequesTotal': 400,
        'pendingInstallmentsCount': 5,
        'pendingInstallmentsTotal': 3000,
        'paidInstallmentsCount': 2,
        'paidInstallmentsTotal': 900,
        'overdueInstallmentsCount': 1,
        'overdueInstallmentsTotal': 600,
      });
      expect(s.collectedCount, 5);
      expect(s.collectedTotal, 2900);
      expect(s.overdueInstallmentsCount, 1);
    });

    test('چک فروشگاهی — جهت تراکنش از نوع سند', () {
      final recv = ShopCheque.fromJson({
        'id': 1,
        'transactionType': 2,
        'number': '111',
        'amount': 500,
        'partyName': 'مشتری',
        'status': 3,
        'bounceReason': 'کسر موجودی',
        'daysOverdue': 12,
      });
      expect(recv.isReceivable, isTrue);
      expect(recv.isBounced, isTrue);
      expect(recv.bounceReason, 'کسر موجودی');
      expect(recv.daysOverdue, 12);

      final paid = ShopCheque.fromJson({'transactionType': 1});
      expect(paid.isReceivable, isFalse);
    });

    test('قسط فروشگاهی', () {
      final i = ShopInstallment.fromJson({
        'id': 4,
        'no': 2,
        'amount': 750,
        'partyName': 'مشتری ج',
        'isPaid': false,
        'daysOverdue': 3,
        'dueDate': '2026-02-01T00:00:00',
      });
      expect(i.no, 2);
      expect(i.amount, 750);
      expect(i.isPaid, isFalse);
      expect(i.daysOverdue, 3);
    });
  });

  group('کمک‌تابع‌های مانده‌های اولیه', () {
    test('تقسیم اقساط — آخرین قسط گرد‌شده را می‌گیرد', () {
      final parts = splitInstallments(1000, 3);
      expect(parts.length, 3);
      expect(parts[0], 333);
      expect(parts[1], 333);
      expect(parts[2], 334);
      expect(parts.reduce((a, b) => a + b), 1000);
    });

    test('تقسیم با تعداد صفر → فهرست خالی', () {
      expect(splitInstallments(1000, 0), isEmpty);
    });

    test('بازهٔ ماه جاری', () {
      final r = currentMonthRange(DateTime(2026, 2, 15));
      expect(r.from, DateTime(2026, 2, 1));
      expect(r.to, DateTime(2026, 2, 28));
    });
  });
}
