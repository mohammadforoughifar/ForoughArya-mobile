import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/moadian_perms.dart';
import '../data/moadian_repository.dart';
import 'moadian_style.dart';

class MoadianGuideTab extends StatefulWidget {
  const MoadianGuideTab({
    super.key,
    required this.activeCpInfoId,
    required this.onJumpToBasicSection,
  });

  final int activeCpInfoId;
  final ValueChanged<int> onJumpToBasicSection;

  @override
  State<MoadianGuideTab> createState() => _MoadianGuideTabState();
}

class _MoadianGuideTabState extends State<MoadianGuideTab> {
  late final MoadianRepository _repo = MoadianRepository(
    context.read<ApiClient>(),
  );
  bool _diagBusy = false;
  String _searchErr = '';

  static const List<({String code, String title, String fix})> _commonErrors = [
    (
      code: 'امضای دیجیتال / کلید خصوصی',
      title: 'خطای عدم تطابق امضا با گواهی ثبت‌شده در کارپوشه',
      fix:
          'کلید عمومی متناظر با کلید خصوصی PEM باید دقیقاً در کارپوشه my.tax.gov.ir روی همان شناسه یکتای ۶ کاراکتری حافظه مالیاتی بارگذاری شده باشد.',
    ),
    (
      code: 'مهلت قانونی تاریخ صدور',
      title: 'فاصله تاریخ صدور صورتحساب تا تاریخ ارسال بیش از حد مجاز سامانه است',
      fix:
          'سامانه مودیان بازه مجاز ثبت گذشته را محدود می‌کند (معمولاً ۷ تا ۲۱ روز بسته به بخشنامه جاری). تاریخ صدور را بررسی و اصلاح نمایید.',
    ),
    (
      code: 'شناسه ۱۳ رقمی CPC',
      title: 'شناسه کالا/خدمت نامعتبر یا غیرفعال در stuffid.tax.gov.ir',
      fix:
          'کد ۱۳ رقمی کالا و نرخ ارزش افزوده آن را دقیقاً مطابق سامانه stuffid.tax.gov.ir در بخش «کالا و خدمات» اصلاح کنید.',
    ),
    (
      code: 'کد اقتصادی / شناسه ملی خریدار',
      title: 'عدم اعتبار شماره اقتصادی یا کد ملی خریدار در صورتحساب نوع اول',
      fix:
          'در صورتحساب نوع اول، خریدار باید پرونده مالیاتی فعال داشته باشد؛ برای فروش به مصرف‌کننده نهایی بدون پرونده مالیاتی از «نوع دوم» استفاده کنید.',
    ),
    (
      code: 'وضعیت نامشخص شبکه (DeliveryUncertain)',
      title: 'بسته ارسال شد اما پاسخ شبکه قطع شد',
      fix:
          'از ارسال مجدد فوری خودداری کنید تا سند تکراری صادر نشود؛ ابتدا دکمه «استعلام وضعیت از سامانه» را بزنید یا کارپوشه را بررسی نمایید.',
    ),
  ];

  Future<void> _runDiagnose({required bool lists}) async {
    if (_diagBusy) return;
    setState(() => _diagBusy = true);
    try {
      final res = lists
          ? await _repo.diagnoseLists(widget.activeCpInfoId)
          : await _repo.diagnoseSchema();
      if (!mounted) return;
      final pretty = const JsonEncoder.withIndent('  ').convert(
        res.data ?? {'status': res.status, 'message': res.message},
      );
      await showMoadianJsonSheet(
        context,
        title: lists
            ? 'گزارش عیب‌یاب کوئری‌های پرونده (#${Fa.digits(widget.activeCpInfoId)})'
            : 'گزارش عیب‌یاب جداول و اسکیما (Moadian/Diagnose)',
        subtitle: res.message,
        jsonText: pretty,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _diagBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session;
    final canDiagnose = MoadianPerms.can(session, MoadianPerms.diagnose);

    final filteredErrors = _commonErrors.where((e) {
      if (_searchErr.trim().isEmpty) return true;
      final q = _searchErr.trim();
      return e.code.contains(q) || e.title.contains(q) || e.fix.contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
      children: [
        // نقشه راه گام‌به‌گام مودیان تیسا
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MoadianColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MoadianColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MoadianSectionTitle(
                title: 'راهنمای جامع کار با سامانه مودیان تیسا',
                subtitle: 'گام‌های استاندارد از راه‌اندازی کلید تا صدور و اصلاحیه',
              ),
              _GuideStepRow(
                step: '۱',
                title: 'ثبت شرکت و سال مالی',
                desc:
                    'مشخصات ثبتی، شماره اقتصادی، کد پستی ۱۰ رقمی و بازه سال مالی فعال را ثبت کنید.',
                actionLabel: 'بخش شرکت',
                onAction: () => widget.onJumpToBasicSection(0),
              ),
              const Divider(height: 16),
              _GuideStepRow(
                step: '۲',
                title: 'شناسه حافظه ۶ کاراکتری و کلید خصوصی RSA',
                desc:
                    'پس از بارگذاری کلید عمومی در my.tax.gov.ir، کلید خصوصی (.pem) و شناسه حافظه را وارد و با «تست زنده اتصال» بررسی کنید.',
                actionLabel: 'تنظیم اتصال',
                onAction: () => widget.onJumpToBasicSection(1),
              ),
              const Divider(height: 16),
              _GuideStepRow(
                step: '۳',
                title: 'تعریف کالا/خدمت با کد ۱۳ رقمی CPC و مشتریان',
                desc:
                    'شناسه‌های رسمی ۱۳ رقمی را از stuffid.tax.gov.ir استخراج و به همراه نرخ ارزش افزوده و واحد سنجش ثبت نمایید.',
                actionLabel: 'کالاهای CPC',
                onAction: () => widget.onJumpToBasicSection(2),
              ),
              const Divider(height: 16),
              const _GuideStepRow(
                step: '۴',
                title: 'صدور، پیش‌نمایش JSON، ارسال و استعلام',
                desc:
                    'برای فروش B2B از «نوع اول» و برای فروش مصرف‌کننده نهایی از «نوع دوم» استفاده کنید. پس از ارسال، با «استعلام» وضعیت نهایی را دریافت نمایید.',
              ),
              const Divider(height: 16),
              const _GuideStepRow(
                step: '۵',
                title: 'اسناد ارجاعی: اصلاحی، برگشت از فروش و ابطالی',
                desc:
                    'پس از ثبت صورتحساب اصلی در کارپوشه، تغییر آن تنها از طریق صدور سند «اصلاحی»، «برگشت از فروش» یا «ابطال» با ارجاع به کد مالیاتی ۲۲ رقمی امکان‌پذیر است.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // پیوندهای رسمی سازمان امور مالیاتی
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MoadianColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MoadianColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MoadianSectionTitle(
                title: 'درگاه‌های رسمی سازمان امور مالیاتی',
              ),
              _PortalCopyTile(
                title: 'کارپوشه ملی مودیان مالیاتی',
                url: 'https://my.tax.gov.ir',
              ),
              const SizedBox(height: 6),
              _PortalCopyTile(
                title: 'سامانه جستجوی شناسه ۱۳ رقمی کالا و خدمت (CPC)',
                url: 'https://stuffid.tax.gov.ir',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // فرهنگ کامل کدهای وضعیت ۰ تا ۱۱
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MoadianColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MoadianColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MoadianSectionTitle(
                title: 'جدول وضعیت‌های ۱۲گانه صورتحساب',
                subtitle: 'معنای هر وضعیت در چرخه مودیان تیسا',
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final code in const [
                    '0',
                    '1',
                    '2',
                    '3',
                    '4',
                    '5',
                    '6',
                    '7',
                    '8',
                    '9',
                    '10',
                    '11',
                  ])
                    MoadianStatusPill(code: code),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // خطایاب هوشمند مودیان
        const MoadianSectionTitle(
          title: 'دانشنامه رفع خطاهای رایج سامانه مودیان',
        ),
        TextField(
          onChanged: (v) => setState(() => _searchErr = v),
          decoration: InputDecoration(
            hintText: 'جستجو در خطاهای رایج (کلید خصوصی، CPC، تاریخ، خریدار)…',
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            isDense: true,
            filled: true,
            fillColor: MoadianColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: MoadianColors.line),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final err in filteredErrors)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: MoadianColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MoadianColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  err.code,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: MoadianColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  err.title,
                  style: const TextStyle(
                    fontSize: 12.4,
                    fontWeight: FontWeight.w800,
                    color: MoadianColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'راه‌حل: ${err.fix}',
                  style: const TextStyle(
                    fontSize: 11.2,
                    height: 1.6,
                    color: MoadianColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),

        // ابزار عیب‌یاب فنی مدیر سیستم (Diagnose)
        if (canDiagnose) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MoadianSectionTitle(
                  title: 'ابزار عیب‌یاب فنی مدیر سیستم (Diagnose)',
                  subtitle: 'بررسی سلامت جداول SQL و کوئری‌های مودیان روی سرور',
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _diagBusy
                            ? null
                            : () => _runDiagnose(lists: false),
                        icon: const Icon(Icons.storage_rounded, size: 17),
                        label: const Text(
                          'بررسی اسکیما',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _diagBusy || widget.activeCpInfoId <= 0
                            ? null
                            : () => _runDiagnose(lists: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: MoadianColors.indigo,
                        ),
                        icon: const Icon(Icons.troubleshoot_rounded, size: 17),
                        label: const Text(
                          'تست کوئری لیست‌ها',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GuideStepRow extends StatelessWidget {
  const _GuideStepRow({
    required this.step,
    required this.title,
    required this.desc,
    this.actionLabel,
    this.onAction,
  });

  final String step;
  final String title;
  final String desc;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: MoadianColors.heroGradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          step,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.6,
                      fontWeight: FontWeight.w900,
                      color: MoadianColors.ink,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 11.2,
                height: 1.6,
                color: MoadianColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PortalCopyTile extends StatelessWidget {
  const _PortalCopyTile({required this.title, required this.url});
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () async {
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('آدرس $url کپی شد.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: MoadianColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MoadianColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.language_rounded,
            size: 17,
            color: MoadianColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    url,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: MoadianColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.copy_rounded,
            size: 15,
            color: MoadianColors.inkSoft,
          ),
        ],
      ),
    ),
  );
}
