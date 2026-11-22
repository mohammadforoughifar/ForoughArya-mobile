import '../models/moadian_models.dart';

/// محاسبات دقیق مالیاتی و قواعد شمارهٔ مالیاتی سامانه مودیان — ۱۰۰٪ هم‌تراز با وب (`MoadianInvoiceForm.razor` و `MoadianInvoiceDetail.razor`).
class MoadianCalc {
  const MoadianCalc._();

  /// مبلغ قبل از تخفیف = تعداد × فی واحد
  static double lineGross(MoadianInvoiceItem item) =>
      (item.count < 0 ? 0 : item.count) *
      (item.priceUnit < 0 ? 0 : item.priceUnit);

  /// مبلغ تخفیف ردیف
  static double lineDiscount(MoadianInvoiceItem item) =>
      item.discount < 0 ? 0 : item.discount;

  /// مبلغ پس از تخفیف
  static double lineNet(MoadianInvoiceItem item) {
    final net = lineGross(item) - lineDiscount(item);
    return net < 0 ? 0 : net;
  }

  /// مبلغ مالیات بر ارزش افزوده (بدون اعشار — Truncate مطابق فرمول رسمی مودیان)
  static double lineVat(MoadianInvoiceItem item) {
    if (item.valueAddedAmount != null && item.valueAddedAmount! > 0) {
      return item.valueAddedAmount!;
    }
    return (lineNet(item) * item.valueAddedPercentage / 100.0)
        .truncateToDouble();
  }

  /// جمع نهایی ردیف = Truncate(مبلغ پس از تخفیف) + ارزش افزوده
  static double lineTotal(MoadianInvoiceItem item) =>
      item.calculatedPay ??
      (lineNet(item).truncateToDouble() + lineVat(item));

  static double totalGross(Iterable<MoadianInvoiceItem> items) =>
      items.fold<double>(0, (s, i) => s + lineGross(i));

  static double totalDiscount(Iterable<MoadianInvoiceItem> items) =>
      items.fold<double>(0, (s, i) => s + lineDiscount(i));

  static double totalNet(Iterable<MoadianInvoiceItem> items) =>
      items.fold<double>(0, (s, i) => s + lineNet(i));

  static double totalVat(Iterable<MoadianInvoiceItem> items) =>
      items.fold<double>(0, (s, i) => s + lineVat(i));

  static double grandTotal(Iterable<MoadianInvoiceItem> items) =>
      items.fold<double>(0, (s, i) => s + lineTotal(i));

  /// آیا موضوع صورتحساب از نوع ارجاعی است؟ (اصلاحی / ابطالی / برگشت از فروش)
  static bool isReferenceSubject(String? subject) {
    final s = (subject ?? '').trim();
    return s.contains('اصلاحی') ||
        s.contains('ابطالی') ||
        s.contains('برگشت از فروش');
  }

  /// شمارهٔ مالیاتی ۲۲ کاراکتری خودِ همین صورتحساب (`Taxid`).
  /// در صورتحساب‌های ارجاعی، `newTaxNumber` شمارهٔ خود سند و `taxNumber` شمارهٔ مرجع است.
  static String primaryTaxNumber(MoadianInvoice inv) {
    final nt = inv.newTaxNumber?.trim() ?? '';
    if (nt.isNotEmpty) return nt;
    if (isReferenceSubject(inv.subject)) return '';
    return inv.taxNumber?.trim() ?? '';
  }

  /// شمارهٔ مالیاتی ۲۲ کاراکتری صورتحساب مرجع (`Irtaxid`) برای اسناد اصلاحی/ابطالی/برگشت.
  static String referenceTaxNumber(MoadianInvoice inv) {
    if (!isReferenceSubject(inv.subject)) return '';
    final ref = inv.taxNumber?.trim() ?? '';
    if (ref.isEmpty) return '';
    final own = primaryTaxNumber(inv);
    return ref.toLowerCase() == own.toLowerCase() ? '' : ref;
  }
}
