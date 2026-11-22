// ============================================================
//  «میز کار حرفه‌ای فروغ آریا» — صفحهٔ اصلی سازمان
//
//  ساختار میز کار (از بالا به پایین):
//    ۱. سربرگ فرماندهی (Executive Header) — سلام هوشمند، ساعت زنده و تاریخ شمسی،
//       فرمان‌یار جستجوی سریع (⌘)، شخصی‌سازی میز کار، اعلان‌ها، تنظیمات سرور،
//       انتخابگر شیشه‌ای شرکت فعال و نوار نبض زندهٔ سازمان (۴ شاخص فوری)
//    ۲. نوار عملیات سریع یک‌ضربه‌ای — صدور مستقیم فاکتور، نامه، دستور کار، سند خزانه…
//    ۳. کارتابل یکپارچه و میز اقدام (آینهٔ Cartable.razor وب) — سه تب:
//         • منتظر اقدام من (تجمیع زندهٔ ویزیتوری، توکا، رایکا، IT و آرشیو)
//         • اقدامات اصلی (موارد تازهٔ نیازمند نخستین اقدام)
//         • پیگیری‌ها (تأیید، ارجاع، کامنت و تغییر وضعیت)
//    ۴. شاخص‌های کلیدی عملکرد (KPI) — با کلید بازهٔ زمانی (امروز / هفته / ماه)
//       و ورود مستقیم با لمس هر کارت
//    ۵. ماژول‌های سازمان (۱۰۰٪ هم‌نام با وب: توکا، رایکا، کایر، میها، فیکا، تیسا…)
//       همراه فیلتر دسته‌بندی، سنجاق‌کردن به صدر میز کار، بج زنده و چیدمان ۲/۳ ستونی
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../../core/app_version.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/utils/fa.dart';
import '../../auth/connections_sheet.dart';
import '../../it_assets/data/doc_archive_repository.dart';
import '../../it_assets/data/it_request_repository.dart';
import '../../it_assets/models/it_request_models.dart';
import '../../it_assets/presentation/cctv_cameras_page.dart';
import '../../it_assets/presentation/doc_archive_cartable_page.dart';
import '../../it_assets/presentation/doc_archive_page.dart';
import '../../it_assets/presentation/it_home_page.dart';
import '../../it_assets/presentation/it_request_form_page.dart';
import '../../it_assets/presentation/it_requests_page.dart';
import '../../it_assets/presentation/network_scan_page.dart';
import '../../it_assets/presentation/server_management_page.dart';
import '../../it_assets/presentation/vault_page.dart';
import '../../messenger/data/chat_erp_api.dart';
import '../../misc/presentation/minutes_detail_page.dart';
import '../../misc/presentation/minutes_editor_page.dart';
import '../../misc/presentation/minutes_list_page.dart';
import '../../misc/presentation/misc_forms_page.dart';
import '../../moadian/data/moadian_repository.dart';
import '../../moadian/presentation/moadian_home_page.dart';
import '../../moadian/presentation/moadian_invoice_form_page.dart';
import '../../office_automation/data/email_repository.dart';
import '../../office_automation/data/office_repository.dart';
import '../../office_automation/presentation/letter_detail_page.dart';
import '../../office_automation/presentation/letter_editor_page.dart';
import '../../shop/data/shop_repository.dart';
import '../../shop/models/order_models.dart';
import '../../shop/models/treasury_models.dart';
import '../../shop/presentation/expenses_page.dart';
import '../../shop/presentation/kardex_page.dart';
import '../../shop/presentation/ops_dashboard_page.dart';
import '../../shop/presentation/order_form_page.dart';
import '../../shop/presentation/parties_page.dart';
import '../../shop/presentation/repairs_page.dart';
import '../../shop/presentation/sale_orders_page.dart';
import '../../shop/presentation/shop_home_page.dart';
import '../../shop/presentation/stock_page.dart';
import '../../shop/presentation/trs_cheques_page.dart';
import '../../shop/presentation/trs_dashboard_page.dart';
import '../../shop/presentation/trs_voucher_form_page.dart';
import '../../shop/presentation/vis_approvals_page.dart';
import '../../shop/presentation/vis_finance_queue_page.dart';
import '../../shop/presentation/visits_page.dart';
import '../../work_orders/data/work_order_repository.dart';
import '../../work_orders/presentation/work_order_detail_page.dart';
import '../../work_orders/presentation/work_order_editor_page.dart';
import '../data/home_repository.dart';
import '../data/notification_target.dart';
import '../models/home_models.dart';
import 'company_picker_sheet.dart';
import 'home_style.dart';
import 'notifications_sheet.dart';
import 'workbench_sheets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onOpenTab});

  /// با زدن روی کاشی ماژول یا میان‌بر تب، پوسته را به همان تب می‌بریم.
  final ValueChanged<int> onOpenTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _storage = FlutterSecureStorage();

  late final HomeRepository _repo = HomeRepository(context.read<ApiClient>());

  CompanyContext _companies = CompanyContext.empty;
  Map<String, WidgetData> _widgetData = const {};
  List<HomeKpi> _kpis = const [];
  WorkbenchPrefs _prefs = const WorkbenchPrefs();
  WorkbenchPulse _pulse = const WorkbenchPulse();
  int _moadianActionable = 0;
  int _moadianErrors = 0;

  // کارتابل یکپارچه و میز اقدام
  List<CartableEntry> _cartableEntries = const [];
  NotificationPageResult _mainNtfs = const NotificationPageResult();
  NotificationPageResult _subNtfs = const NotificationPageResult();
  int _cartableTab = 0; // ۰=منتظر اقدام · ۱=اقدامات اصلی · ۲=پیگیری‌ها
  bool _ntfUnreadOnly = false;
  bool _cartableLoading = true;

  // فیلتر ماژول‌ها و بازهٔ KPI
  String _moduleFilter = 'all';
  int _kpiRange = 0; // ۰=امروز · ۱=هفته · ۲=ماه
  bool _kpiRefreshing = false;

  int _unread = 0;
  bool _loading = true;
  bool _widgetsSettled = false;
  String? _error;

  final PageController _pc = PageController(viewportFraction: 0.9);
  final GlobalKey _cartableKey = GlobalKey();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _kpis = buildKpiCards();
    _pc.addListener(() {
      final p = _pc.page ?? 0;
      if ((p - _page).abs() > 0.001 && mounted) setState(() => _page = p);
    });
    _initPrefs();
    _load();
  }

  Future<void> _initPrefs() async {
    final loaded = await WorkbenchPrefs.load(_storage);
    if (mounted) setState(() => _prefs = loaded);
  }

  Future<void> _updatePrefs(WorkbenchPrefs next) async {
    setState(() => _prefs = next);
    await next.save(_storage);
  }

  void _togglePin(ModuleTile m) {
    HapticFeedback.lightImpact();
    final nextPins = Set<String>.from(_prefs.pinnedIds);
    final pinned = nextPins.contains(m.id);
    if (pinned) {
      nextPins.remove(m.id);
    } else {
      nextPins.add(m.id);
    }
    _updatePrefs(_prefs.copyWith(pinnedIds: nextPins));
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
      _cartableLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.fetchCompanies(),
        _repo.fetchUnreadCount(),
        _repo.fetchWidgets(_kpis.map((k) => k.widgetKey), range: _kpiRange),
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
      await Future.wait([
        _loadWidgets(widgets, range: _kpiRange),
        _loadWorkbenchCartable(unreadCount: unread),
      ]);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _cartableLoading = false;
        _error = e.toString();
      });
    }
  }

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
      } catch (_) {}
    }
  }

  /// بارگذاری همزمان کارتابل یکپارچه، اقدامات اصلی/فرعی و شمارنده‌های زندهٔ ماژول‌ها.
  Future<void> _loadWorkbenchCartable({int? unreadCount}) async {
    final api = context.read<ApiClient>();
    await _ensureCompany();

    // ۱) منابع رسمی سرور: /api/cartable/me و /api/notifications/page
    final serverCartableFuture = _repo.fetchUnifiedCartable();
    final mainNtfFuture = _repo.fetchNotificationPage(
      take: 6,
      category: 'main',
      unreadOnly: _ntfUnreadOnly,
    );
    final subNtfFuture = _repo.fetchNotificationPage(
      take: 6,
      category: 'sub',
      unreadOnly: _ntfUnreadOnly,
    );

    // فاز اول: نمایش فوری کارتابل و اعلان‌های سرور بدون معطل شدن روی ماژول‌های جانبی
    final serverCartable = await serverCartableFuture;
    final mainNtfs = await mainNtfFuture;
    final subNtfs = await subNtfFuture;
    if (!mounted) return;
    setState(() {
      _cartableEntries = List<CartableEntry>.from(serverCartable);
      _mainNtfs = mainNtfs;
      _subNtfs = subNtfs;
      _cartableLoading = false;
      _unread = unreadCount ?? (mainNtfs.unread > 0 ? mainNtfs.unread : _unread);
      _pulse = WorkbenchPulse(
        actionableCount: serverCartable
            .where((e) => e.actionable)
            .fold<int>(0, (s, e) => s + (e.badgeCount ?? 1)),
        unreadNotifications: _unread,
      );
    });

    // ۲) جمع‌آوری موازی وضعیت زنده از ماژول‌ها (هر کدام کاملاً مستقل و ایمن)
    int unreadLetters = 0;
    int signingLetters = 0;
    int dabirkhaneLetters = 0;
    int openWo = 0;
    int overdueWo = 0;
    int assignedWo = 0;
    int openItReq = 0;
    int pendingArchive = 0;
    int unreadChats = 0;
    final extraEntries = <CartableEntry>[];

    await Future.wait<void>([
      // اتوماسیون اداری توکا
      () async {
        final repo = OfficeAutomationRepository(api);
        try {
          final st = await repo.innerStats();
          unreadLetters += st.unread;
        } catch (_) {}
        for (final kind in LetterKind.values) {
          try {
            final c = await repo.mailboxCounts(kind);
            signingLetters += c.signing;
            dabirkhaneLetters += c.dabirkhane;
          } catch (_) {}
        }
        if (unreadLetters > 0) {
          extraEntries.add(
            CartableEntry(
              source: 'letters',
              kind: 'unread-erja',
              title: '${Fa.digits(unreadLetters)} ارجاع و نامهٔ خوانده‌نشده',
              subtitle: 'منتظر بررسی در کارتابل نامه‌ها',
              moduleLabel: 'اتوماسیون اداری توکا',
              targetKey: 'tab-2',
              icon: Icons.mark_email_unread_rounded,
              color: const Color(0xff0284c7),
              badgeCount: unreadLetters,
              priority: 2,
            ),
          );
        }
        if (signingLetters > 0) {
          extraEntries.add(
            CartableEntry(
              source: 'letters',
              kind: 'signing',
              title: '${Fa.digits(signingLetters)} نامه در انتظار امضای شما',
              subtitle: 'کارتابل امضای نامه‌های صادره',
              moduleLabel: 'اتوماسیون اداری توکا',
              targetKey: 'tab-2',
              icon: Icons.draw_rounded,
              color: const Color(0xff7c3aed),
              badgeCount: signingLetters,
              priority: 3,
            ),
          );
        }
        if (dabirkhaneLetters > 0) {
          extraEntries.add(
            CartableEntry(
              source: 'letters',
              kind: 'dabirkhane',
              title:
                  '${Fa.digits(dabirkhaneLetters)} نامه در صف شماره‌گذاری دبیرخانه',
              subtitle: 'دبیرخانه یکپارچه اتوماسیون اداری توکا',
              moduleLabel: 'اتوماسیون اداری توکا',
              targetKey: 'tab-2',
              icon: Icons.move_to_inbox_rounded,
              color: const Color(0xff0f766e),
              badgeCount: dabirkhaneLetters,
              priority: 2,
            ),
          );
        }
      }(),

      // دستورکار رایکا
      () async {
        try {
          final c = await WorkOrderRepository(api).counts();
          int pick(List<String> names) => names
              .map((n) => (c[n] as num?)?.toInt())
              .whereType<int>()
              .fold<int>(0, (a, b) => a + b);
          openWo = pick([
            'open',
            'Open',
            'openCount',
            'inProgress',
            'inprogress',
            'pending',
          ]);
          overdueWo = pick(['overdue', 'Overdue', 'late', 'delayed']);
          assignedWo = pick(['assigned', 'Assigned', 'assignedToMe', 'inbox']);
          if (overdueWo > 0) {
            extraEntries.add(
              CartableEntry(
                source: 'workorders',
                kind: 'overdue',
                title: '${Fa.digits(overdueWo)} دستور کار معوق (گذشته از مهلت)',
                subtitle: 'نیازمند پیگیری یا ثبت گزارش فوری',
                moduleLabel: 'دستورکار رایکا',
                targetKey: 'tab-1',
                icon: Icons.alarm_on_rounded,
                color: const Color(0xffdc2626),
                badgeCount: overdueWo,
                priority: 3,
              ),
            );
          }
          final activeInbox = assignedWo > 0 ? assignedWo : openWo;
          if (activeInbox > 0) {
            extraEntries.add(
              CartableEntry(
                source: 'workorders',
                kind: 'open',
                title: '${Fa.digits(activeInbox)} دستور کار باز در جریان',
                subtitle: 'مشاهده و ثبت اقدام در دستورکار رایکا',
                moduleLabel: 'دستورکار رایکا',
                targetKey: 'tab-1',
                icon: Icons.assignment_turned_in_rounded,
                color: const Color(0xffd97706),
                badgeCount: activeInbox,
                priority: 2,
              ),
            );
          }
        } catch (_) {}
      }(),

      // درخواست‌های خدمت IT (مدیریت سیستم — هم‌تراز با Cartable.razor وب)
      () async {
        try {
          final itRepo = ItRequestRepository(api);
          final access = await itRepo.myAccess();
          final mine = await itRepo.mine();
          final readyConfirm = mine.items
              .where((r) => r.status == ItRequestStatus.managerApproved)
              .length;
          if (readyConfirm > 0) {
            openItReq += readyConfirm;
            extraEntries.add(
              CartableEntry(
                source: 'it',
                kind: 'confirm',
                title:
                    'پاسخ ${Fa.digits(readyConfirm)} درخواست IT آمادهٔ تأیید شماست',
                subtitle: 'تأیید نهایی و بستن درخواست خدمت',
                moduleLabel: 'مدیریت سیستم',
                targetKey: 'it-requests',
                icon: Icons.task_alt_rounded,
                color: const Color(0xff0284c7),
                badgeCount: readyConfirm,
                priority: 2,
              ),
            );
          }
          if (access.isExpert) {
            final exp = await itRepo.expertInbox();
            final waitingReport = exp.items
                .where(
                  (r) =>
                      r.status == ItRequestStatus.assigned &&
                      r.assignments.any(
                        (a) =>
                            a.expertUserId == access.userId &&
                            !a.reportSubmitted,
                      ),
                )
                .length;
            if (waitingReport > 0) {
              openItReq += waitingReport;
              extraEntries.add(
                CartableEntry(
                  source: 'it',
                  kind: 'expert',
                  title:
                      '${Fa.digits(waitingReport)} درخواست IT منتظر گزارش کارشناسی شماست',
                  subtitle: 'کارتابل کارشناس مدیریت سیستم',
                  moduleLabel: 'مدیریت سیستم',
                  targetKey: 'it-requests',
                  icon: Icons.handyman_rounded,
                  color: const Color(0xffd97706),
                  badgeCount: waitingReport,
                  priority: 2,
                ),
              );
            }
          }
          if (access.isManager) {
            final mgr = await itRepo.managerInbox();
            final newReqs = mgr.items
                .where((r) => r.status == ItRequestStatus.created)
                .length;
            final waitingDecision = mgr.items
                .where(
                  (r) =>
                      r.status == ItRequestStatus.assigned &&
                      r.assignments.any((a) => a.pendingDecision),
                )
                .length;
            openItReq += newReqs + waitingDecision;
            if (newReqs > 0) {
              extraEntries.add(
                CartableEntry(
                  source: 'it',
                  kind: 'mgr-new',
                  title:
                      '${Fa.digits(newReqs)} درخواست جدید IT منتظر ارجاع مدیر',
                  subtitle: 'کارتابل مدیر زیرساخت و پشتیبانی',
                  moduleLabel: 'مدیریت سیستم',
                  targetKey: 'it-requests',
                  icon: Icons.support_agent_rounded,
                  color: const Color(0xff4f46e5),
                  badgeCount: newReqs,
                  priority: 3,
                ),
              );
            }
            if (waitingDecision > 0) {
              extraEntries.add(
                CartableEntry(
                  source: 'it',
                  kind: 'mgr-decision',
                  title:
                      'گزارش کارشناس برای ${Fa.digits(waitingDecision)} درخواست IT منتظر تصمیم شماست',
                  subtitle: 'تأیید یا رد گزارش کارشناس',
                  moduleLabel: 'مدیریت سیستم',
                  targetKey: 'it-requests',
                  icon: Icons.verified_user_outlined,
                  color: const Color(0xff059669),
                  badgeCount: waitingDecision,
                  priority: 2,
                ),
              );
            }
          }
        } catch (_) {}
      }(),

      // کارتابل آرشیو اسناد و مدارک
      () async {
        try {
          final page = await DocArchiveRepository(
            api,
          ).cartable(includeDone: false, take: 5);
          pendingArchive = page.total;
          if (pendingArchive > 0) {
            extraEntries.add(
              CartableEntry(
                source: 'doc-archive',
                kind: 'pending',
                title:
                    '${Fa.digits(pendingArchive)} مدرک در کارتابل آرشیو منتظر بررسی است',
                subtitle: 'تأیید یا تکمیل گردش مدارک سازمانی',
                moduleLabel: 'کارتابل آرشیو',
                targetKey: 'doc-cartable',
                icon: Icons.folder_copy_rounded,
                color: const Color(0xffea580c),
                badgeCount: pendingArchive,
                priority: 2,
              ),
            );
          }
        } catch (_) {}
      }(),

      // پیام رسان میها — خلاصهٔ سبک پیام‌های خوانده‌نشده از /api/chat/summary
      () async {
        try {
          final summary = await ChatErpApi(api).summary();
          unreadChats = summary.totalUnreadMessages;
        } catch (_) {}
      }(),

      // مودیان تیسا — شمارندهٔ صورتحساب‌های خطادار، پیش‌نویس و منتظر استعلام
      () async {
        try {
          final mRepo = MoadianRepository(api);
          final cps = await mRepo.getCpInfos();
          if (cps.isEmpty) {
            _moadianActionable = 0;
            _moadianErrors = 0;
            return;
          }
          final saved = await mRepo.loadSavedCpInfoId();
          final cpId = (saved != null && cps.any((c) => c.cpInfoId == saved))
              ? saved
              : cps.first.cpInfoId;
          final invRes = await mRepo.getInvoices(
            cpInfoId: cpId,
            operation: 'همه',
            page: 1,
            pageSize: 1,
          );
          final lbl = invRes.labels;
          _moadianErrors = lbl.hasError;
          _moadianActionable =
              lbl.notSent + lbl.hasError + lbl.waitingInquiry;
          if (lbl.hasError > 0) {
            extraEntries.add(
              CartableEntry(
                source: 'moadian',
                kind: 'error',
                title:
                    '${Fa.digits(lbl.hasError)} صورتحساب مودیان دارای خطای برگشتی سامانه است',
                subtitle: 'بررسی خطا، اصلاح و ارسال مجدد در مودیان تیسا',
                moduleLabel: 'مودیان تیسا',
                targetKey: 'moadian-error',
                icon: Icons.error_outline_rounded,
                color: const Color(0xffdc2626),
                badgeCount: lbl.hasError,
                priority: 3,
              ),
            );
          }
          if (lbl.notSent > 0) {
            extraEntries.add(
              CartableEntry(
                source: 'moadian',
                kind: 'draft',
                title:
                    '${Fa.digits(lbl.notSent)} پیش‌نویس صورتحساب آمادهٔ امضا و ارسال به مودیان',
                subtitle: 'ارسال رسمی به کارپوشه مالیاتی tp.tax.gov.ir',
                moduleLabel: 'مودیان تیسا',
                targetKey: 'moadian-draft',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xff0f766e),
                badgeCount: lbl.notSent,
                priority: 2,
              ),
            );
          }
          if (lbl.waitingInquiry > 0) {
            extraEntries.add(
              CartableEntry(
                source: 'moadian',
                kind: 'inquiry',
                title:
                    '${Fa.digits(lbl.waitingInquiry)} صورتحساب ارسال‌شده منتظر استعلام نتیجه است',
                subtitle: 'دریافت وضعیت نهایی از سامانه مودیان',
                moduleLabel: 'مودیان تیسا',
                targetKey: 'moadian-inquiry',
                icon: Icons.sync_rounded,
                color: const Color(0xff0284c7),
                badgeCount: lbl.waitingInquiry,
                priority: 2,
              ),
            );
          }
        } catch (_) {
          _moadianActionable = 0;
          _moadianErrors = 0;
        }
      }(),
    ]);

    if (!mounted) return;

    final merged = <CartableEntry>[...serverCartable, ...extraEntries]
      ..sort((a, b) {
        if (a.actionable != b.actionable) return a.actionable ? -1 : 1;
        return b.priority.compareTo(a.priority);
      });

    final totalActionable = merged
        .where((e) => e.actionable)
        .fold<int>(0, (s, e) => s + (e.badgeCount ?? 1));

    setState(() {
      _cartableEntries = merged;
      _pulse = WorkbenchPulse(
        actionableCount: totalActionable,
        unreadLetters: unreadLetters,
        signingLetters: signingLetters,
        openWorkOrders: openWo,
        overdueWorkOrders: overdueWo,
        unreadNotifications: _unread,
        unreadChats: unreadChats,
        openItRequests: openItReq,
        pendingArchiveTasks: pendingArchive,
      );
    });
  }

  Future<void> _reloadNotificationsOnly() async {
    final results = await Future.wait([
      _repo.fetchNotificationPage(
        take: 6,
        category: 'main',
        unreadOnly: _ntfUnreadOnly,
      ),
      _repo.fetchNotificationPage(
        take: 6,
        category: 'sub',
        unreadOnly: _ntfUnreadOnly,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _mainNtfs = results[0];
      _subNtfs = results[1];
    });
  }

  Future<void> _loadWidgets(
    Map<String, WidgetData> initial, {
    required int range,
  }) async {
    setState(() => _widgetData = initial);
    await _ensureCompany();
    final keys = _kpis.map((k) => k.widgetKey).toList();
    var have = _widgetData;
    if (keys.any((k) => !have.containsKey(k))) {
      final again = await _repo.fetchWidgets(keys, range: range);
      if (!mounted) return;
      if (again.isNotEmpty) setState(() => _widgetData = again);
      have = again;
    }
    final missing = keys.where((k) => !have.containsKey(k)).toList();
    final fallback = missing.isEmpty
        ? const <String, WidgetData>{}
        : await _fallbackMetrics(missing, range: range);
    if (!mounted) return;
    setState(() {
      _widgetData = {..._widgetData, ...fallback};
      _widgetsSettled = true;
      _kpiRefreshing = false;
    });
  }

  /// دادهٔ عددی واقعی از endpointهای خود ماژول‌ها (وقتی ویجت داشبورد سرور تنظیم نشده است).
  Future<Map<String, WidgetData>> _fallbackMetrics(
    List<String> keys, {
    required int range,
  }) async {
    final api = context.read<ApiClient>();
    final out = <String, WidgetData>{};
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final rangeStart = switch (range) {
      1 => todayStart.subtract(const Duration(days: 6)),
      2 => todayStart.subtract(const Duration(days: 29)),
      _ => todayStart,
    };

    await Future.wait<void>([
      // فروشگاهی کایر — فروش، خرید، خزانه و نقطه سفارش
      if (keys.any(
        (k) =>
            k == 'fac-sales-today' ||
            k == 'trs-receipt-period' ||
            k == 'inv-doc-count',
      ))
        () async {
          final shop = ShopRepository(api);
          int reorderCount = 0;
          try {
            final ro = await shop.reorderItems(take: 1);
            reorderCount = ro.total ?? ro.items.length;
          } catch (_) {}

          if (keys.contains('fac-sales-today')) {
            try {
              final ops = await shop.opsDashboard(from: rangeStart, to: now);
              out['fac-sales-today'] = WidgetData(
                key: 'fac-sales-today',
                title: 'فروش و فاکتور',
                value: ops.saleTotal / 1000000.0,
                unit: 'میلیون ریال',
                deltaText: '${Fa.digits(ops.saleCount)} فاکتور فروش ثبت‌شده',
                deltaUp: ops.saleCount > 0 ? true : null,
                rows: [
                  ['فاکتور فروش', Fa.digits(ops.saleCount), 'سند'],
                  ['فاکتور خرید', Fa.digits(ops.purchaseCount), 'سند'],
                  ['زیر نقطه سفارش', Fa.digits(reorderCount), 'قلم'],
                ],
                series: ops.trend
                    .map((t) => t.sale / 1000000.0)
                    .toList(),
              );
            } catch (_) {}
          }

          if (keys.contains('trs-receipt-period')) {
            try {
              final trs = await shop.treasuryDashboard(
                from: rangeStart,
                to: now,
              );
              out['trs-receipt-period'] = WidgetData(
                key: 'trs-receipt-period',
                title: 'خزانه و چک',
                value: trs.periodIn / 1000000.0,
                unit: 'میلیون ریال',
                deltaText:
                    'موجودی نقد و بانک: ${Fa.number(trs.totalBalance / 1000000.0, decimals: 1)} م.ر',
                deltaUp: trs.periodIn >= trs.periodOut,
                rows: [
                  [
                    'دریافت دوره',
                    Fa.number(trs.periodIn / 1000000.0, decimals: 1),
                    'م.ر',
                  ],
                  [
                    'پرداخت دوره',
                    Fa.number(trs.periodOut / 1000000.0, decimals: 1),
                    'م.ر',
                  ],
                  ['چک سررسیدشده', Fa.digits(trs.overdueChequeCount), 'فقره'],
                ],
              );
            } catch (_) {}
          }

          if (keys.contains('inv-doc-count') && reorderCount > 0) {
            out['inv-doc-count'] = WidgetData(
              key: 'inv-doc-count',
              title: 'انبار و موجودی',
              value: reorderCount.toDouble(),
              unit: 'قلم زیر نقطه سفارش',
              rows: [
                ['اقلام زیر نقطه سفارش', Fa.digits(reorderCount), 'قلم'],
              ],
            );
          }
        }(),

      // اتوماسیون اداری توکا
      if (keys.any((k) => k.startsWith('off-')))
        () async {
          final repo = OfficeAutomationRepository(api);
          int inbox = 0, sent = 0, unread = 0, pish = 0, dab = 0, sign = 0;
          var anyOk = false;
          for (final kind in LetterKind.values) {
            try {
              final c = await repo.mailboxCounts(kind);
              inbox += c.inbox;
              sent += c.sent;
              pish += c.drafts;
              sign += c.signing;
              dab += c.dabirkhane;
              anyOk = true;
            } catch (_) {}
          }
          try {
            final st = await repo.innerStats();
            unread += st.unread;
            anyOk = true;
          } catch (_) {}
          if (!anyOk) return;
          if (keys.contains('off-letters-count')) {
            out['off-letters-count'] = WidgetData(
              key: 'off-letters-count',
              title: 'دبیرخانه و نامه‌ها',
              value: (inbox + sent).toDouble(),
              unit: 'نامه',
              deltaText: unread > 0
                  ? '${Fa.digits(unread)} ارجاع خوانده‌نشده در کارتابل'
                  : 'بدون ارجاع خوانده‌نشده',
              deltaUp: unread == 0 ? true : null,
              rows: [
                ['وارده', Fa.digits(inbox), 'نامه'],
                ['صادره', Fa.digits(sent), 'نامه'],
                ['ارجاع نخوانده', Fa.digits(unread), 'مورد'],
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
                ['پیش‌نویس', Fa.digits(pish), 'نامه'],
                ['در انتظار امضا', Fa.digits(sign), 'نامه'],
                ['صف دبیرخانه', Fa.digits(dab), 'نامه'],
              ],
            );
          }
        }(),

      // دستورکار رایکا
      if (keys.contains('wo-open'))
        () async {
          try {
            final c = await WorkOrderRepository(api).counts();
            int pick(List<String> names) => names
                .map((n) => (c[n] as num?)?.toInt())
                .whereType<int>()
                .fold<int>(0, (a, b) => a + b);
            final open = pick([
              'open',
              'Open',
              'openCount',
              'inProgress',
              'inprogress',
              'pending',
            ]);
            final overdue = pick(['overdue', 'Overdue', 'late', 'delayed']);
            final done = pick([
              'done',
              'Done',
              'closed',
              'completed',
              'doneCount',
            ]);
            final assigned = pick([
              'assigned',
              'Assigned',
              'assignedToMe',
              'inbox',
            ]);
            out['wo-open'] = WidgetData(
              key: 'wo-open',
              title: 'دستورکار رایکا',
              value: open.toDouble(),
              unit: 'دستور کار باز',
              deltaText: overdue > 0
                  ? '${Fa.digits(overdue)} دستور کار معوق نیازمند پیگیری'
                  : 'بدون تأخیر در دستورهای باز',
              deltaUp: overdue == 0,
              rows: [
                ['معوق', Fa.digits(overdue), 'مورد'],
                ['انجام‌شده', Fa.digits(done), 'مورد'],
                ['محول به من', Fa.digits(assigned), 'مورد'],
              ],
            );
          } catch (_) {}
        }(),

      // درخواست خدمت IT
      if (keys.contains('it-open'))
        () async {
          try {
            final itRepo = ItRequestRepository(api);
            final access = await itRepo.myAccess();
            final mine = await itRepo.mine();
            final myOpen = mine.items.where((r) => r.open).length;
            int expOpen = 0;
            int mgrOpen = 0;
            if (access.isExpert) {
              final e = await itRepo.expertInbox();
              expOpen = e.items.where((r) => r.open).length;
            }
            if (access.isManager) {
              final m = await itRepo.managerInbox();
              mgrOpen = m.items.where((r) => r.open).length;
            }
            final totalOpen = mgrOpen > 0 ? mgrOpen : (myOpen + expOpen);
            out['it-open'] = WidgetData(
              key: 'it-open',
              title: 'درخواست خدمت IT',
              value: totalOpen.toDouble(),
              unit: 'درخواست باز',
              rows: [
                ['درخواست‌های من', Fa.digits(myOpen), 'مورد'],
                ['کارتابل کارشناس', Fa.digits(expOpen), 'مورد'],
                ['کارتابل مدیر', Fa.digits(mgrOpen), 'مورد'],
              ],
            );
          } catch (_) {}
        }(),

      // ایمیل سازمانی
      if (keys.contains('email-today'))
        () async {
          try {
            final r = await EmailRepository(api).inbox(
              pageSize: 100,
              dateFrom: rangeStart,
              dateTo: now,
            );
            out['email-today'] = WidgetData(
              key: 'email-today',
              title: 'ایمیل سازمانی',
              value: r.totalCount.toDouble(),
              unit: 'ایمیل',
            );
          } catch (_) {}
        }(),
    ]);

    return out;
  }

  Future<void> _switchKpiRange(int nextRange) async {
    if (_kpiRange == nextRange) return;
    HapticFeedback.selectionClick();
    setState(() {
      _kpiRange = nextRange;
      _kpiRefreshing = true;
    });
    final widgets = await _repo.fetchWidgets(
      _kpis.map((k) => k.widgetKey),
      range: nextRange,
    );
    if (!mounted) return;
    await _loadWidgets(widgets, range: nextRange);
  }

  Future<void> _reloadWidgets() async {
    HapticFeedback.lightImpact();
    setState(() => _kpiRefreshing = true);
    final widgets = await _repo.fetchWidgets(
      _kpis.map((k) => k.widgetKey),
      range: _kpiRange,
    );
    if (!mounted) return;
    await _loadWidgets(widgets, range: _kpiRange);
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
    await PushService.instance.onCompanyChanged();
    if (!mounted) return;
    try {
      final unread = await _repo.fetchUnreadCount();
      if (mounted) setState(() => _unread = unread);
    } catch (_) {}
    await Future.wait([
      _reloadWidgets(),
      _loadWorkbenchCartable(),
    ]);
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

  void _pushPage(Widget page) {
    HapticFeedback.selectionClick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page)).then((_) {
      if (mounted) _loadWorkbenchCartable();
    });
  }

  void _openTargetKey(String key) {
    if (key.isEmpty) return;
    switch (key) {
      case 'tab-1':
        HapticFeedback.selectionClick();
        widget.onOpenTab(1);
        return;
      case 'tab-2':
        HapticFeedback.selectionClick();
        widget.onOpenTab(2);
        return;
      case 'tab-3':
        HapticFeedback.selectionClick();
        widget.onOpenTab(3);
        return;
      case 'tab-4':
        HapticFeedback.selectionClick();
        widget.onOpenTab(4);
        return;
      case 'shop-ops':
        _pushPage(const OpsDashboardPage());
        return;
      case 'shop-trs':
        _pushPage(const TrsDashboardPage());
        return;
      case 'shop-stock':
        _pushPage(const StockPage());
        return;
      case 'sale-orders':
        _pushPage(const SaleOrdersPage(type: TxnType.sale));
        return;
      case 'vis-approvals':
        _pushPage(const VisApprovalsPage());
        return;
      case 'vis-finance':
        _pushPage(const VisFinanceQueuePage());
        return;
      case 'vis-orders':
        _pushPage(const VisitsPage());
        return;
      case 'it-requests':
        _pushPage(const ItRequestsPage());
        return;
      case 'doc-cartable':
        _pushPage(const DocArchiveCartablePage());
        return;
      case 'moadian':
        _pushPage(const MoadianHomePage());
        return;
      case 'moadian-error':
        _pushPage(
          const MoadianHomePage(initialTab: 1, initialInvoiceFilter: '5'),
        );
        return;
      case 'moadian-draft':
        _pushPage(
          const MoadianHomePage(initialTab: 1, initialInvoiceFilter: '0'),
        );
        return;
      case 'moadian-inquiry':
        _pushPage(
          const MoadianHomePage(initialTab: 1, initialInvoiceFilter: '1'),
        );
        return;
      default:
        _pushPage(const ShopHomePage());
    }
  }

  /// ساخت فهرست کامل فرمان‌یار جستجوی سریع (Command Palette) در سراسر نرم‌افزار.
  List<WorkbenchCommandItem> _buildCommandItems(List<ModuleTile> modules) => [
    // عملیات سریع
    WorkbenchCommandItem(
      title: 'صدور صورتحساب الکترونیکی مودیان',
      subtitle: 'مودیان تیسا • ارسال رسمی به کارپوشه مالیاتی',
      group: 'عملیات سریع یک‌ضربه‌ای',
      icon: Icons.post_add_rounded,
      color: const Color(0xff0f766e),
      keywords: const [
        'صورتحساب مودیان',
        'مودیان تیسا',
        'فاکتور مالیاتی',
        'سامانه مودیان',
      ],
      onSelect: () => _pushPage(const MoadianInvoiceFormPage()),
    ),
    WorkbenchCommandItem(
      title: 'صدور فاکتور فروش جدید',
      subtitle: 'فروشگاهی کایر • عملیات فروش',
      group: 'عملیات سریع یک‌ضربه‌ای',
      icon: Icons.add_shopping_cart_rounded,
      color: const Color(0xff2563eb),
      keywords: const ['فاکتور فروش', 'فروش جدید', 'کایر'],
      onSelect: () => _pushPage(const OrderFormPage(type: TxnType.sale)),
    ),
    WorkbenchCommandItem(
      title: 'ثبت فاکتور خرید جدید',
      subtitle: 'فروشگاهی کایر • عملیات خرید',
      group: 'عملیات سریع یک‌ضربه‌ای',
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xff0f766e),
      keywords: const ['فاکتور خرید', 'خرید جدید', 'کایر'],
      onSelect: () => _pushPage(const OrderFormPage(type: TxnType.purchase)),
    ),
    WorkbenchCommandItem(
      title: 'صدور پیش‌فاکتور فروش',
      subtitle: 'فروشگاهی کایر • پیش‌فاکتور',
      group: 'عملیات سریع یک‌ضربه‌ای',
      icon: Icons.request_quote_rounded,
      color: const Color(0xff4f46e5),
      keywords: const ['پیش فاکتور', 'پیش‌فاکتور'],
      onSelect: () => _pushPage(
        const OrderFormPage(type: TxnType.sale, isProforma: true),
      ),
    ),
    WorkbenchCommandItem(
      title: 'ثبت نامهٔ داخلی جدید',
      subtitle: 'اتوماسیون اداری توکا',
      group: 'عملیات سریع یک‌ضربه‌ای',
      icon: Icons.outgoing_mail,
      color: const Color(0xff2547a8),
      keywords: const ['نامه جدید', 'نامه داخلی', 'توکا', 'اتوماسیون'],
      onSelect: () =>
          _pushPage(const LetterEditorPage(kind: LetterKind.inner)),
    ),
    WorkbenchCommandItem(
      title: 'ثبت دستور کار جدید',
      subtitle: 'دستورکار رایکا',
      group: 'عملیات سریع یک‌ضربه‌ای',
      icon: Icons.playlist_add_check_circle_rounded,
      color: const Color(0xffd97706),
      keywords: const ['دستور کار جدید', 'دستورکار', 'رایکا'],
      onSelect: () => _pushPage(const WorkOrderEditorPage()),
    ),
    WorkbenchCommandItem(
      title: 'ثبت سند دریافت خزانه',
      subtitle: 'فروشگاهی کایر • خزانه‌داری',
      group: 'عملیات سریع یک‌ضربه‌ای',
      icon: Icons.south_west_rounded,
      color: const Color(0xff059669),
      keywords: const ['سند دریافت', 'دریافت وجه', 'تسویه', 'خزانه'],
      onSelect: () =>
          _pushPage(const TrsVoucherFormPage(kind: TrsKind.receipt)),
    ),
    WorkbenchCommandItem(
      title: 'ثبت سند پرداخت خزانه',
      subtitle: 'فروشگاهی کایر • خزانه‌داری',
      group: 'عملیات سریع یک‌ضربه‌ای',
      icon: Icons.north_east_rounded,
      color: const Color(0xffdc2626),
      keywords: const ['سند پرداخت', 'پرداخت وجه', 'خزانه'],
      onSelect: () =>
          _pushPage(const TrsVoucherFormPage(kind: TrsKind.payment)),
    ),
    WorkbenchCommandItem(
      title: 'تنظیم صورتجلسهٔ جدید',
      subtitle: 'فرم‌های متفرقه • صورتجلسه',
      group: 'عملیات سریع یک‌ضربه‌ای',
      icon: Icons.note_add_rounded,
      color: const Color(0xff059669),
      keywords: const ['صورتجلسه جدید', 'مصوبه'],
      onSelect: () => _pushPage(const MinutesEditorPage()),
    ),
    WorkbenchCommandItem(
      title: 'ثبت درخواست خدمت IT',
      subtitle: 'مدیریت سیستم • پشتیبانی فنی',
      group: 'عملیات سریع یک‌ضربه‌ای',
      icon: Icons.support_agent_rounded,
      color: const Color(0xff4f46e5),
      keywords: const ['درخواست IT', 'تیکت', 'خرابی سیستم'],
      onSelect: () => _pushPage(const ItRequestFormPage()),
    ),

    // همهٔ ماژول‌های سازمان (هم‌نام با وب)
    for (final m in modules)
      WorkbenchCommandItem(
        title: m.name,
        subtitle: m.subtitle,
        group: 'ماژول‌های سازمان',
        icon: m.icon,
        color: m.color,
        keywords: m.keywords,
        badge: m.liveCount > 0 ? Fa.digits(m.liveCount) : m.badge,
        onSelect: () => _openModule(m),
      ),

    // زیربخش‌های کلیدی پرکاربرد
    WorkbenchCommandItem(
      title: 'داشبورد عملیاتی خرید، فروش و تعمیرات',
      subtitle: 'فروشگاهی کایر • داشبورد',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.query_stats_rounded,
      color: const Color(0xff2563eb),
      keywords: const ['داشبورد عملیاتی', 'آمار فروش'],
      onSelect: () => _pushPage(const OpsDashboardPage()),
    ),
    WorkbenchCommandItem(
      title: 'مدیریت چک‌های دریافتی و پرداختی',
      subtitle: 'فروشگاهی کایر • خزانه‌داری',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.payments_outlined,
      color: const Color(0xff059669),
      keywords: const ['چک', 'سررسید چک', 'واگذاری'],
      onSelect: () => _pushPage(const TrsChequesPage()),
    ),
    WorkbenchCommandItem(
      title: 'موجودی لحظه‌ای انبارها',
      subtitle: 'فروشگاهی کایر • کالا و انبار',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.inventory_2_outlined,
      color: const Color(0xfff97316),
      keywords: const ['موجودی', 'انبار', 'کالا'],
      onSelect: () => _pushPage(const StockPage()),
    ),
    WorkbenchCommandItem(
      title: 'کاردکس کالا (تعدادی و ریالی)',
      subtitle: 'فروشگاهی کایر • گزارش‌ها',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.list_alt_rounded,
      color: const Color(0xff0891b2),
      keywords: const ['کاردکس', 'گردش کالا'],
      onSelect: () => _pushPage(const KardexPage()),
    ),
    WorkbenchCommandItem(
      title: 'طرف حساب‌ها (مشتریان و تأمین‌کنندگان)',
      subtitle: 'فروشگاهی کایر • اطلاعات پایه',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.people_alt_rounded,
      color: const Color(0xff4f46e5),
      keywords: const ['مشتری', 'تأمین کننده', 'طرف حساب'],
      onSelect: () => _pushPage(const PartiesPage()),
    ),
    WorkbenchCommandItem(
      title: 'تعمیرات، گارانتی و طرح تعویض',
      subtitle: 'فروشگاهی کایر • عملیات',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.build_circle_outlined,
      color: const Color(0xffd97706),
      keywords: const ['تعمیرات', 'گارانتی', 'طرح تعویض'],
      onSelect: () => _pushPage(const RepairsPage()),
    ),
    WorkbenchCommandItem(
      title: 'فهرست و کارپوشه صورتحساب‌های مودیان',
      subtitle: 'مودیان تیسا • ارسال، استعلام، اصلاحیه و ابطال',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.receipt_long_rounded,
      color: const Color(0xff0f766e),
      keywords: const ['کارپوشه مودیان', 'استعلام مودیان', 'اصلاحیه', 'ابطالی'],
      onSelect: () => _pushPage(const MoadianHomePage(initialTab: 1)),
    ),
    WorkbenchCommandItem(
      title: 'اتصال، حافظه مالیاتی و کلید خصوصی RSA',
      subtitle: 'مودیان تیسا • اطلاعات پایه و تست اتصال',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.vpn_key_rounded,
      color: const Color(0xff0d9488),
      keywords: const ['کلید خصوصی', 'حافظه مالیاتی', 'PEM', 'تست اتصال مودیان'],
      onSelect: () => _pushPage(
        const MoadianHomePage(initialTab: 2, initialBasicSection: 1),
      ),
    ),
    WorkbenchCommandItem(
      title: 'کالا و خدمات دارای کد ۱۳ رقمی CPC',
      subtitle: 'مودیان تیسا • شناسه‌های stuffid.tax.gov.ir',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.qr_code_2_rounded,
      color: const Color(0xff0f766e),
      keywords: const ['CPC', 'شناسه کالا', '۱۳ رقمی', 'stuffid'],
      onSelect: () => _pushPage(
        const MoadianHomePage(initialTab: 2, initialBasicSection: 2),
      ),
    ),
    WorkbenchCommandItem(
      title: 'هزینه‌های فروشگاه',
      subtitle: 'فروشگاهی کایر • مالی',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.receipt_rounded,
      color: const Color(0xffdc2626),
      keywords: const ['هزینه', 'ثبت هزینه'],
      onSelect: () => _pushPage(const ExpensesPage()),
    ),
    WorkbenchCommandItem(
      title: 'گاوصندوق رمزهای سازمانی',
      subtitle: 'مدیریت سیستم • امنیت',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.enhanced_encryption_rounded,
      color: const Color(0xff3730a3),
      keywords: const ['گاوصندوق', 'پسورد', 'رمز', 'vault'],
      onSelect: () => _pushPage(const VaultPage()),
    ),
    WorkbenchCommandItem(
      title: 'مدیریت سرورها و منابع',
      subtitle: 'مدیریت سیستم • زیرساخت',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.dns_outlined,
      color: const Color(0xff1e3a8a),
      keywords: const ['سرور', 'server'],
      onSelect: () => _pushPage(const ServerManagementPage()),
    ),
    WorkbenchCommandItem(
      title: 'اسکن شبکه و تجهیزات فعال',
      subtitle: 'مدیریت سیستم • شبکه',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.radar_rounded,
      color: const Color(0xff0284c7),
      keywords: const ['اسکن شبکه', 'آی‌پی', 'پینگ'],
      onSelect: () => _pushPage(const NetworkScanPage()),
    ),
    WorkbenchCommandItem(
      title: 'دوربین‌های مداربسته (CCTV)',
      subtitle: 'مدیریت سیستم • نظارت تصویری',
      group: 'صفحات و گزارش‌های پرکاربرد',
      icon: Icons.videocam_rounded,
      color: const Color(0xff0f766e),
      keywords: const ['دوربین', 'مداربسته', 'cctv', 'nvr'],
      onSelect: () => _pushPage(const CctvCamerasPage()),
    ),
    WorkbenchCommandItem(
      title: 'تغییر شرکت فعال',
      subtitle: _companies.active?.name ?? 'انتخاب شرکت سازمانی',
      group: 'تنظیمات میز کار',
      icon: Icons.apartment_rounded,
      color: HomeColors.seed,
      keywords: const ['شرکت', 'شعبه', 'تغییر شرکت'],
      onSelect: _openCompanies,
    ),
    WorkbenchCommandItem(
      title: 'سرورها و اتصال شبکه',
      subtitle: 'مدیریت پروفایل سرور و آدرس جایگزین',
      group: 'تنظیمات میز کار',
      icon: Icons.hub_outlined,
      color: const Color(0xff0f766e),
      keywords: const ['سرور', 'اتصال', 'شبکه', 'پروفایل'],
      onSelect: () => showConnectionsSheet(context),
    ),
  ];

  void _openCommandSearch(List<ModuleTile> modules) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WorkbenchCommandSheet(items: _buildCommandItems(modules)),
    );
  }

  void _openCustomize(List<ModuleTile> modules) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WorkbenchCustomizeSheet(
        initial: _prefs,
        modules: modules,
        onChanged: _updatePrefs,
      ),
    );
  }

  /// کلیک روی اعلان → پیدا کردن «همان رکورد» و باز کردن مستقیم آن.
  Future<void> _openFromNotification(NotificationItem n) async {
    if (!n.isRead) {
      try {
        await _repo.markRead(n.id);
      } catch (_) {}
      if (mounted) {
        setState(() {
          if (_unread > 0) _unread--;
        });
        _reloadNotificationsOnly();
      }
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
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
        case 'minutes':
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

    switch (target.kind) {
      case 'wo':
        widget.onOpenTab(1);
        return;
      case 'minutes':
        _pushPage(const MinutesListPage());
        return;
      default:
        widget.onOpenTab(2);
    }
  }

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
        onCleared: () async {
          await PushService.instance.cancelAll();
          final c = await _repo.fetchUnreadCount();
          if (mounted) setState(() => _unread = c);
          await _reloadNotificationsOnly();
        },
      ),
    );
    final n = await _repo.fetchUnreadCount();
    if (mounted) {
      setState(() => _unread = n);
      _reloadNotificationsOnly();
    }
  }

  Future<void> _openSettings(List<ModuleTile> modules) async {
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
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(
                  Icons.dashboard_customize_outlined,
                  color: HomeColors.seed,
                ),
                title: const Text(
                  'شخصی‌سازی میز کار',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'انتخاب بخش‌های فعال، چیدمان و سنجاق ماژول‌ها',
                  style: TextStyle(fontSize: 11.5),
                ),
                onTap: () => Navigator.pop(c, 'customize'),
              ),
              const Divider(height: 1),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(Icons.hub_outlined, color: HomeColors.seed),
                title: const Text(
                  'سرورها و اتصال شبکه',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    auth.connections.activeProfile?.displayName,
                    auth.connections.activeEndpoint?.displayLabel,
                  ].whereType<String>().join(' • '),
                  style: const TextStyle(fontSize: 11.5),
                ),
                onTap: () => Navigator.pop(c, 'connections'),
              ),
              const Divider(height: 1),
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
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(
                  'نسخهٔ ${toFaDigits(appVersion)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: HomeColors.inkFaint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'customize') {
      _openCustomize(modules);
      return;
    }
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
    if (action == 'connections' && mounted) await showConnectionsSheet(context);
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
                decoration: const InputDecoration(labelText: 'تکرار رمز جدید'),
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
    switch (m.onTapName) {
      case 'minutes':
        _pushPage(const MinutesListPage());
        return;
      case 'it-assets':
        _pushPage(const ItHomePage());
        return;
      case 'doc-archive':
        _pushPage(const DocArchivePage());
        return;
      case 'doc-archive-cartable':
        _pushPage(const DocArchiveCartablePage());
        return;
      case 'sales':
        _pushPage(const ShopHomePage());
        return;
      case 'moadian':
        _pushPage(const MoadianHomePage());
        return;
      case 'misc':
        _pushPage(const MiscFormsPage());
        return;
      default:
        HapticFeedback.selectionClick();
        _openModuleSheet(m);
    }
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
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: m.iconGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(m.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 11),
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
                'نسخهٔ وب این ماژول به‌طور کامل در دسترس است؛ نسخهٔ موبایل '
                'آن در فازهای بعدی تکمیل می‌شود. هم‌اکنون می‌توانید از '
                'ماژول‌های فعال (اتوماسیون اداری توکا، دستورکار رایکا، '
                'فروشگاهی کایر، مودیان تیسا، پیام رسان میها، مدیریت سیستم، '
                'صورتجلسه و آرشیو اسناد) در میز کار موبایل استفاده کنید.',
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
                  child: const Text('متوجه شدم'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// غنی‌سازی کاشی‌های ماژول با شمارنده‌های زندهٔ همان لحظه.
  List<ModuleTile> _enrichedModules() {
    final raw = buildModuleTiles(openTabs: const {1, 2, 3, 4});
    return [
      for (final m in raw)
        switch (m.id) {
          'letters' when _pulse.unreadLetters > 0 => m.copyWith(
            liveCount: _pulse.unreadLetters,
            liveLabel: '${Fa.digits(_pulse.unreadLetters)} نخوانده',
          ),
          'workorders' when _pulse.openWorkOrders > 0 => m.copyWith(
            liveCount: _pulse.openWorkOrders,
            liveLabel: _pulse.overdueWorkOrders > 0
                ? '${Fa.digits(_pulse.overdueWorkOrders)} معوق'
                : '${Fa.digits(_pulse.openWorkOrders)} باز',
          ),
          'chat' when _pulse.unreadChats > 0 => m.copyWith(
            liveCount: _pulse.unreadChats,
            liveLabel: '${Fa.digits(_pulse.unreadChats)} پیام',
          ),
          'it-assets' when _pulse.openItRequests > 0 => m.copyWith(
            liveCount: _pulse.openItRequests,
            liveLabel: '${Fa.digits(_pulse.openItRequests)} باز',
          ),
          'doc-cartable' when _pulse.pendingArchiveTasks > 0 => m.copyWith(
            liveCount: _pulse.pendingArchiveTasks,
            liveLabel: '${Fa.digits(_pulse.pendingArchiveTasks)} مورد',
          ),
          'moadian' when _moadianActionable > 0 => m.copyWith(
            liveCount: _moadianActionable,
            liveLabel: _moadianErrors > 0
                ? '${Fa.digits(_moadianErrors)} خطادار'
                : '${Fa.digits(_moadianActionable)} اقدام',
          ),
          _ => m,
        },
    ];
  }

  List<ModuleTile> _filteredAndSortedModules(List<ModuleTile> all) {
    final filtered = switch (_moduleFilter) {
      'pinned' => all.where((m) => _prefs.pinnedIds.contains(m.id)).toList(),
      'all' => List<ModuleTile>.from(all),
      _ => all.where((m) => m.category == _moduleFilter).toList(),
    };
    // ماژول‌های سنجاق‌شده همیشه در صدر فهرست قرار می‌گیرند (با حفظ ترتیب اصلی)
    final pinned = filtered
        .where((m) => _prefs.pinnedIds.contains(m.id))
        .toList();
    final rest = filtered
        .where((m) => !_prefs.pinnedIds.contains(m.id))
        .toList();
    return [...pinned, ...rest];
  }

  /// مرتب‌سازی کارت‌های KPI: کارت‌هایی که دادهٔ زنده دارند در اولویت اول قرار می‌گیرند.
  List<HomeKpi> get _orderedKpis {
    if (!_widgetsSettled) return _kpis;
    final withData = _kpis
        .where((k) => _widgetData[k.widgetKey]?.value != null)
        .toList();
    final withoutData = _kpis
        .where((k) => _widgetData[k.widgetKey]?.value == null)
        .toList();
    return [...withData, ...withoutData];
  }

  void _focusCartable() {
    HapticFeedback.selectionClick();
    setState(() => _cartableTab = 0);
    final ctx = _cartableKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.select<AuthController, ({String name, String role})>(
      (a) => (
        name: a.session?.displayName ?? '',
        role: a.session?.role == 'Admin'
            ? 'مدیر سیستم'
            : (a.session?.roleNames.isNotEmpty == true
                  ? a.session!.roleNames.first
                  : 'کاربر سازمانی'),
      ),
    );
    final allModules = _enrichedModules();
    final visibleModules = _filteredAndSortedModules(allModules);
    final orderedKpis = _orderedKpis;

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
            // ۱. سربرگ فرماندهی میز کار + شرکت فعال + نوار نبض سازمان
            _ExecutiveHeader(
              name: session.name,
              roleLabel: session.role,
              unread: _unread,
              companies: _companies,
              pulse: _pulse,
              loading: _loading,
              onSearch: () => _openCommandSearch(allModules),
              onCustomize: () => _openCustomize(allModules),
              onBell: _openNotifications,
              onSettings: () => _openSettings(allModules),
              onPickCompany: _openCompanies,
              onTapActionable: _focusCartable,
              onTapLetters: () => widget.onOpenTab(2),
              onTapWorkOrders: () => widget.onOpenTab(1),
              onTapChats: () => widget.onOpenTab(4),
            ),

            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _ErrorBanner(message: _error!, onRetry: _load),
                ),
              ),

            // ۲. نوار عملیات سریع یک‌ضربه‌ای
            if (_prefs.showQuickActions) ...[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'عملیات سریع میز کار',
                  subtitle: 'ثبت و صدور مستقیم با یک لمس',
                  trailing: TextButton.icon(
                    onPressed: () => _openCommandSearch(allModules),
                    icon: const Icon(Icons.bolt_rounded, size: 15),
                    label: const Text('همهٔ فرمان‌ها'),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: HomeColors.seed,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _QuickActionsRail(
                  onSaleInvoice: () =>
                      _pushPage(const OrderFormPage(type: TxnType.sale)),
                  onPurchaseInvoice: () =>
                      _pushPage(const OrderFormPage(type: TxnType.purchase)),
                  onProforma: () => _pushPage(
                    const OrderFormPage(type: TxnType.sale, isProforma: true),
                  ),
                  onNewLetter: () => _pushPage(
                    const LetterEditorPage(kind: LetterKind.inner),
                  ),
                  onNewWorkOrder: () => _pushPage(const WorkOrderEditorPage()),
                  onNewReceipt: () => _pushPage(
                    const TrsVoucherFormPage(kind: TrsKind.receipt),
                  ),
                  onNewMinutes: () => _pushPage(const MinutesEditorPage()),
                  onNewItRequest: () => _pushPage(const ItRequestFormPage()),
                  onMoadianInvoice: () =>
                      _pushPage(const MoadianInvoiceFormPage()),
                ),
              ),
            ],

            // ۳. کارتابل یکپارچه و میز اقدام (آینهٔ صفحهٔ اول وب Cartable.razor)
            if (_prefs.showCartable) ...[
              SliverToBoxAdapter(
                key: _cartableKey,
                child: _SectionHeader(
                  title: 'کارتابل یکپارچه و میز اقدام',
                  subtitle: 'امور منتظر اقدام و پیام‌های دسته‌بندی‌شده',
                  trailing: TextButton.icon(
                    onPressed: _openNotifications,
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('مرکز اعلان‌ها'),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: HomeColors.seed,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _WorkbenchCartableCard(
                    loading: _cartableLoading,
                    tabIndex: _cartableTab,
                    entries: _cartableEntries,
                    mainPage: _mainNtfs,
                    subPage: _subNtfs,
                    unreadOnly: _ntfUnreadOnly,
                    onTabChanged: (t) {
                      HapticFeedback.selectionClick();
                      setState(() => _cartableTab = t);
                    },
                    onToggleUnreadOnly: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _ntfUnreadOnly = v);
                      _reloadNotificationsOnly();
                    },
                    onTapEntry: (e) => _openTargetKey(e.targetKey),
                    onTapNotification: _openFromNotification,
                    onOpenAllNotifications: _openNotifications,
                  ),
                ),
              ),
            ],

            // ۴. شاخص‌های کلیدی عملکرد (KPI) با انتخابگر بازهٔ زمانی
            if (_prefs.showKpis) ...[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'شاخص‌های عملکرد سازمان',
                  subtitle: 'خلاصهٔ آماری زندهٔ ماژول‌ها',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RangePills(
                        selected: _kpiRange,
                        onSelect: _switchKpiRange,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'به‌روزرسانی شاخص‌ها',
                        onPressed: _kpiRefreshing ? null : _reloadWidgets,
                        icon: _kpiRefreshing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: HomeColors.seed,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildCarousel(orderedKpis)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: HDots(count: orderedKpis.length, index: _page),
                ),
              ),
            ],

            // ۵. ماژول‌های سازمان (هم‌نام با نسخهٔ وب + فیلتر + سنجاق + چیدمان ۲/۳ ستونی)
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'ماژول‌های سازمان',
                subtitle: 'سنجاق با لمس آیکون پین • هم‌تراز با نسخهٔ وب',
                trailing: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: _prefs.compactModules
                      ? 'نمایش تفصیلی (۲ ستونی)'
                      : 'نمایش فشرده (۳ ستونی)',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _updatePrefs(
                      _prefs.copyWith(compactModules: !_prefs.compactModules),
                    );
                  },
                  icon: Icon(
                    _prefs.compactModules
                        ? Icons.view_agenda_outlined
                        : Icons.grid_view_rounded,
                    size: 19,
                    color: HomeColors.seed,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _ModuleCategoryBar(
                selected: _moduleFilter,
                pinnedCount: _prefs.pinnedIds.length,
                onSelect: (cat) {
                  HapticFeedback.selectionClick();
                  setState(() => _moduleFilter = cat);
                },
              ),
            ),
            _buildModules(visibleModules),

            // فضای پایین برای نوار شیشه‌ای شناور
            const SliverToBoxAdapter(child: SizedBox(height: 108)),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel(List<HomeKpi> kpis) {
    if (_loading) {
      return SizedBox(
        height: 256,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) =>
              const HShimmer(width: 296, height: 248, radius: 24),
        ),
      );
    }
    final rangeLabel = switch (_kpiRange) {
      1 => 'هفته',
      2 => 'ماه',
      _ => 'امروز',
    };
    return SizedBox(
      height: 268,
      child: PageView.builder(
        controller: _pc,
        itemCount: kpis.length,
        padEnds: false,
        itemBuilder: (context, i) {
          final delta = _page - i;
          final abs = delta.abs();
          final scale = (1 - (abs * 0.08)).clamp(0.90, 1.0);
          final fade = (1 - (abs * 0.45)).clamp(0.55, 1.0);
          final kpi = kpis[i];
          return AnimatedBuilder(
            animation: _pc,
            child: _KpiCard(
              kpi: kpi,
              data: _widgetData[kpi.widgetKey],
              rangeLabel: rangeLabel,
              loading: _loading || !_widgetsSettled || _kpiRefreshing,
              onTap: kpi.targetKey.isEmpty
                  ? null
                  : () => _openTargetKey(kpi.targetKey),
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

  Widget _buildModules(List<ModuleTile> tiles) {
    final cols = _prefs.compactModules ? 3 : 2;
    final ratio = _prefs.compactModules ? 0.96 : 1.38;

    if (_loading) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 11,
            crossAxisSpacing: 11,
            childAspectRatio: ratio,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, _) => const HShimmer(width: 170, height: 120, radius: 20),
            childCount: 6,
          ),
        ),
      );
    }

    if (tiles.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: HomeColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: HomeColors.line),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.push_pin_outlined,
                  size: 30,
                  color: HomeColors.inkFaint,
                ),
                SizedBox(height: 8),
                Text(
                  'هنوز ماژولی در این دسته سنجاق نشده است',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 11,
          crossAxisSpacing: 11,
          childAspectRatio: ratio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final t = tiles[i];
            final pinned = _prefs.pinnedIds.contains(t.id);
            return HFadeSlideIn(
              index: i,
              delayMs: 35,
              offsetY: 16,
              child: _ModuleCard(
                tile: t,
                pinned: pinned,
                compact: _prefs.compactModules,
                onTap: () => _openModule(t),
                onTogglePin: () => _togglePin(t),
              ),
            );
          },
          childCount: tiles.length,
        ),
      ),
    );
  }
}

// ============================================================
//  ۱. سربرگ فرماندهی میز کار (Executive Cockpit Header)
// ============================================================

class _ExecutiveHeader extends StatelessWidget {
  const _ExecutiveHeader({
    required this.name,
    required this.roleLabel,
    required this.unread,
    required this.companies,
    required this.pulse,
    required this.loading,
    required this.onSearch,
    required this.onCustomize,
    required this.onBell,
    required this.onSettings,
    required this.onPickCompany,
    required this.onTapActionable,
    required this.onTapLetters,
    required this.onTapWorkOrders,
    required this.onTapChats,
  });

  final String name;
  final String roleLabel;
  final int unread;
  final CompanyContext companies;
  final WorkbenchPulse pulse;
  final bool loading;
  final VoidCallback onSearch;
  final VoidCallback onCustomize;
  final VoidCallback onBell;
  final VoidCallback onSettings;
  final VoidCallback onPickCompany;
  final VoidCallback onTapActionable;
  final VoidCallback onTapLetters;
  final VoidCallback onTapWorkOrders;
  final VoidCallback onTapChats;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'صبح بخیر';
    if (h >= 12 && h < 16) return 'ظهر بخیر';
    if (h >= 16 && h < 20) return 'عصر بخیر';
    return 'شب بخیر';
  }

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'ف';
    if (parts.length == 1) return parts.first.characters.first;
    return '${parts[0].characters.first}${parts[1].characters.first}';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final activeCompany = companies.active;

    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: HomeColors.hero,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Color(0x280c1938),
              blurRadius: 26,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: HHeaderGridPainter()),
              ),
              Positioned(
                left: -50,
                top: -40,
                child: _orb(170, const Color(0xff38bdf8), 0.14),
              ),
              Positioned(
                right: -40,
                top: 30,
                child: _orb(145, const Color(0xff818cf8), 0.16),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, top + 10, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ردیف بالا: نشان میز کار + دکمه‌های فرماندهی
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xff38bdf8),
                                      Color(0xff6366f1),
                                    ],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  _initials,
                                  style: const TextStyle(
                                    fontSize: 14,
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
                                        Flexible(
                                          child: Text(
                                            'میز کار یکپارچه فروغ آریا',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white.withValues(
                                                alpha: 0.72,
                                              ),
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
                                            color: const Color(
                                              0xff38bdf8,
                                            ).withValues(alpha: 0.20),
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xff7dd3fc,
                                              ).withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Text(
                                            roleLabel,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xffe0f2fe),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      name.isEmpty
                                          ? '$_greeting، خوش آمدید'
                                          : '$_greeting، $name',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _HeaderIconBtn(
                          icon: Icons.search_rounded,
                          tooltip: 'فرمان‌یار و جستجوی سریع',
                          onTap: onSearch,
                        ),
                        const SizedBox(width: 6),
                        _BellButton(unread: unread, onTap: onBell),
                        const SizedBox(width: 6),
                        _HeaderIconBtn(
                          icon: Icons.settings_rounded,
                          tooltip: 'تنظیمات و شخصی‌سازی',
                          onTap: onSettings,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ردیف دوم: ساعت زنده + نوار جستجوی فرمان‌یار سریع
                    Row(
                      children: [
                        const Flexible(child: HLiveClock()),
                        const SizedBox(width: 8),
                        HPressable(
                          onTap: onCustomize,
                          scale: 0.94,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 12.5,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'چیدمان میز کار',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ردیف سوم: کپسول شیشه‌ای شرکت فعال + جستجوی فوری
                    HPressable(
                      onTap: onPickCompany,
                      scale: 0.985,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: activeCompany == null
                                  ? const Icon(
                                      Icons.apartment_rounded,
                                      size: 17,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      activeCompany.initials,
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
                                  Text(
                                    'شرکت فعال سازمان',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    loading
                                        ? 'در حال بارگذاری شرکت…'
                                        : (activeCompany?.name ??
                                              'انتخاب شرکت فعال'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xff34d399,
                                ).withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                '${Fa.digits(companies.activeCount)} شرکت مجاز',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xffa7f3d0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.unfold_more_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 11),

                    // ردیف چهارم: نوار نبض زندهٔ میز کار (۴ شاخص عملیاتی قابل لمس)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PulseCell(
                              label: 'منتظر اقدام',
                              count: pulse.actionableCount,
                              accent: const Color(0xfffbbf24),
                              icon: Icons.bolt_rounded,
                              onTap: onTapActionable,
                            ),
                          ),
                          _vDivider(),
                          Expanded(
                            child: _PulseCell(
                              label: 'توکا (نخوانده)',
                              count: pulse.unreadLetters,
                              accent: const Color(0xff38bdf8),
                              icon: Icons.mark_email_unread_rounded,
                              onTap: onTapLetters,
                            ),
                          ),
                          _vDivider(),
                          Expanded(
                            child: _PulseCell(
                              label: 'رایکا (باز)',
                              count: pulse.openWorkOrders,
                              accent: pulse.overdueWorkOrders > 0
                                  ? const Color(0xfff87171)
                                  : const Color(0xfffb923c),
                              icon: Icons.assignment_late_rounded,
                              onTap: onTapWorkOrders,
                            ),
                          ),
                          _vDivider(),
                          Expanded(
                            child: _PulseCell(
                              label: 'میها (چت)',
                              count: pulse.unreadChats,
                              accent: const Color(0xff2dd4bf),
                              icon: Icons.forum_rounded,
                              onTap: onTapChats,
                            ),
                          ),
                        ],
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

  static Widget _vDivider() => Container(
    width: 1,
    height: 28,
    color: Colors.white.withValues(alpha: 0.12),
  );

  static Widget _orb(double size, Color color, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

class _PulseCell extends StatelessWidget {
  const _PulseCell({
    required this.label,
    required this.count,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: accent),
              const SizedBox(width: 4),
              Text(
                Fa.digits(count),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    ),
  );
}

class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HPressable(
    onTap: onTap,
    scale: 0.9,
    child: Tooltip(
      message: tooltip,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Icon(icon, size: 19, color: Colors.white),
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
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (unread > 0)
            Positioned(
              top: -3,
              left: -3,
              child: HPulseHalo(
                color: HomeColors.danger,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4.5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HomeColors.danger,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: HomeColors.deep, width: 1.8),
                  ),
                  child: Text(
                    Fa.digits(unread > 99 ? '99+' : unread),
                    style: const TextStyle(
                      fontSize: 9.5,
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
//  ۲. نوار عملیات سریع یک‌ضربه‌ای (Quick Actions Dock)
// ============================================================

class _QuickActionsRail extends StatelessWidget {
  const _QuickActionsRail({
    required this.onSaleInvoice,
    required this.onPurchaseInvoice,
    required this.onProforma,
    required this.onNewLetter,
    required this.onNewWorkOrder,
    required this.onNewReceipt,
    required this.onNewMinutes,
    required this.onNewItRequest,
    required this.onMoadianInvoice,
  });

  final VoidCallback onSaleInvoice;
  final VoidCallback onPurchaseInvoice;
  final VoidCallback onProforma;
  final VoidCallback onNewLetter;
  final VoidCallback onNewWorkOrder;
  final VoidCallback onNewReceipt;
  final VoidCallback onNewMinutes;
  final VoidCallback onNewItRequest;
  final VoidCallback onMoadianInvoice;

  @override
  Widget build(BuildContext context) {
    final actions =
        <({String title, String sub, IconData icon, Color color, VoidCallback onTap})>[
          (
            title: 'فاکتور فروش',
            sub: 'فروشگاهی کایر',
            icon: Icons.add_shopping_cart_rounded,
            color: const Color(0xff2563eb),
            onTap: onSaleInvoice,
          ),
          (
            title: 'صورتحساب مودیان',
            sub: 'مودیان تیسا',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xff0f766e),
            onTap: onMoadianInvoice,
          ),
          (
            title: 'فاکتور خرید',
            sub: 'فروشگاهی کایر',
            icon: Icons.shopping_bag_rounded,
            color: const Color(0xff0f766e),
            onTap: onPurchaseInvoice,
          ),
          (
            title: 'نامه جدید',
            sub: 'اتوماسیون توکا',
            icon: Icons.edit_document,
            color: const Color(0xff1e40af),
            onTap: onNewLetter,
          ),
          (
            title: 'دستور کار جدید',
            sub: 'دستورکار رایکا',
            icon: Icons.playlist_add_check_rounded,
            color: const Color(0xffd97706),
            onTap: onNewWorkOrder,
          ),
          (
            title: 'سند دریافت',
            sub: 'خزانه‌داری کایر',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xff059669),
            onTap: onNewReceipt,
          ),
          (
            title: 'پیش‌فاکتور',
            sub: 'فروشگاهی کایر',
            icon: Icons.request_quote_rounded,
            color: const Color(0xff4f46e5),
            onTap: onProforma,
          ),
          (
            title: 'صورتجلسه جدید',
            sub: 'مصوبات جلسات',
            icon: Icons.description_rounded,
            color: const Color(0xff0d9488),
            onTap: onNewMinutes,
          ),
          (
            title: 'درخواست IT',
            sub: 'مدیریت سیستم',
            icon: Icons.support_agent_rounded,
            color: const Color(0xff7c3aed),
            onTap: onNewItRequest,
          ),
        ];

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (_, i) {
          final a = actions[i];
          return HPressable(
            onTap: a.onTap,
            scale: 0.95,
            child: Container(
              width: 138,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: HomeColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: HomeColors.line),
                boxShadow: [
                  BoxShadow(
                    color: a.color.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          a.color,
                          Color.lerp(a.color, Colors.black, 0.2)!,
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(a.icon, size: 19, color: Colors.white),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: HomeColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: HomeColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
//  ۳. کارتابل یکپارچه و میز اقدام (آینهٔ Cartable.razor وب)
// ============================================================

class _WorkbenchCartableCard extends StatelessWidget {
  const _WorkbenchCartableCard({
    required this.loading,
    required this.tabIndex,
    required this.entries,
    required this.mainPage,
    required this.subPage,
    required this.unreadOnly,
    required this.onTabChanged,
    required this.onToggleUnreadOnly,
    required this.onTapEntry,
    required this.onTapNotification,
    required this.onOpenAllNotifications,
  });

  final bool loading;
  final int tabIndex;
  final List<CartableEntry> entries;
  final NotificationPageResult mainPage;
  final NotificationPageResult subPage;
  final bool unreadOnly;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<bool> onToggleUnreadOnly;
  final ValueChanged<CartableEntry> onTapEntry;
  final ValueChanged<NotificationItem> onTapNotification;
  final VoidCallback onOpenAllNotifications;

  @override
  Widget build(BuildContext context) {
    final actionableBadge = entries.where((e) => e.actionable).length;

    return Container(
      decoration: BoxDecoration(
        color: HomeColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeColors.line),
        boxShadow: [
          BoxShadow(
            color: HomeColors.seed.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // نوار تب‌های سهگانهٔ میز کار
          Container(
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: HomeColors.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CartableTabBtn(
                    label: 'منتظر اقدام',
                    icon: Icons.bolt_rounded,
                    selected: tabIndex == 0,
                    badge: actionableBadge,
                    urgentBadge: entries.any((e) => e.priority >= 3),
                    onTap: () => onTabChanged(0),
                  ),
                ),
                Expanded(
                  child: _CartableTabBtn(
                    label: 'اقدامات اصلی',
                    icon: Icons.flash_on_rounded,
                    selected: tabIndex == 1,
                    badge: mainPage.mainUnread > 0
                        ? mainPage.mainUnread
                        : mainPage.mainTotal,
                    urgentBadge: mainPage.mainUnread > 0,
                    onTap: () => onTabChanged(1),
                  ),
                ),
                Expanded(
                  child: _CartableTabBtn(
                    label: 'پیگیری‌ها',
                    icon: Icons.sync_rounded,
                    selected: tabIndex == 2,
                    badge: subPage.subUnread > 0
                        ? subPage.subUnread
                        : subPage.subTotal,
                    urgentBadge: false,
                    onTap: () => onTabChanged(2),
                  ),
                ),
              ],
            ),
          ),

          // نوار راهنمای تب برای اقدامات اصلی / پیگیری‌ها + فیلتر فقط نخوانده
          if (tabIndex > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tabIndex == 1
                          ? 'موارد تازه‌ای که منتظر نخستین اقدام شما هستند'
                          : 'پیگیری روی موارد موجود: تأیید، ارجاع، پاسخ و وضعیت',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: HomeColors.inkSoft,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onToggleUnreadOnly(!unreadOnly),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            unreadOnly
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 15,
                            color: unreadOnly
                                ? HomeColors.seed
                                : HomeColors.inkFaint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'فقط نخوانده',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: unreadOnly
                                  ? HomeColors.seed
                                  : HomeColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (loading)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: const [
                  HShimmer(width: double.infinity, height: 54, radius: 14),
                  SizedBox(height: 8),
                  HShimmer(width: double.infinity, height: 54, radius: 14),
                ],
              ),
            )
          else if (tabIndex == 0)
            _buildUnifiedEntries()
          else
            _buildNotificationRows(tabIndex == 1 ? mainPage : subPage),
        ],
      ),
    );
  }

  Widget _buildUnifiedEntries() {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeColors.ok.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: HomeColors.ok,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'همهٔ امور انجام شده است',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: HomeColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'در حال حاضر موردی در ماژول‌ها منتظر اقدام فوری شما نیست.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: HomeColors.inkSoft),
            ),
          ],
        ),
      );
    }

    final shown = entries.take(6).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _CartableEntryTile(
              entry: shown[i],
              onTap: () => onTapEntry(shown[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationRows(NotificationPageResult page) {
    if (page.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Icon(
              Icons.notifications_paused_outlined,
              size: 30,
              color: HomeColors.inkFaint.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 6),
            Text(
              unreadOnly
                  ? 'پیام خوانده‌نشده‌ای در این بخش وجود ندارد.'
                  : 'موردی برای نمایش در این بخش ثبت نشده است.',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: HomeColors.inkSoft,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        children: [
          for (var i = 0; i < page.items.length; i++) ...[
            if (i > 0) const SizedBox(height: 5),
            _CompactNotificationTile(
              item: page.items[i],
              onTap: () => onTapNotification(page.items[i]),
            ),
          ],
          if (page.filteredTotal > page.items.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton(
                onPressed: onOpenAllNotifications,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(34),
                  foregroundColor: HomeColors.seed,
                ),
                child: Text(
                  'مشاهدهٔ همهٔ ${Fa.digits(page.filteredTotal)} مورد در مرکز اعلان‌ها',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartableTabBtn extends StatelessWidget {
  const _CartableTabBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.badge,
    required this.urgentBadge,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final int badge;
  final bool urgentBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: selected ? HomeColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 13.5,
            color: selected ? HomeColors.seed : HomeColors.inkFaint,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? HomeColors.ink : HomeColors.inkSoft,
                ),
              ),
            ),
          ),
          if (badge > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1),
              decoration: BoxDecoration(
                color: urgentBadge
                    ? HomeColors.danger
                    : (selected
                          ? HomeColors.seed.withValues(alpha: 0.14)
                          : HomeColors.line),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                Fa.digits(badge > 99 ? '99+' : badge),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: urgentBadge
                      ? Colors.white
                      : (selected ? HomeColors.seed : HomeColors.inkSoft),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CartableEntryTile extends StatelessWidget {
  const _CartableEntryTile({required this.entry, required this.onTap});

  final CartableEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUrgent = entry.priority >= 3;
    return Material(
      color: isUrgent
          ? HomeColors.danger.withValues(alpha: 0.05)
          : HomeColors.surfaceSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUrgent
                  ? HomeColors.danger.withValues(alpha: 0.24)
                  : HomeColors.line.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(entry.icon, color: entry.color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (entry.moduleLabel.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: entry.color.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.moduleLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: entry.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (isUrgent)
                          const Text(
                            'فوری',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: HomeColors.danger,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: HomeColors.ink,
                      ),
                    ),
                    if (entry.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        entry.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: HomeColors.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if ((entry.badgeCount ?? 0) > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    Fa.digits(entry.badgeCount!),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: HomeColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactNotificationTile extends StatelessWidget {
  const _CompactNotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  ({IconData icon, Color color}) get _style {
    final f = (item.formName ?? item.title).toLowerCase();
    if (f.contains('نامه') || f.contains('توکا')) {
      return (
        icon: Icons.mark_email_unread_rounded,
        color: const Color(0xff0284c7),
      );
    }
    if (f.contains('دستور') || f.contains('رایکا')) {
      return (
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xff7c3aed),
      );
    }
    if (f.contains('سفارش') || f.contains('فروش') || f.contains('کایر')) {
      return (icon: Icons.storefront_rounded, color: const Color(0xff059669));
    }
    if (f.contains('صورتجلسه') || f.contains('جلسه')) {
      return (icon: Icons.description_rounded, color: const Color(0xff0d9488));
    }
    return (icon: Icons.notifications_active_rounded, color: HomeColors.seed);
  }

  @override
  Widget build(BuildContext context) {
    final st = _style;
    return Material(
      color: item.isRead
          ? HomeColors.surfaceSoft
          : const Color(0xffeff6ff),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: st.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(st.icon, size: 17, color: st.color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: item.isRead
                            ? FontWeight.w600
                            : FontWeight.w800,
                        color: HomeColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if ((item.formName ?? '').trim().isNotEmpty)
                          item.formName!.trim(),
                        if ((item.fromName ?? '').trim().isNotEmpty)
                          'از: ${item.fromName!.trim()}',
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: HomeColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: HomeColors.seed,
                  ),
                ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: HomeColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  ۴. شاخص‌های کلیدی عملکرد (KPI Cards + Range Pills)
// ============================================================

class _RangePills extends StatelessWidget {
  const _RangePills({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const labels = ['امروز', 'هفته', 'ماه'];
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: HomeColors.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: HomeColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: selected == i ? HomeColors.seed : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: selected == i ? Colors.white : HomeColors.inkSoft,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.kpi,
    required this.rangeLabel,
    this.data,
    this.loading = false,
    this.onTap,
  });

  final HomeKpi kpi;
  final String rangeLabel;
  final WidgetData? data;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = data?.value ?? kpi.value;
    final String? valueText = data?.value == null
        ? (loading ? '…' : '—')
        : (value == value.roundToDouble()
              ? null
              : Fa.number(value, decimals: 1));
    final delta = data == null
        ? kpi.deltaPercent
        : (data!.deltaUp == null ? null : (data!.deltaUp! ? 1.0 : -1.0));
    final deltaText = data?.deltaText;
    final spark = (data?.series.isNotEmpty ?? false) ? data!.series : kpi.spark;
    final rows = data?.rows ?? const <List<String>>[];

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12, top: 4, bottom: 4),
      child: HPressable(
        onTap: onTap,
        scale: 0.98,
        child: Container(
          decoration: BoxDecoration(
            color: HomeColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: HomeColors.line),
            boxShadow: [
              BoxShadow(
                color: kpi.from.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  left: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(gradient: kpi.gradient),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: kpi.gradient,
                              boxShadow: [
                                BoxShadow(
                                  color: kpi.from.withValues(alpha: 0.30),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              kpi.icon,
                              size: 18,
                              color: Colors.white,
                            ),
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
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: kpi.from.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  rangeLabel,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: kpi.to,
                                  ),
                                ),
                                if (onTap != null) ...[
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 13,
                                    color: kpi.to,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (valueText == null)
                            HCountUp(
                              value: value,
                              style: const TextStyle(
                                fontSize: 30,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.1,
                                color: HomeColors.ink,
                              ),
                            )
                          else
                            Text(
                              valueText,
                              style: TextStyle(
                                fontSize: data?.value == null ? 26 : 30,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: data?.value == null
                                    ? HomeColors.inkFaint
                                    : HomeColors.ink,
                              ),
                            ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                data?.unit ?? kpi.unit,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: HomeColors.inkSoft,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      _Delta(
                        delta: delta,
                        text: deltaText,
                        hasData: data != null,
                        loading: loading,
                      ),
                      const SizedBox(height: 2),
                      HSparkline(
                        values: spark.length >= 2
                            ? spark
                            : const [0.4, 0.9, 0.6, 1.3, 1.0, 1.7, 1.5],
                        color: kpi.from,
                        height: 36,
                        width: 250,
                      ),
                      const SizedBox(height: 6),
                      Container(height: 1, color: HomeColors.line),
                      const SizedBox(height: 9),
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
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({
    required this.delta,
    required this.hasData,
    required this.loading,
    this.text,
  });

  final double? delta;
  final String? text;
  final bool hasData;
  final bool loading;

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
                : Icons.check_circle_outline_rounded,
            size: 13.5,
            color: up > 0
                ? HomeColors.ok
                : up < 0
                ? HomeColors.danger
                : HomeColors.seed,
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
                    : HomeColors.inkSoft,
              ),
            ),
          ),
        ],
      );
    }
    return Text(
      loading
          ? 'در حال دریافت آمار زنده…'
          : (hasData ? 'به‌روزرسانی‌شده از سرور' : 'برای مشاهدهٔ جزئیات لمس کنید'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
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
    final items = live.isNotEmpty
        ? [
            for (final r in live.take(3))
              (
                r.isNotEmpty ? r[0] : '—',
                r.length > 1 ? r[1] : '—',
                r.length > 2 && r[2].isNotEmpty ? r[2] : null,
              ),
          ]
        : [
            for (final r in fallback.take(3)) (r.label, '—', r.hint),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    items[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: HomeColors.inkSoft,
                    ),
                  ),
                ),
                Text(
                  items[i].$2,
                  style: const TextStyle(
                    fontSize: 12,
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
//  ۵. ماژول‌های سازمان (فیلتر دسته + کارت سنجاق‌پذیر حرفه‌ای)
// ============================================================

class _ModuleCategoryBar extends StatelessWidget {
  const _ModuleCategoryBar({
    required this.selected,
    required this.pinnedCount,
    required this.onSelect,
  });

  final String selected;
  final int pinnedCount;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final cats = <({String id, String label, IconData icon})>[
      (id: 'all', label: 'همهٔ ماژول‌ها', icon: Icons.apps_rounded),
      (
        id: 'pinned',
        label: 'سنجاق‌شده (${Fa.digits(pinnedCount)})',
        icon: Icons.push_pin_rounded,
      ),
      (
        id: 'office',
        label: 'اداری و ارتباطات',
        icon: Icons.mark_email_read_outlined,
      ),
      (
        id: 'commerce',
        label: 'فروش و مالی',
        icon: Icons.storefront_outlined,
      ),
      (id: 'tech', label: 'فنی و زیرساخت', icon: Icons.dns_outlined),
      (id: 'hr', label: 'منابع انسانی', icon: Icons.groups_outlined),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final c = cats[i];
          final active = c.id == selected;
          return GestureDetector(
            onTap: () => onSelect(c.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? HomeColors.seed : HomeColors.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: active ? HomeColors.seed : HomeColors.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    c.icon,
                    size: 14,
                    color: active ? Colors.white : HomeColors.inkSoft,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    c.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : HomeColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.tile,
    required this.pinned,
    required this.compact,
    required this.onTap,
    required this.onTogglePin,
  });

  final ModuleTile tile;
  final bool pinned;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final hasLive = tile.liveCount > 0 && (tile.liveLabel ?? '').isNotEmpty;
    final badgeText = hasLive ? tile.liveLabel : tile.badge;

    if (compact) {
      return HPressable(
        onTap: onTap,
        onLongPress: onTogglePin,
        scale: 0.95,
        child: Opacity(
          opacity: tile.locked ? 0.55 : 1,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 9),
            decoration: BoxDecoration(
              color: HomeColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: pinned
                    ? tile.color.withValues(alpha: 0.38)
                    : HomeColors.line,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: tile.iconGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(tile.icon, size: 21, color: Colors.white),
                    ),
                    if (tile.liveCount > 0)
                      PositionedDirectional(
                        top: -5,
                        end: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: HomeColors.danger,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: Colors.white, width: 1.4),
                          ),
                          child: Text(
                            Fa.digits(tile.liveCount),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tile.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.8,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: HomeColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return HPressable(
      onTap: onTap,
      onLongPress: onTogglePin,
      scale: 0.96,
      child: Opacity(
        opacity: tile.locked ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            color: HomeColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: pinned
                  ? tile.color.withValues(alpha: 0.35)
                  : HomeColors.line,
              width: pinned ? 1.25 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: tile.color.withValues(alpha: pinned ? 0.09 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
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
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: tile.iconGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: tile.color.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(tile.icon, size: 21, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: (badgeText ?? '').isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: hasLive
                                    ? tile.color
                                    : tile.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                badgeText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.2,
                                  fontWeight: FontWeight.w800,
                                  color: hasLive ? Colors.white : tile.color,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTogglePin,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        pinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        size: 15,
                        color: pinned
                            ? tile.color
                            : HomeColors.inkFaint.withValues(alpha: 0.65),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: HomeColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tile.locked ? 'بدون مجوز دسترسی' : tile.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.2,
                        fontWeight: FontWeight.w600,
                        color: HomeColors.inkSoft,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 10.5,
                    color: tile.color.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  عنوان بخش و بنر خطا
// ============================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 12, 10),
    child: Row(
      children: [
        Container(
          width: 4,
          height: subtitle == null ? 18 : 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [HomeColors.seed, HomeColors.accent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: HomeColors.ink,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.inkFaint,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

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
