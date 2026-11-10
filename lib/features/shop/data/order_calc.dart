// ============================================================
//  محاسبات خالص فرم سند (بدون وابستگی به UI)
//  آینهٔ متدهای OrderForm.razor:
//    HasNonCash / CashPart / FinalRemaining / PaymentMethod / DeclaredMethod
//    / BuildInstallments / محاسبهٔ اقساط با سود
//  تا آزمون‌پذیر باشد و منطق دو جا تکرار نشود.
// ============================================================

import '../models/order_models.dart';

class OrderCalc {
  /// `DeclaredMethod` وب: نقدی → چک → اقساطی → نسیه
  static int declaredMethod({
    required bool useCheque,
    required bool useInstallment,
    required bool useCredit,
  }) {
    if (!(useCheque || useInstallment || useCredit)) return PayMethod.cash;
    if (useCheque) return PayMethod.cheque;
    if (useInstallment) return PayMethod.installment;
    return PayMethod.credit;
  }

  /// `CashPart` وب: اگر جزء غیرنقدی فعال نباشد، تمام مبلغ سند نقدی است
  static double cashPart({
    required double grandTotal,
    required double cashText,
    required bool hasNonCash,
  }) => hasNonCash ? cashText : grandTotal;

  /// `FinalRemaining` = مبلغ سند − (نقد + چک + اقساط)
  static double finalRemaining({
    required double grandTotal,
    required double cash,
    required double chequeSum,
    required double instSum,
  }) => grandTotal - cash - chequeSum - instSum;

  /// `BuildInstallments` وب: تقسیم مساوی با گرد کردن به پایین؛
  /// قسط آخر = ماندهٔ دقیق.
  static List<double> buildInstallments({
    required double totalDue,
    required int count,
  }) {
    if (count < 1 || totalDue <= 0) return const [];
    final base = (totalDue / count).floorToDouble();
    return [
      for (var i = 0; i < count; i++)
        i == count - 1 ? totalDue - base * (count - 1) : base,
    ];
  }

  /// سود سادهٔ ماهانه: پایه × درصد ÷ ۱۰۰ × تعداد ماه
  static double interest({
    required double base,
    required double monthlyPercent,
    required int months,
  }) {
    if (base <= 0 || monthlyPercent <= 0 || months < 1) return 0;
    return (base * monthlyPercent / 100 * months).roundToDouble();
  }
}
