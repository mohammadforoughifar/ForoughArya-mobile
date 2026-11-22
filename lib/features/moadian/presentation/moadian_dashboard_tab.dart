import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/moadian_calc.dart';
import '../models/moadian_models.dart';
import 'moadian_style.dart';

class MoadianDashboardTab extends StatelessWidget {
  const MoadianDashboardTab({
    super.key,
    required this.companies,
    required this.activeCpInfoId,
    required this.connection,
    required this.fiscalYearCount,
    required this.goodsCount,
    required this.customersCount,
    required this.labels,
    required this.recentInvoices,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onSelectCompany,
    required this.onNewInvoice,
    required this.onOpenInvoicesWithFilter,
    required this.onOpenInvoiceDetail,
    required this.onOpenBasicSection,
    required this.onOpenGuide,
  });

  final List<MoadianCpInfo> companies;
  final int activeCpInfoId;
  final MoadianConnection? connection;
  final int fiscalYearCount;
  final int goodsCount;
  final int customersCount;
  final MoadianInvoiceLabels labels;
  final List<MoadianInvoice> recentInvoices;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final ValueChanged<MoadianCpInfo> onSelectCompany;
  final VoidCallback onNewInvoice;
  final ValueChanged<String> onOpenInvoicesWithFilter;
  final ValueChanged<MoadianInvoice> onOpenInvoiceDetail;
  final ValueChanged<int> onOpenBasicSection;
  final VoidCallback onOpenGuide;

  bool get _hasCompany => activeCpInfoId > 0 && companies.isNotEmpty;
  bool get _hasFiscalYear => fiscalYearCount > 0;
  bool get _hasConn =>
      connection != null &&
      connection!.taxMemoryId.trim().isNotEmpty &&
      connection!.hasStoredPrivateKey;
  bool get _hasGoods => goodsCount > 0;

  @override
  Widget build(BuildContext context) {
    final readyCount = [
      _hasCompany,
      _hasFiscalYear,
      _hasConn,
      _hasGoods,
    ].where((e) => e).length;

    return RefreshIndicator(
      color: MoadianColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: [
          MoadianCompanyBar(
            companies: companies,
            activeCpInfoId: activeCpInfoId,
            connected: _hasCompany ? _hasConn : null,
            onSelect: onSelectCompany,
            onManageCompanies: () => onOpenBasicSection(0),
          ),
          const SizedBox(height: 12),

          if (error != null) ...[
            MoadianErrorBanner(message: error!, onRetry: onRefresh),
            const SizedBox(height: 10),
          ],

          // چک‌لیست هوشمند ۴ گام راه‌اندازی مودیان
          _SetupReadinessCard(
            readyCount: readyCount,
            hasCompany: _hasCompany,
            hasFiscalYear: _hasFiscalYear,
            hasConn: _hasConn,
            hasGoods: _hasGoods,
            onStepTap: (step) => switch (step) {
              0 => onOpenBasicSection(0),
              1 => onOpenBasicSection(0),
              2 => onOpenBasicSection(1),
              _ => onOpenBasicSection(2),
            },
          ),
          const SizedBox(height: 14),

          // کارت‌های شاخص (KPI) وضعیت کارپوشه صورتحساب‌ها
          MoadianSectionTitle(
            title: 'شاخص‌های لحظه‌ای صورتحساب‌ها',
            subtitle: 'لمس هر کارت فهرست همان وضعیت را باز می‌کند',
            trailing: loading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MoadianColors.primary,
                    ),
                  )
                : null,
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.05,
            children: [
              _KpiTile(
                title: 'کل صورتحساب‌ها',
                count: labels.all,
                icon: Icons.receipt_long_rounded,
                color: MoadianColors.primary,
                onTap: () => onOpenInvoicesWithFilter('همه'),
              ),
              _KpiTile(
                title: 'ارسال‌نشده (پیش‌نویس)',
                count: labels.notSent,
                icon: Icons.edit_note_rounded,
                color: const Color(0xFF475569),
                onTap: () => onOpenInvoicesWithFilter('0'),
              ),
              _KpiTile(
                title: 'در انتظار استعلام',
                count: labels.waitingInquiry,
                icon: Icons.sync_rounded,
                color: MoadianColors.accent,
                onTap: () => onOpenInvoicesWithFilter('1'),
              ),
              _KpiTile(
                title: 'در انتظار واکنش خریدار',
                count: labels.waitingReaction,
                icon: Icons.hourglass_top_rounded,
                color: MoadianColors.warn,
                onTap: () => onOpenInvoicesWithFilter('4'),
              ),
              _KpiTile(
                title: 'دارای خطای سامانه',
                count: labels.hasError,
                icon: Icons.error_outline_rounded,
                color: MoadianColors.danger,
                onTap: () => onOpenInvoicesWithFilter('5'),
              ),
              _KpiTile(
                title: 'ارسال‌شده به سامانه',
                count: labels.sent,
                icon: Icons.verified_outlined,
                color: MoadianColors.ok,
                onTap: () => onOpenInvoicesWithFilter('3'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // نوار دسترسی سریع عملیاتی
          const MoadianSectionTitle(
            title: 'عملیات سریع مودیان تیسا',
            subtitle: 'ثبت سند جدید و مدیریت پایه‌های مالیاتی',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickOpBtn(
                  icon: Icons.post_add_rounded,
                  label: 'صدور صورتحساب',
                  sub: 'سند جدید',
                  primary: true,
                  onTap: onNewInvoice,
                ),
                const SizedBox(width: 8),
                _QuickOpBtn(
                  icon: Icons.vpn_key_rounded,
                  label: 'اتصال و کلید',
                  sub: _hasConn ? 'متصل' : 'تنظیم حافظه',
                  onTap: () => onOpenBasicSection(1),
                ),
                const SizedBox(width: 8),
                _QuickOpBtn(
                  icon: Icons.inventory_2_outlined,
                  label: 'کالا و خدمات',
                  sub: '${Fa.digits(goodsCount)} قلم CPC',
                  onTap: () => onOpenBasicSection(2),
                ),
                const SizedBox(width: 8),
                _QuickOpBtn(
                  icon: Icons.groups_2_outlined,
                  label: 'مشتریان',
                  sub: '${Fa.digits(customersCount)} طرف‌حساب',
                  onTap: () => onOpenBasicSection(3),
                ),
                const SizedBox(width: 8),
                _QuickOpBtn(
                  icon: Icons.menu_book_rounded,
                  label: 'راهنما و خطایاب',
                  sub: 'کدهای سامانه',
                  onTap: onOpenGuide,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // آخرین صورتحساب‌های ثبت‌شده
          MoadianSectionTitle(
            title: 'آخرین صورتحساب‌های پرونده',
            trailing: TextButton(
              onPressed: () => onOpenInvoicesWithFilter('همه'),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'مشاهده همه',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (recentInvoices.isEmpty && !loading)
            MoadianEmptyCard(
              icon: Icons.receipt_long_outlined,
              title: 'هنوز صورتحسابی ثبت نشده است',
              subtitle:
                  'پس از تکمیل اطلاعات پایه، اولین صورتحساب الکترونیکی خود را صادر و به سامانه مودیان ارسال کنید.',
              actionLabel: 'صدور اولین صورتحساب',
              onAction: onNewInvoice,
            )
          else
            for (final inv in recentInvoices.take(5)) ...[
              _RecentInvoiceTile(
                inv: inv,
                onTap: () => onOpenInvoiceDetail(inv),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _SetupReadinessCard extends StatelessWidget {
  const _SetupReadinessCard({
    required this.readyCount,
    required this.hasCompany,
    required this.hasFiscalYear,
    required this.hasConn,
    required this.hasGoods,
    required this.onStepTap,
  });

  final int readyCount;
  final bool hasCompany;
  final bool hasFiscalYear;
  final bool hasConn;
  final bool hasGoods;
  final ValueChanged<int> onStepTap;

  @override
  Widget build(BuildContext context) {
    final allReady = readyCount == 4;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoadianColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: allReady
              ? MoadianColors.ok.withValues(alpha: 0.35)
              : MoadianColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                allReady
                    ? Icons.verified_user_rounded
                    : Icons.checklist_rtl_rounded,
                color: allReady ? MoadianColors.ok : MoadianColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  allReady
                      ? 'پرونده آمادهٔ صدور و ارسال صورتحساب الکترونیکی است'
                      : 'گام‌های آماده‌سازی اتصال به سامانه مودیان (${Fa.digits(readyCount)} از ۴)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.6,
                    fontWeight: FontWeight.w900,
                    color: MoadianColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StepBadge(
                label: '۱. ثبت شرکت',
                done: hasCompany,
                onTap: () => onStepTap(0),
              ),
              _StepBadge(
                label: '۲. سال مالی',
                done: hasFiscalYear,
                onTap: () => onStepTap(1),
              ),
              _StepBadge(
                label: '۳. حافظه و کلید خصوصی',
                done: hasConn,
                onTap: () => onStepTap(2),
              ),
              _StepBadge(
                label: '۴. کالا با کد CPC',
                done: hasGoods,
                onTap: () => onStepTap(3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.label,
    required this.done,
    required this.onTap,
  });

  final String label;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = done ? MoadianColors.ok : MoadianColors.warn;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: c.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.pending_outlined,
              size: 13.5,
              color: c,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: MoadianColors.surface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MoadianColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fa.number(count),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.4,
                      fontWeight: FontWeight.w700,
                      color: MoadianColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickOpBtn extends StatelessWidget {
  const _QuickOpBtn({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Material(
    color: primary ? MoadianColors.primary : MoadianColors.surface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 124,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: primary ? null : Border.all(color: MoadianColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 21,
              color: primary ? Colors.white : MoadianColors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: primary ? Colors.white : MoadianColors.ink,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: primary ? Colors.white70 : MoadianColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecentInvoiceTile extends StatelessWidget {
  const _RecentInvoiceTile({required this.inv, required this.onTap});

  final MoadianInvoice inv;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tax = MoadianCalc.primaryTaxNumber(inv);
    return Material(
      color: MoadianColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MoadianColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'شماره ${Fa.digits(inv.numberInvoice ?? inv.effectiveId)}',
                        style: const TextStyle(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w900,
                          color: MoadianColors.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      MoadianSubjectBadge(subject: inv.subject),
                    ],
                  ),
                  MoadianStatusPill(code: inv.statusCode, compact: true),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      inv.isNoBuyerType
                          ? 'مصرف‌کننده نهایی (${inv.typePattern})'
                          : (inv.customerName ?? '—'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: MoadianColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${Fa.number(inv.totalMoney.round())} ریال',
                    style: const TextStyle(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w900,
                      color: MoadianColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    inv.dateOrder == null ? '—' : jalaliShort(inv.dateOrder!),
                    style: const TextStyle(
                      fontSize: 10.3,
                      color: MoadianColors.inkFaint,
                    ),
                  ),
                  if (tax.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          tax,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.2,
                            color: MoadianColors.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
