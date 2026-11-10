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
import '../../misc/presentation/minutes_detail_page.dart';
import '../../misc/presentation/minutes_list_page.dart';
import '../data/notification_target.dart';
import '../../misc/presentation/misc_forms_page.dart';
import '../../office_automation/data/email_repository.dart';
import '../../office_automation/models/office_common.dart';
import '../../office_automation/presentation/letter_detail_page.dart';
import '../../work_orders/presentation/work_order_detail_page.dart';
import '../../office_automation/data/office_repository.dart';
import '../../work_orders/data/work_order_repository.dart';
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

  /// دادهٔ ویجت‌ها رسیده (یا شکست خورده) — برای نمایش «…» یا «—»
  bool _widgetsSettled = false;
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
    final api = context.read<ApiClient>();
    setState(() {
      _loading = true;
      _widgetsSettled = false;
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
      if (companies.activeCompanyId != null && companies.activeCompanyId! > 0) {
        await api.setCompanyId(companies.activeCompanyId);
      }
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _unread = unread;
        _loading = false;
      });
      await _loadWidgets(widgets);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// شرکت فعال را روی هدر شبکه ست می‌کند تا دادهٔ ویجت‌ها درست واکشی شود.
  Future<void> _ensureCompany() async {
    final api = context.read<ApiClient>();
    var id = _companies.activeCompanyId;
    if (id == null || id <= 0) {
      try {
        id = await api.ensureCompanyId();
      } catch (_) {
        id = null;
      }
      if (id != null) {
        _companies = CompanyContext(
          companies: _companies.companies,
          activeCompanyId: id,
        );
      }
    }
    if (id != null) {
      try {
        await api.setCompanyId(id);
      } catch (_) {
        // ست‌شدن هدر شرکت نباید کل صفحه را خراب کند
      }
    }
  }

  Future<void> _loadWidgets(Map<String, WidgetData> initial) async {
    setState(() => _widgetData = initial);
    await _ensureCompany();
    final keys = _kpis.map((k) => k.widgetKey).toList();
    var have = _widgetData;
    if (keys.any((k) => !have.containsKey(k))) {
      final again = await _repo.fetchWidgets(keys);
      if (!mounted) return;
      if (again.isNotEmpty) setState(() => _widgetData = again);
      have = again;
    }
    final missing = keys.where((k) => !have.containsKey(k)).toList();
    // ویجت‌های داشبورد سرور در دسترس نیستند → مستقیم از خود ماژول‌ها می‌خوانیم
    final fallback = missing.isEmpty
        ? const <String, WidgetData>{}
        : await _fallbackMetrics(missing);
    if (!mounted) return;
    setState(() {
      _widgetData = {..._widgetData, ...fallback};
      _widgetsSettled = true;
    });
  }

  /// دادهٔ عددی واقعی از endpointهای خود ماژول‌ها (وقتی dashboard-api جواب نمی‌دهد).
  Future<Map<String, WidgetData>> _fallbackMetrics(List<String> keys) async {
    final api = context.read<ApiClient>();
    final out = <String, WidgetData>{};
    final start = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // نامه‌ها — سه کارتابل داخلی/صادره/وارده
    if (keys.any((k) => k.startsWith('off-'))) {
      final repo = OfficeAutomationRepository(api);
      int inbox = 0, sent = 0, unread = 0, pish = 0, dab = 0, sign = 0;
      for (final kind in LetterKind.values) {
        try {
          final c = await repo.mailboxCounts(kind);
          inbox += c.inbox;
          sent += c.sent;
          pish += c.drafts;
          sign += c.signing;
          dab += c.dabirkhane;
        } catch (_) {}
      }
      try {
        final st = await repo.innerStats();
        unread += st.unread;
      } catch (_) {}
      if (keys.contains('off-letters-count')) {
        out['off-letters-count'] = WidgetData(
          key: 'off-letters-count',
          title: 'نامه‌ها',
          value: (inbox + sent).toDouble(),
          unit: 'نامه',
          rows: [
            ['وارده', Fa.digits(inbox)],
            ['صادره', Fa.digits(sent)],
            ['ارجاع نخوانده', Fa.digits(unread)],
          ],
        );
      }
      if (keys.contains('off-erja-unread')) {
        out['off-erja-unread'] = WidgetData(
          key: 'off-erja-unread',
          title: 'ارجاع‌های من',
          value: unread.toDouble(),
          unit: 'ارجاع نخوانده',
          rows: [
            ['پیش‌نویس', Fa.digits(pish)],
            ['در انتظار امضا', Fa.digits(sign)],
            ['دبیرخانه', Fa.digits(dab)],
          ],
        );
      }
    }

    // دستور کارها
    if (keys.contains('wo-open')) {
      try {
        final c = await WorkOrderRepository(api).counts();
        int pick(List<String> names) => names
            .map((n) => (c[n] as num?)?.toInt())
            .whereType<int>()
            .fold<int>(0, (a, b) => a + b);
        final open = pick([
          'open', 'Open', 'openCount', 'inProgress', 'inprogress', 'pending',
        ]);
        final overdue = pick(['overdue', 'Overdue', 'late', 'delayed']);
        final done = pick(['done', 'Done', 'closed', 'completed', 'doneCount']);
        out['wo-open'] = WidgetData(
          key: 'wo-open',
          title: 'دستور کار',
          value: open.toDouble(),
          unit: 'دستور کار باز',
          rows: [
            ['معوق', Fa.digits(overdue)],
            ['انجام‌شده', Fa.digits(done)],
          ],
        );
      } catch (_) {}
    }

    // ایمیل امروز (سازمانی)
    if (keys.contains('email-today')) {
      try {
        final r = await EmailRepository(api).inbox(
          pageSize: 100,
          dateFrom: start,
          dateTo: DateTime.now(),
        );
        out['email-today'] = WidgetData(
          key: 'email-today',
          title: 'ایمیل امروز',
          value: r.totalCount.toDouble(),
          unit: 'ایمیل',
        );
      } catch (_) {}
    }
    return out;
  }

  Future<void> _pickCompany(CompanyOption c) async {
    await context.read<ApiClient>().setCompanyId(c.id);
    if (!mounted) return;
    setState(() {
      _companies = CompanyContext(
        companies: _companies.companies,
        activeCompanyId: c.id,
      );
    });
    // دادهٔ ویجت‌ها وابسته به شرکت است — دوباره خوانده می‌شود.
    await _reloadWidgets();
  }

  Future<void> _reloadWidgets() async {
    final widgets = await _repo.fetchWidgets(_kpis.map((k) => k.widgetKey));
    if (!mounted) return;
    await _loadWidgets(widgets);
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

  /// کلیک روی اعلان → پیدا کردن «همان رکورد» و باز کردن مستقیم آن.
  /// (نه رفتن به صفحهٔ اصلی ماژول)
  Future<void> _openFromNotification(NotificationItem n) async {
    final messenger = ScaffoldMessenger.of(context);
    // نشانگر کوتاه تا کاربر بداند در حال باز شدن است
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('در حال باز کردن مورد مرتبط…'),
          ],
        ),
        duration: Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
      ),
    );

    NotificationTarget target;
    try {
      target = await NotificationResolver(
        context.read<ApiClient>(),
      ).resolve(n);
    } catch (e) {
      target = NotificationTarget(kind: 'none', reason: e.toString());
    }
    if (!mounted) return;
    messenger.hideCurrentSnackBar();

    if (target.isResolved) {
      switch (target.kind) {
        case 'wo':
          await _openExactTarget(target, n);
          return;
        case 'minutes':
          await _openExactTarget(target, n);
          return;
        case 'letter':
          await _openExactTarget(target, n);
          return;
        case 'email':
          widget.onOpenTab(3);
          return;
        default:
          break;
      }
    }

    // پیدا نشد: فقط در این حالت به ماژول مربوطه می‌رویم
    switch (target.kind) {
      case 'wo':
        widget.onOpenTab(1);
        return;
      case 'minutes':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MinutesListPage()),
        );
        return;
      default:
        widget.onOpenTab(2);
    }
  }

  /// باز کردن صفحهٔ جزئیات دقیقاً همان سند.
  Future<void> _openExactTarget(
    NotificationTarget target,
    NotificationItem n,
  ) async {
    switch (target.kind) {
      case 'wo':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WorkOrderDetailPage(id: target.id!),
          ),
        );
        return;
      case 'minutes':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MinutesDetailPage(minutesId: target.id!),
          ),
        );
        return;
      case 'letter':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LetterDetailPage(
              kind: target.letterKind ?? LetterKind.inner,
              letterId: target.id!,
              erjaId: target.erjaId ?? n.entityId,
            ),
          ),
        );
        return;
    }
  }

  Future<void> _openNotifications() async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationsSheet(
        repository: _repo,
        onOpen: _openFromNotification,
      ),
    );
    // شمارندهٔ زنگوله بعد از بستن شیت به‌روز شود.
    final n = await _repo.fetchUnreadCount();
    if (mounted) setState(() => _unread = n);
  }

  /// چرخ‌دندهٔ هدر — منوی کوتاه خروج و تغییر رمز عبور.
  Future<void> _openSettings() async {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthController>();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: HomeColors.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(
                  Icons.password_rounded,
                  color: HomeColors.seed,
                ),
                title: const Text(
                  'تغییر رمز عبور',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(c, 'password'),
              ),
              const Divider(height: 1),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: HomeColors.danger,
                ),
                title: const Text(
                  'خروج از حساب',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(c, 'logout'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'logout') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('خروج از حساب'),
          content: const Text('از حساب کاربری خارج می‌شوید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('خروج'),
            ),
          ],
        ),
      );
      if (ok == true) await auth.logout();
      return;
    }
    if (action == 'password') await _changePassword();
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final replacement = TextEditingController();
    final again = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تغییر رمز عبور'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'رمز فعلی'),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'رمز فعلی را وارد کنید.' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: replacement,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'رمز جدید'),
                validator: (v) => (v ?? '').length < 6
                    ? 'رمز جدید حداقل ۶ کاراکتر باشد.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: again,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تکرار رمز جدید',
                ),
                validator: (v) =>
                    v != replacement.text ? 'تکرار رمز یکسان نیست.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await context.read<AuthController>().changePassword(
          current.text,
          replacement.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رمز عبور تغییر کرد.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تغییر رمز انجام نشد: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
    current.dispose();
    replacement.dispose();
    again.dispose();
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
    if (m.onTapName == 'minutes') {
      HapticFeedback.selectionClick();
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MinutesListPage()));
      return;
    }
    if (m.onTapName == 'misc') {
      HapticFeedback.selectionClick();
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MiscFormsPage()));
      return;
    }
    // تا وقتی صفحهٔ اختصاصی این ماژول در موبایل نیست، «برگهٔ ماژول»
    // باز می‌شود تا کلیک بی‌اثر نماند.
    HapticFeedback.selectionClick();
    _openModuleSheet(m);
  }

  Future<void> _openModuleSheet(ModuleTile m) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(
            color: HomeColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: m.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(m.icon, color: m.color, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: HomeColors.ink,
                          ),
                        ),
                        Text(
                          m.subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: HomeColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'نسخهٔ وب این ماژول در دسترس است؛ نسخهٔ موبایل آن به‌زودی '
                'تکمیل می‌شود. تا آن زمان از داشبورد و ماژول‌های فعال '
                '(اتوماسیون، دستور کار، صورتجلسه، ایمیل) استفاده کنید.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.9,
                  color: HomeColors.inkSoft,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(c),
                  style: FilledButton.styleFrom(
                    backgroundColor: m.color,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('بستن'),
                ),
              ),
            ],
          ),
        ),
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
              onSettings: _openSettings,
            ),
            SliverToBoxAdapter(
              child: HFadeSlideIn(
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _CompanyPill(
                    context_: _companies,
                    loading: _loading || !_widgetsSettled,
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
            // فضای پایین برای نوار شیشه‌ای شناور
            const SliverToBoxAdapter(child: SizedBox(height: 104)),
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
              loading: _loading || !_widgetsSettled,
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
    required this.onSettings,
  });

  final String name;
  final int unread;
  final VoidCallback onBell;

  /// چرخ‌دندهٔ تنظیمات — خروج و تغییر رمز عبور
  final VoidCallback onSettings;

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
                  Row(
                    children: [
                      HFadeSlideIn(
                        index: 1,
                        offsetY: 14,
                        child: _BellButton(unread: unread, onTap: onBell),
                      ),
                      const SizedBox(width: 8),
                      // چرخ‌دنده سمت چپ زنگوله
                      HFadeSlideIn(
                        index: 2,
                        offsetY: 14,
                        child: _SettingsButton(onTap: onSettings),
                      ),
                    ],
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

/// چرخ‌دندهٔ تنظیمات هدر — خروج و تغییر رمز عبور
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HPressable(
    onTap: onTap,
    scale: 0.9,
    child: Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: const Icon(
        Icons.settings_rounded,
        size: 19,
        color: Colors.white,
      ),
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
  const _KpiCard({required this.kpi, this.data, this.loading = false});

  final HomeKpi kpi;
  final WidgetData? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final value = data?.value ?? kpi.value;
    // اگر سرور مقداری نداده باشد، «—» نمایش می‌دهیم نه صفرِ گمراه‌کننده.
    // مقدار اعشاری‌دار تا یک رقم اعشار (بدون وابستگی به en_US locale) نمایش داده می‌شود.
    final String? valueText = data?.value == null
        ? (loading ? '…' : '—')
        : (value == value.roundToDouble()
              ? Fa.number(value, decimals: 0)
              : Fa.number(value, decimals: 1));
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
                        if (valueText == null)
                          HCountUp(
                            value: value,
                            style: const TextStyle(
                              fontSize: 32,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.3,
                              color: HomeColors.ink,
                            ),
                          )
                        else
                          Text(
                            valueText,
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: HomeColors.inkSoft,
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
                    if (data == null && !loading)
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 12,
                            color: HomeColors.inkSoft,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'دادهٔ این ویجت از سرور دریافت نشد',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: HomeColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
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
            // داده‌ای از سرور نرسیده → عدد ساختگی/صفر نمایش نمی‌دهیم
            for (final r in fallback) (r.label, '—', r.hint),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // آیکون و بج وسط‌چین
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: tile.color.withValues(alpha: 0.13),
                  ),
                  child: Icon(tile.icon, size: 22, color: tile.color),
                ),
                if (tile.locked)
                  PositionedDirectional(
                    end: -6,
                    top: -4,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: HomeColors.inkFaint,
                    ),
                  )
                else if ((tile.badge ?? '').isNotEmpty)
                  PositionedDirectional(
                    end: -10,
                    top: -5,
                    child: Container(
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
                  ),
              ],
            ),
            const Spacer(),
            Text(
              tile.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: HomeColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tile.locked ? 'بدون مجوز' : tile.subtitle,
              maxLines: 1,
              textAlign: TextAlign.center,
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
