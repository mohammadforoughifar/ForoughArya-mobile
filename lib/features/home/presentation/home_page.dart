// ============================================================
//  صفحهٔ اصلی اپ
//
//  ساختار (از بالا به پایین):
//    ۱. هدر گرادیانی — سلام، تاریخ شمسی، زنگولهٔ اعلان با هالهٔ نبضی
//    ۲. انتخابگر شرکت فعال
//    ۳. گزارش روزانه — کاروسل اسلایدی، یک کارت به ازای هر ماژول
//    ۴. ماژول‌ها — گرید کارت دو ستونی
//
//  اعلان‌ها عمداً در بدنهٔ صفحه نیستند؛ پشت زنگولهٔ هدر باز می‌شوند.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/home_repository.dart';
import '../models/home_models.dart';
import 'company_picker_sheet.dart';
import 'home_style.dart';
import 'notifications_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onOpenTab});

  /// با زدن روی کاشی ماژول، پوسته را به همان تب می‌بریم.
  final ValueChanged<int> onOpenTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeRepository _repo =
      HomeRepository(context.read<ApiClient>());

  CompanyContext _companies = CompanyContext.empty;
  Map<String, WidgetData> _widgetData = const {};
  List<HomeKpi> _kpis = const [];
  int _unread = 0;
  bool _loading = true;
  String? _error;

  final PageController _pc = PageController(viewportFraction: 0.9);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _kpis = buildKpiCards();
    _pc.addListener(() {
      final p = _pc.page ?? 0;
      if ((p - _page).abs() > 0.001 && mounted) setState(() => _page = p);
    });
    _load();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.fetchCompanies(),
        _repo.fetchUnreadCount(),
        _repo.fetchWidgets(_kpis.map((k) => k.widgetKey)),
      ]);
      if (!mounted) return;
      final companies = results[0] as CompanyContext;
      final unread = results[1] as int;
      final widgets = results[2] as Map<String, WidgetData>;
      setState(() {
        _companies = companies;
        _unread = unread;
        _widgetData = widgets;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _pickCompany(CompanyOption c) {
    setState(() {
      _companies = CompanyContext(
        companies: _companies.companies,
        activeCompanyId: c.id,
      );
    });
    // دادهٔ ویجت‌ها وابسته به شرکت است — دوباره خوانده می‌شود.
    _reloadWidgets();
  }

  Future<void> _reloadWidgets() async {
    final widgets = await _repo.fetchWidgets(_kpis.map((k) => k.widgetKey));
    if (!mounted) return;
    setState(() => _widgetData = widgets);
  }

  void _openCompanies() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompanyPickerSheet(
        context_: _companies,
        activeId: _companies.activeCompanyId,
        onPick: _pickCompany,
      ),
    );
  }

  Future<void> _openNotifications() async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationsSheet(repository: _repo),
    );
    // شمارندهٔ زنگوله بعد از بستن شیت به‌روز شود.
    final n = await _repo.fetchUnreadCount();
    if (mounted) setState(() => _unread = n);
  }

  void _openModule(ModuleTile m) {
    if (m.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شما به این ماژول دسترسی ندارید.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (m.tabIndex != null) {
      HapticFeedback.selectionClick();
      widget.onOpenTab(m.tabIndex!);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ماژول «${m.name}» در نسخهٔ وب در دسترس است.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = context.select<AuthController, String>(
      (a) => a.session?.displayName ?? '',
    );
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: HomeColors.seed,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _Header(
              name: name,
              unread: _unread,
              onBell: _openNotifications,
            ),
            SliverToBoxAdapter(
              child: HFadeSlideIn(
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _CompanyPill(
                    context_: _companies,
                    loading: _loading,
                    onTap: _openCompanies,
                  ),
                ),
              ),
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _ErrorBanner(message: _error!, onRetry: _load),
                ),
              ),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'گزارش روزانه',
                trailing: _loading
                    ? null
                    : TextButton.icon(
                        onPressed: _reloadWidgets,
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: const Text('به‌روزرسانی'),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: HomeColors.seed,
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
            SliverToBoxAdapter(child: _buildCarousel()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: HDots(count: _kpis.length, index: _page),
              ),
            ),
            const SliverToBoxAdapter(
              child: _SectionHeader(title: 'ماژول‌ها'),
            ),
            _buildModules(),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    if (_loading) {
      return SizedBox(
        height: 258,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => const HShimmer(
            width: 296,
            height: 250,
            radius: 24,
          ),
        ),
      );
    }
    return SizedBox(
      height: 268,
      child: PageView.builder(
        controller: _pc,
        itemCount: _kpis.length,
        padEnds: false,
        itemBuilder: (context, i) {
          final delta = _page - i;
          final abs = delta.abs();
          final scale = (1 - (abs * 0.09)).clamp(0.88, 1.0);
          final fade = (1 - (abs * 0.55)).clamp(0.45, 1.0);
          return AnimatedBuilder(
            animation: _pc,
            child: _KpiCard(
              kpi: _kpis[i],
              data: _widgetData[_kpis[i].widgetKey],
            ),
            builder: (_, child) => Transform.scale(
              scale: scale,
              child: Opacity(opacity: fade, child: child),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModules() {
    final tiles = buildModuleTiles(openTabs: const {1, 2, 3});
    if (_loading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 11,
            crossAxisSpacing: 11,
            childAspectRatio: 1.34,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, _) => const HShimmer(width: 170, height: 120, radius: 18),
            childCount: 6,
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 11,
          crossAxisSpacing: 11,
          childAspectRatio: 1.34,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => HFadeSlideIn(
            index: i,
            delayMs: 45,
            offsetY: 18,
            child: _ModuleCard(tile: tiles[i], onTap: () => _openModule(tiles[i])),
          ),
          childCount: tiles.length,
        ),
      ),
    );
  }
}

// ============================================================
//  بنر خطا
// ============================================================

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
    decoration: BoxDecoration(
      color: HomeColors.danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HomeColors.danger.withValues(alpha: 0.28)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.cloud_off_rounded,
          size: 19,
          color: HomeColors.danger,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.8,
              color: HomeColors.ink,
            ),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: HomeColors.danger,
          ),
          child: const Text(
            'تلاش دوباره',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

// ============================================================
//  هدر
// ============================================================

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.unread,
    required this.onBell,
  });

  final String name;
  final int unread;
  final VoidCallback onBell;

  String get _todayFa {
    final j = Jalali.now();
    final f = j.formatter;
    return '${f.wN} ${Fa.digits(j.day)} ${f.mN} ${Fa.digits(j.year)}';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(gradient: HomeColors.hero),
        child: Stack(
          children: [
            // حباب‌های تزئینی
            Positioned(
              left: -46,
              top: -34,
              child: _bubble(132, 0.10),
            ),
            Positioned(
              left: 62,
              top: 42,
              child: _bubble(66, 0.07),
            ),
            Positioned(
              right: -30,
              bottom: -40,
              child: _bubble(110, 0.08),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, top + 12, 16, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: HFadeSlideIn(
                      index: 0,
                      offsetY: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _todayFa,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name.isEmpty ? 'خوش آمدید' : 'سلام، $name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  HFadeSlideIn(
                    index: 1,
                    offsetY: 14,
                    child: _BellButton(unread: unread, onTap: onBell),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bubble(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HPressable(
    onTap: onTap,
    scale: 0.9,
    child: SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          if (unread > 0)
            Positioned(
              top: -3,
              left: -3,
              child: HPulseHalo(
                color: HomeColors.danger,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  height: 19,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HomeColors.danger,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: HomeColors.deep, width: 2),
                  ),
                  child: Text(
                    Fa.digits(unread > 99 ? '99+' : unread),
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

// ============================================================
//  نوار شرکت فعال
// ============================================================

class _CompanyPill extends StatelessWidget {
  const _CompanyPill({
    required this.context_,
    required this.loading,
    required this.onTap,
  });

  final CompanyContext context_;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = context_.active;
    return HPressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: HomeColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HomeColors.line),
          boxShadow: [
            BoxShadow(
              color: HomeColors.seed.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: active == null
                    ? null
                    : const LinearGradient(
                        colors: [HomeColors.seed, HomeColors.accent],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                color: active == null ? HomeColors.bg : null,
              ),
              child: active == null
                  ? const Icon(
                      Icons.apartment_rounded,
                      size: 18,
                      color: HomeColors.inkFaint,
                    )
                  : Text(
                      active.initials,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: loading
                  ? const HShimmer(width: 140, height: 26, radius: 8)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'شرکت فعال',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: HomeColors.inkFaint,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          active?.name ?? 'انتخاب شرکت',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: HomeColors.ink,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: HomeColors.ok.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${Fa.digits(context_.activeCount)} شرکت فعال',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: HomeColors.ok,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: HomeColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  عنوان بخش
// ============================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 10, 12),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 17,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: const LinearGradient(
              colors: [HomeColors.seed, HomeColors.accent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: HomeColors.ink,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

// ============================================================
//  کارت گزارش روزانه
// ============================================================

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi, this.data});

  final HomeKpi kpi;
  final WidgetData? data;

  @override
  Widget build(BuildContext context) {
    final value = data?.value ?? kpi.value;
    final delta = data == null
        ? kpi.deltaPercent
        : (data!.deltaUp == null ? null : (data!.deltaUp! ? 1.0 : -1.0));
    final deltaText = data?.deltaText;
    final spark = (data?.series.isNotEmpty ?? false) ? data!.series : kpi.spark;
    final rows = data?.rows ?? const <List<String>>[];

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12, top: 4, bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: HomeColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: HomeColors.line),
          boxShadow: [
            BoxShadow(
              color: kpi.from.withValues(alpha: 0.13),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // نوار گرادیانی بالا
              Positioned(
                top: 0,
                right: 0,
                left: 0,
                child: Container(height: 4, decoration: BoxDecoration(gradient: kpi.gradient)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            gradient: kpi.gradient,
                            boxShadow: [
                              BoxShadow(
                                color: kpi.from.withValues(alpha: 0.32),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(kpi.icon, size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kpi.moduleName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: HomeColors.ink,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                kpi.moduleSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: HomeColors.inkFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: HomeColors.bg,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'امروز',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: HomeColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        HCountUp(
                          value: value,
                          style: const TextStyle(
                            fontSize: 32,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.3,
                            color: HomeColors.ink,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            data?.unit ?? kpi.unit,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: HomeColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _Delta(delta: delta, text: deltaText),
                    const SizedBox(height: 2),
                    HSparkline(
                      values: spark.isEmpty
                          ? const [0, 1, 0.4, 1.6, 1.1, 2.0, 1.5]
                          : spark,
                      color: kpi.from,
                      height: 38,
                      width: 250,
                    ),
                    const SizedBox(height: 6),
                    Container(height: 1, color: HomeColors.line),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _KpiRows(
                        color: kpi.from,
                        live: rows,
                        fallback: kpi.rows,
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
}

class _Delta extends StatelessWidget {
  const _Delta({required this.delta, this.text});

  final double? delta;
  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text != null && text!.isNotEmpty) {
      final up = delta ?? 0;
      return Row(
        children: [
          Icon(
            up > 0
                ? Icons.trending_up_rounded
                : up < 0
                ? Icons.trending_down_rounded
                : Icons.trending_flat_rounded,
            size: 14,
            color: up > 0
                ? HomeColors.ok
                : up < 0
                ? HomeColors.danger
                : HomeColors.inkFaint,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: up > 0
                    ? HomeColors.ok
                    : up < 0
                    ? HomeColors.danger
                    : HomeColors.inkFaint,
              ),
            ),
          ),
        ],
      );
    }
    return const Text(
      'در انتظار دادهٔ سرور',
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: HomeColors.inkFaint,
      ),
    );
  }
}

class _KpiRows extends StatelessWidget {
  const _KpiRows({
    required this.color,
    required this.live,
    required this.fallback,
  });

  final Color color;
  final List<List<String>> live;
  final List<KpiRow> fallback;

  @override
  Widget build(BuildContext context) {
    // ردیف‌های سرور خودتوضیح‌اند (DashRowDto.Cells)؛ اگر رسیدند مستقیم
    // نمایش داده می‌شوند، وگرنه از برچسب‌های پیش‌فرض کارت استفاده می‌کنیم.
    final items = live.isNotEmpty
        ? [
            for (final r in live)
              (
                r.isNotEmpty ? r[0] : '—',
                r.length > 1 ? r[1] : '—',
                r.length > 2 && r[2].isNotEmpty ? r[2] : null,
              ),
          ]
        : [
            for (final r in fallback) (r.label, r.value, r.hint),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 7),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    items[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: HomeColors.inkSoft,
                    ),
                  ),
                ),
                Text(
                  items[i].$2,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: HomeColors.ink,
                  ),
                ),
                if ((items[i].$3 ?? '').isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    items[i].$3!,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ============================================================
//  کارت ماژول
// ============================================================

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.tile, required this.onTap});

  final ModuleTile tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HPressable(
    onTap: onTap,
    scale: 0.95,
    child: Opacity(
      opacity: tile.locked ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: HomeColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HomeColors.line),
          boxShadow: [
            BoxShadow(
              color: HomeColors.ink.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: tile.color.withValues(alpha: 0.13),
                  ),
                  child: Icon(tile.icon, size: 19, color: tile.color),
                ),
                const Spacer(),
                if (tile.locked)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: HomeColors.inkFaint,
                  )
                else if ((tile.badge ?? '').isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tile.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      tile.badge!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: tile.color,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              tile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: HomeColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tile.locked ? 'بدون مجوز' : tile.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: HomeColors.inkFaint,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
