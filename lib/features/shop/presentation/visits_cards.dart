// ============================================================
//  اجزای مشترک صفحه‌های ویزیتوری (فیلد ۶)
//  کارت سفارش، رنگ/برچسب وضعیت، جعبهٔ هشدار کسری
//  مشترک بین: سفارش‌های من، کارتابل تأیید، همهٔ درخواست‌ها، صف مالی
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../models/visit_models.dart';
import 'shop_style.dart';

Color visStatusColor(int s) => switch (s) {
  VisStatus.draft => ShopColors.inkFaint,
  VisStatus.submitted => ShopColors.warn,
  VisStatus.approved => ShopColors.seed,
  VisStatus.returned || VisStatus.rejected || VisStatus.canceled =>
    ShopColors.danger,
  VisStatus.invoiced || VisStatus.closed => ShopColors.ok,
  _ => ShopColors.inkSoft,
};

/// کارت استاندارد سفارش — معادل ردیف جدول‌های وب در نمای موبایل
class VisOrderCard extends StatelessWidget {
  const VisOrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.showReferrer = false,
    this.trailing,
    this.leadingNote,
    this.showStock = false,
  });

  final VisOrder order;
  final VoidCallback? onTap;
  final bool showReferrer;
  final Widget? trailing;
  final Widget? leadingNote;
  final bool showStock;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final color = visStatusColor(o.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border(
            right: BorderSide(color: color, width: 3),
            top: const BorderSide(color: ShopColors.line),
            bottom: const BorderSide(color: ShopColors.line),
            left: const BorderSide(color: ShopColors.line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'سفارش ${Fa.number(int.tryParse(o.number) ?? 0)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (o.returnCount > 0) ...[
                            const SizedBox(width: 5),
                            ShopTag(
                              text: '${Fa.number(o.returnCount)} بار برگشت',
                              color: ShopColors.danger,
                            ),
                          ],
                          if (o.discountOverLimit) ...[
                            const SizedBox(width: 5),
                            const ShopTag(
                              text: 'تخفیف ویژه',
                              color: ShopColors.danger,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        o.partyName.isEmpty ? '—' : o.partyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                      Text(
                        [
                          o.referrerName.isEmpty ? null : 'ویزیتور: ${o.referrerName}',
                          o.date == null ? null : jalaliShort(o.date!),
                        ].whereType<String>().join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShopTag(text: o.statusTitle, color: color),
                    const SizedBox(height: 4),
                    Text(
                      Fa.number(o.totalNet),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.ink,
                      ),
                    ),
                    const Text(
                      'ریال',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 12,
                  color: ShopColors.inkFaint,
                ),
                const SizedBox(width: 3),
                Text(
                  o.effectiveDeliveryDate == null
                      ? 'تحویل: —'
                      : 'تحویل: ${jalaliShort(o.effectiveDeliveryDate!)}'
                            '${o.finalDateChanged ? ' (تغییر مدیر)' : ''}',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: o.finalDateChanged
                        ? ShopColors.warn
                        : ShopColors.inkFaint,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 12,
                  color: ShopColors.inkFaint,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    o.warehouseName.isEmpty ? '—' : o.warehouseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                ),
                Text(
                  '${Fa.number(o.lineCount)} سطر',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ],
            ),
            if ((o.decisionNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ShopColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  o.decisionNote!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: ShopColors.danger,
                  ),
                ),
              ),
            ],
            if (showStock && o.status == VisStatus.approved) ...[
              const SizedBox(height: 5),
              o.stockWarnings.isEmpty
                  ? const ShopTag(
                      text: 'موجودی تأمین است',
                      color: ShopColors.ok,
                      icon: Icons.check_circle_outline_rounded,
                    )
                  : ShopTag(
                      text: 'کسری ${Fa.number(o.stockWarnings.length)} قلم',
                      color: ShopColors.danger,
                      icon: Icons.warning_amber_rounded,
                    ),
            ],
            if ((o.invoiceNumber ?? 0) > 0) ...[
              const SizedBox(height: 5),
              ShopTag(
                text: 'شماره فروش: ${Fa.number(o.invoiceNumber!)}',
                color: ShopColors.indigo,
                icon: Icons.receipt_long_rounded,
              ),
            ],
            if (leadingNote != null) ...[
              const SizedBox(height: 6),
              leadingNote!,
            ],
            if (trailing != null) ...[
              const SizedBox(height: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// جدول کوچک سطرهای سفارش
class VisLinesTable extends StatelessWidget {
  const VisLinesTable({super.key, required this.lines, this.warnings = const []});

  final List<VisLine> lines;
  final List<VisStockWarning> warnings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < lines.length; i++)
          Builder(
            builder: (_) {
              final l = lines[i];
              final w = warnings.where((x) => x.productId == l.productId).firstOrNull;
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: w == null
                      ? ShopColors.bg
                      : ShopColors.warn.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${Fa.number(i + 1)}. ${l.productName}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          Fa.number(l.lineTotal),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${Fa.number(l.quantity, decimals: 2)} ${l.unit ?? ''} × '
                      '${Fa.number(l.unitPrice)} · تخفیف ${l.discountText}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                    if (w != null)
                      Text(
                        'موجودی ${Fa.number(w.available, decimals: 2)} — '
                        'نیاز ${Fa.number(w.required, decimals: 2)}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: ShopColors.danger,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// جعبهٔ هشدار کسری موجودی (مشترک کارتابل تأیید و صف مالی)
class VisStockWarnBox extends StatelessWidget {
  const VisStockWarnBox({
    super.key,
    required this.warnings,
    this.note = 'تأیید سفارش متوقف شد؛ ابتدا موجودی انبار را تأمین کنید.',
  });

  final List<VisStockWarning> warnings;
  final String note;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ShopColors.warn.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShopColors.warn.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 15,
                color: ShopColors.warn,
              ),
              SizedBox(width: 5),
              Text(
                'کسری موجودی انبار',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.warn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          for (final w in warnings)
            Text(
              '${w.productName}: نیاز ${Fa.number(w.required, decimals: 2)} · '
              'موجودی ${Fa.number(w.available, decimals: 2)}',
              style: const TextStyle(fontSize: 9.5, color: ShopColors.inkSoft),
            ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                note,
                style: const TextStyle(fontSize: 9, color: ShopColors.warn),
              ),
            ),
        ],
      ),
    );
  }
}
