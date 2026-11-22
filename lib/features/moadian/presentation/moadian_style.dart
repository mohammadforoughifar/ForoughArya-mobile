import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/fa.dart';
import '../data/moadian_perms.dart';
import '../models/moadian_models.dart';

/// پالت و سیستم طراحی اختصاصی «مودیان تیسا» — تم زمردی-نفتی رسمی درگاه مالیاتی.
class MoadianColors {
  const MoadianColors._();

  static const Color bg = Color(0xFFF3F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8FAFB);
  static const Color line = Color(0xFFDCE6E9);

  static const Color deep = Color(0xFF071F24);
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryBright = Color(0xFF0D9488);
  static const Color accent = Color(0xFF0284C7);
  static const Color indigo = Color(0xFF4F46E5);

  static const Color ok = Color(0xFF059669);
  static const Color warn = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);

  static const Color ink = Color(0xFF0F172A);
  static const Color inkSoft = Color(0xFF475569);
  static const Color inkFaint = Color(0xFF94A3B8);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF071F24), Color(0xFF0E4B50), Color(0xFF0F766E)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  /// استایل رنگی هر کد وضعیت `0` تا `11` (رنگ متن/نقطه، پس‌زمینهٔ ملایم و آیکون).
  static ({Color fg, Color bg, IconData icon}) statusTheme(String? code) =>
      switch (code?.trim()) {
        '0' => (
          fg: const Color(0xFF475569),
          bg: const Color(0xFFF1F5F9),
          icon: Icons.edit_note_rounded,
        ),
        '1' => (
          fg: const Color(0xFF0284C7),
          bg: const Color(0xFFE0F2FE),
          icon: Icons.sync_rounded,
        ),
        '2' => (
          fg: const Color(0xFFD97706),
          bg: const Color(0xFFFEF3C7),
          icon: Icons.manage_search_rounded,
        ),
        '3' => (
          fg: const Color(0xFF4F46E5),
          bg: const Color(0xFFEEF2FF),
          icon: Icons.send_and_archive_rounded,
        ),
        '4' => (
          fg: const Color(0xFFEA580C),
          bg: const Color(0xFFFFEDD5),
          icon: Icons.hourglass_top_rounded,
        ),
        '5' => (
          fg: const Color(0xFFDC2626),
          bg: const Color(0xFFFEE2E2),
          icon: Icons.error_outline_rounded,
        ),
        '6' => (
          fg: const Color(0xFF57534E),
          bg: const Color(0xFFF5F5F4),
          icon: Icons.inventory_2_outlined,
        ),
        '7' => (
          fg: const Color(0xFF059669),
          bg: const Color(0xFFDCFCE7),
          icon: Icons.verified_rounded,
        ),
        '8' => (
          fg: const Color(0xFFB91C1C),
          bg: const Color(0xFFFEE2E2),
          icon: Icons.cancel_outlined,
        ),
        '9' => (
          fg: const Color(0xFF991B1B),
          bg: const Color(0xFFFEE2E2),
          icon: Icons.block_rounded,
        ),
        '10' => (
          fg: const Color(0xFFB45309),
          bg: const Color(0xFFFEF3C7),
          icon: Icons.published_with_changes_rounded,
        ),
        '11' => (
          fg: const Color(0xFF047857),
          bg: const Color(0xFFD1FAE5),
          icon: Icons.task_alt_rounded,
        ),
        _ => (
          fg: const Color(0xFF64748B),
          bg: const Color(0xFFF1F5F9),
          icon: Icons.help_outline_rounded,
        ),
      };

  static ({Color fg, Color bg}) subjectTheme(String? subject) {
    final s = (subject ?? '').trim();
    if (s.contains('اصلاحی')) {
      return (fg: const Color(0xFFB45309), bg: const Color(0xFFFEF3C7));
    }
    if (s.contains('ابطالی') || s.contains('برگشت')) {
      return (fg: const Color(0xFFB91C1C), bg: const Color(0xFFFEE2E2));
    }
    return (fg: const Color(0xFF0F766E), bg: const Color(0xFFCCFBF1));
  }
}

/// هدر استاندارد صفحات فرعی مودیان تیسا (با رعایت خودکار SafeArea و عدم تکرار دکمه بازگشت).
class MoadianPageHeader extends StatelessWidget {
  const MoadianPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final hasEnclosingAppBar = Scaffold.maybeOf(context)?.hasAppBar ?? false;
    final canPop = Navigator.of(context).canPop();

    return Container(
      decoration: const BoxDecoration(
        gradient: MoadianColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22071F24),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        top: !hasEnclosingAppBar,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (canPop && !hasEnclosingAppBar) ...[
                    InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
              if (bottom != null) ...[
                const SizedBox(height: 12),
                bottom!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// کپسول وضعیت صورتحساب مودیان (`0` تا `11`).
class MoadianStatusPill extends StatelessWidget {
  const MoadianStatusPill({
    super.key,
    required this.code,
    this.compact = false,
  });

  final String? code;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final st = MoadianColors.statusTheme(code);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4.5,
      ),
      decoration: BoxDecoration(
        color: st.bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: st.fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(st.icon, size: compact ? 12 : 13.5, color: st.fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              MoadianPerms.statusLabel(code),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 10.8,
                fontWeight: FontWeight.w800,
                color: st.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// برچسب موضوع صورتحساب (`اصلی` / `اصلاحی` / `ابطالی` / `برگشت از فروش`).
class MoadianSubjectBadge extends StatelessWidget {
  const MoadianSubjectBadge({super.key, required this.subject});

  final String? subject;

  @override
  Widget build(BuildContext context) {
    final text = (subject == null || subject!.trim().isEmpty)
        ? 'اصلی'
        : subject!.trim();
    final st = MoadianColors.subjectTheme(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: st.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: st.fg,
        ),
      ),
    );
  }
}

/// نوار انتخابگر شرکت/پروندهٔ فعال مودیان (مشترک در بالای تب‌ها و فرم‌ها).
class MoadianCompanyBar extends StatelessWidget {
  const MoadianCompanyBar({
    super.key,
    required this.companies,
    required this.activeCpInfoId,
    required this.onSelect,
    this.onManageCompanies,
    this.connected,
  });

  final List<MoadianCpInfo> companies;
  final int activeCpInfoId;
  final ValueChanged<MoadianCpInfo> onSelect;
  final VoidCallback? onManageCompanies;
  final bool? connected;

  MoadianCpInfo? get _active {
    for (final c in companies) {
      if (c.cpInfoId == activeCpInfoId) return c;
    }
    return companies.isNotEmpty ? companies.first : null;
  }

  void _openPicker(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: MoadianColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: MoadianColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.domain_verification_rounded,
                        color: MoadianColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'انتخاب پروندهٔ مودیان (خدمات‌دهنده)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: MoadianColors.ink,
                            ),
                          ),
                          Text(
                            'کالاها، مشتریان و صورتحساب‌ها به تفکیک هر پرونده نمایش داده می‌شوند',
                            style: TextStyle(
                              fontSize: 10.8,
                              color: MoadianColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: companies.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final c = companies[i];
                      final selected = c.cpInfoId == activeCpInfoId;
                      return Material(
                        color: selected
                            ? MoadianColors.primary.withValues(alpha: 0.08)
                            : MoadianColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(ctx);
                            onSelect(c);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? MoadianColors.primary
                                    : MoadianColors.line,
                                width: selected ? 1.4 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 19,
                                  color: selected
                                      ? MoadianColors.primary
                                      : MoadianColors.inkFaint,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.persianName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: MoadianColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          c.type,
                                          if ((c.economicNumber ?? '')
                                              .trim()
                                              .isNotEmpty)
                                            'اقتصادی: ${Fa.digits(c.economicNumber)}',
                                          if ((c.nationalId ?? '')
                                              .trim()
                                              .isNotEmpty)
                                            'شناسه: ${Fa.digits(c.nationalId)}',
                                        ].join(' • '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
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
                    },
                  ),
                ),
                if (onManageCompanies != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onManageCompanies!();
                    },
                    icon: const Icon(Icons.add_business_rounded, size: 17),
                    label: const Text('افزودن یا ویرایش پروندهٔ مودیان'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MoadianColors.primary,
                      side: const BorderSide(color: MoadianColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    if (active == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: MoadianColors.warn,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'هنوز پروندهٔ مودیان برای این شرکت تعریف نشده است.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
            if (onManageCompanies != null)
              TextButton(
                onPressed: onManageCompanies,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'ثبت شرکت',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      );
    }

    return Material(
      color: MoadianColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openPicker(context),
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: MoadianColors.heroGradient,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            active.persianName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.8,
                              fontWeight: FontWeight.w900,
                              color: MoadianColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: MoadianColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            active.type,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: MoadianColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (active.economicNumber ?? '').trim().isNotEmpty
                          ? 'کد اقتصادی: ${Fa.digits(active.economicNumber)}'
                          : 'شناسه ملی/ثبت: ${Fa.digits(active.nationalId ?? '—')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: MoadianColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (connected != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (connected!
                            ? MoadianColors.ok
                            : MoadianColors.warn)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        connected!
                            ? Icons.link_rounded
                            : Icons.link_off_rounded,
                        size: 12,
                        color: connected!
                            ? MoadianColors.ok
                            : MoadianColors.warn,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        connected! ? 'متصل' : 'نیازمند اتصال',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: connected!
                              ? MoadianColors.ok
                              : MoadianColors.warn,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(
                Icons.unfold_more_rounded,
                size: 18,
                color: MoadianColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// تیتر بخش استاندارد بدون سرریز در صفحه‌های باریک موبایل.
class MoadianSectionTitle extends StatelessWidget {
  const MoadianSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(
      children: [
        Container(
          width: 4,
          height: subtitle == null ? 17 : 26,
          decoration: BoxDecoration(
            color: MoadianColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: MoadianColors.ink,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: MoadianColors.inkSoft,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          trailing!,
        ],
      ],
    ),
  );
}

/// ردیف نمایش و کپی یک‌کلیکی کد مالیاتی ۲۲ رقمی یا شماره مرجع سامانه.
class MoadianCopyCodeRow extends StatelessWidget {
  const MoadianCopyCodeRow({
    super.key,
    required this.label,
    required this.code,
    this.onTapReference,
    this.highlight = false,
  });

  final String label;
  final String code;
  final VoidCallback? onTapReference;
  final bool highlight;

  Future<void> _copy(BuildContext context) async {
    if (code.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code.trim()));
    HapticFeedback.lightImpact();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label در حافظه کپی شد.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: highlight
            ? MoadianColors.primary.withValues(alpha: 0.06)
            : MoadianColors.surfaceSoft,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: highlight
              ? MoadianColors.primary.withValues(alpha: 0.25)
              : MoadianColors.line,
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: MoadianColors.inkSoft,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onTapReference ?? () => _copy(context),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.2,
                    fontWeight: FontWeight.w800,
                    color: onTapReference != null
                        ? MoadianColors.accent
                        : MoadianColors.ink,
                    decoration: onTapReference != null
                        ? TextDecoration.underline
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _copy(context),
            borderRadius: BorderRadius.circular(7),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(
                Icons.copy_rounded,
                size: 15,
                color: MoadianColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// حالت خالی هدایتگر با دکمه اقدام مستقیم.
class MoadianEmptyCard extends StatelessWidget {
  const MoadianEmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    decoration: BoxDecoration(
      color: MoadianColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: MoadianColors.line),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: MoadianColors.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 26, color: MoadianColors.primary),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.8,
            fontWeight: FontWeight.w900,
            color: MoadianColors.ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.65,
            color: MoadianColors.inkSoft,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(actionLabel!),
            style: FilledButton.styleFrom(
              backgroundColor: MoadianColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// بنر نمایش خطا همراه با دکمه تلاش مجدد.
class MoadianErrorBanner extends StatelessWidget {
  const MoadianErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: MoadianColors.danger.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: MoadianColors.danger.withValues(alpha: 0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: MoadianColors.danger,
          size: 20,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: MoadianColors.ink,
            ),
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: MoadianColors.danger,
            ),
            child: const Text(
              'تلاش مجدد',
              style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    ),
  );
}

/// نمایشگر کد JSON پیش‌نمایش یا پاسخ SDK سامانه مودیان در باتم‌شیت تاریک حرفه‌ای.
Future<void> showMoadianJsonSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required String jsonText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        expand: false,
        builder: (_, controller) => Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.data_object_rounded,
                      color: Color(0xFF2DD4BF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle != null && subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: jsonText));
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('محتوای JSON کپی شد.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('کپی JSON'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2DD4BF),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF1E293B)),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(14),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      jsonText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.2,
                        height: 1.55,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
