import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/moadian_perms.dart';
import '../data/moadian_repository.dart';
import '../models/moadian_models.dart';
import 'moadian_basic_info_tab.dart';
import 'moadian_dashboard_tab.dart';
import 'moadian_guide_tab.dart';
import 'moadian_invoice_detail_page.dart';
import 'moadian_invoice_form_page.dart';
import 'moadian_invoices_tab.dart';
import 'moadian_style.dart';

/// پوستهٔ اصلی زیرسیستم «مودیان تیسا» (سامانه مودیان مالیاتی) با ۴ تب یکپارچه:
/// ۰: پیشخوان مودیان | ۱: صورتحساب‌ها | ۲: اطلاعات پایه و اتصال | ۳: راهنما و عیب‌یاب
class MoadianHomePage extends StatefulWidget {
  const MoadianHomePage({
    super.key,
    this.initialTab = 0,
    this.initialInvoiceFilter,
    this.initialBasicSection,
    this.openCreateOnStart = false,
  });

  final int initialTab;
  final String? initialInvoiceFilter;
  final int? initialBasicSection;
  final bool openCreateOnStart;

  @override
  State<MoadianHomePage> createState() => _MoadianHomePageState();
}

class _MoadianHomePageState extends State<MoadianHomePage> {
  late final MoadianRepository _repo = MoadianRepository(
    context.read<ApiClient>(),
  );

  late int _tab = widget.initialTab.clamp(0, 3);

  List<MoadianCpInfo> _companies = const [];
  int _activeCpInfoId = 0;

  // خلاصه برای پیشخوان
  MoadianConnection? _connection;
  int _fiscalYearCount = 0;
  int _goodsCount = 0;
  int _customersCount = 0;
  MoadianInvoiceLabels _labels = const MoadianInvoiceLabels();
  List<MoadianInvoice> _recentInvoices = const [];

  bool _loading = true;
  String? _error;

  // سیگنال‌های ناوبری بین تب‌ها
  String? _invoiceFilterCode;
  String? _invoiceSearchQuery;
  int _invoiceSignal = 0;
  int? _basicSectionIndex;
  int _basicSignal = 0;

  @override
  void initState() {
    super.initState();
    _invoiceFilterCode = widget.initialInvoiceFilter;
    _basicSectionIndex = widget.initialBasicSection;
    _loadShell().then((_) {
      if (widget.openCreateOnStart && mounted) {
        _openNewInvoice();
      }
    });
  }

  Future<void> _loadShell() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final companies = await _repo.getCpInfos();
      int resolved = _activeCpInfoId;
      if (resolved <= 0 || !companies.any((c) => c.cpInfoId == resolved)) {
        final saved = await _repo.loadSavedCpInfoId();
        if (saved != null && companies.any((c) => c.cpInfoId == saved)) {
          resolved = saved;
        } else if (companies.isNotEmpty) {
          resolved = companies.first.cpInfoId;
          await _repo.saveActiveCpInfoId(resolved);
        } else {
          resolved = 0;
        }
      }

      _companies = companies;
      _activeCpInfoId = resolved;

      if (resolved > 0) {
        await _loadProviderOverview(resolved);
      } else {
        _connection = null;
        _fiscalYearCount = 0;
        _goodsCount = 0;
        _customersCount = 0;
        _labels = const MoadianInvoiceLabels();
        _recentInvoices = const [];
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadProviderOverview(int cpInfoId) async {
    await Future.wait<void>([
      () async {
        try {
          _connection = await _repo.getConnection(cpInfoId);
        } catch (_) {
          _connection = null;
        }
      }(),
      () async {
        try {
          final fys = await _repo.getFiscalYears(cpInfoId);
          _fiscalYearCount = fys.length;
        } catch (_) {
          _fiscalYearCount = 0;
        }
      }(),
      () async {
        try {
          final g = await _repo.getGoods(cpInfoId: cpInfoId, pageSize: 1);
          _goodsCount = g.totalCount;
        } catch (_) {
          _goodsCount = 0;
        }
      }(),
      () async {
        try {
          final c = await _repo.getCustomers(cpInfoId);
          _customersCount = c.length;
        } catch (_) {
          _customersCount = 0;
        }
      }(),
      () async {
        try {
          final inv = await _repo.getInvoices(
            cpInfoId: cpInfoId,
            operation: 'همه',
            page: 1,
            pageSize: 5,
          );
          _labels = inv.labels;
          _recentInvoices = inv.invoices.items;
        } catch (_) {}
      }(),
    ]);
  }

  Future<void> _selectCompany(MoadianCpInfo c) async {
    if (c.cpInfoId == _activeCpInfoId) return;
    await _repo.saveActiveCpInfoId(c.cpInfoId);
    setState(() => _activeCpInfoId = c.cpInfoId);
    await _loadShell();
  }

  Future<void> _openNewInvoice() async {
    if (_activeCpInfoId <= 0 && _companies.isEmpty) {
      setState(() {
        _tab = 2;
        _basicSectionIndex = 0;
        _basicSignal++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ابتدا پروندهٔ شرکت مودیان و سال مالی را ثبت کنید.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final savedId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => MoadianInvoiceFormPage(
          mode: MoadianFormMode.create,
          initialCpInfoId: _activeCpInfoId,
        ),
      ),
    );
    if (savedId != null && mounted) {
      await _loadShell();
      if (savedId > 0 && mounted) {
        await Navigator.of(context).push<dynamic>(
          MaterialPageRoute(
            builder: (_) => MoadianInvoiceDetailPage(
              invoiceId: savedId,
              cpInfoId: _activeCpInfoId,
              onJumpToReferenceTax: (ref) {
                setState(() {
                  _tab = 1;
                  _invoiceFilterCode = 'همه';
                  _invoiceSearchQuery = ref;
                  _invoiceSignal++;
                });
              },
            ),
          ),
        );
        if (mounted) await _loadShell();
      }
    }
  }

  Future<void> _openDetail(MoadianInvoice inv) async {
    await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => MoadianInvoiceDetailPage(
          invoiceId: inv.effectiveId,
          cpInfoId: _activeCpInfoId,
          onJumpToReferenceTax: (ref) {
            setState(() {
              _tab = 1;
              _invoiceFilterCode = 'همه';
              _invoiceSearchQuery = ref;
              _invoiceSignal++;
            });
          },
        ),
      ),
    );
    if (mounted) await _loadShell();
  }

  String get _headerSubtitle => switch (_tab) {
    0 => 'پیشخوان پایش اتصال، وضعیت کارپوشه و عملیات سریع',
    1 => 'مدیریت، ارسال، استعلام، اصلاحیه و ابطال صورتحساب‌ها',
    2 => 'پرونده شرکت، کلید خصوصی RSA، کالاهای CPC و مشتریان',
    _ => 'نقشه راه عملیاتی، جدول وضعیت‌ها و دانشنامه خطایاب',
  };

  @override
  Widget build(BuildContext context) {
    final actionableCount =
        _labels.notSent + _labels.hasError + _labels.waitingInquiry;
    final session = Provider.of<AuthController?>(context)?.session;
    final canCreateInvoice =
        session == null ||
        MoadianPerms.can(session, MoadianPerms.invoiceCreate);

    return Scaffold(
      backgroundColor: MoadianColors.bg,
      body: Column(
        children: [
          MoadianPageHeader(
            title: 'مودیان تیسا (سامانه مودیان)',
            subtitle: _headerSubtitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canCreateInvoice)
                  IconButton(
                    tooltip: 'صدور صورتحساب جدید',
                    onPressed: _openNewInvoice,
                    icon: const Icon(
                      Icons.post_add_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                IconButton(
                  tooltip: 'نوسازی',
                  onPressed: _loading ? null : _loadShell,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: IndexedStack(
                index: _tab,
                children: [
                  MoadianDashboardTab(
                    companies: _companies,
                    activeCpInfoId: _activeCpInfoId,
                    connection: _connection,
                    fiscalYearCount: _fiscalYearCount,
                    goodsCount: _goodsCount,
                    customersCount: _customersCount,
                    labels: _labels,
                    recentInvoices: _recentInvoices,
                    loading: _loading,
                    error: _error,
                    onRefresh: _loadShell,
                    onSelectCompany: _selectCompany,
                    onNewInvoice: _openNewInvoice,
                    onOpenInvoicesWithFilter: (op) {
                      setState(() {
                        _tab = 1;
                        _invoiceFilterCode = op;
                        _invoiceSearchQuery = '';
                        _invoiceSignal++;
                      });
                    },
                    onOpenInvoiceDetail: _openDetail,
                    onOpenBasicSection: (sec) {
                      setState(() {
                        _tab = 2;
                        _basicSectionIndex = sec;
                        _basicSignal++;
                      });
                    },
                    onOpenGuide: () => setState(() => _tab = 3),
                  ),
                  MoadianInvoicesTab(
                    companies: _companies,
                    activeCpInfoId: _activeCpInfoId,
                    onSelectCompany: _selectCompany,
                    onChangedAny: _loadShell,
                    externalFilterCode: _invoiceFilterCode,
                    externalSearchQuery: _invoiceSearchQuery,
                    externalSignal: _invoiceSignal,
                  ),
                  MoadianBasicInfoTab(
                    companies: _companies,
                    activeCpInfoId: _activeCpInfoId,
                    onSelectCompany: _selectCompany,
                    onReloadShell: _loadShell,
                    externalSectionIndex: _basicSectionIndex,
                    externalSignal: _basicSignal,
                  ),
                  MoadianGuideTab(
                    activeCpInfoId: _activeCpInfoId,
                    onJumpToBasicSection: (sec) {
                      setState(() {
                        _tab = 2;
                        _basicSectionIndex = sec;
                        _basicSignal++;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: MoadianColors.surface,
        indicatorColor: MoadianColors.primary.withValues(alpha: 0.14),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(
              Icons.space_dashboard_rounded,
              color: MoadianColors.primary,
            ),
            label: 'پیشخوان',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: actionableCount > 0,
              label: Text(Fa.digits(actionableCount)),
              backgroundColor: _labels.hasError > 0
                  ? MoadianColors.danger
                  : MoadianColors.primary,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: actionableCount > 0,
              label: Text(Fa.digits(actionableCount)),
              backgroundColor: _labels.hasError > 0
                  ? MoadianColors.danger
                  : MoadianColors.primary,
              child: const Icon(
                Icons.receipt_long_rounded,
                color: MoadianColors.primary,
              ),
            ),
            label: 'صورتحساب‌ها',
          ),
          const NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(
              Icons.tune_rounded,
              color: MoadianColors.primary,
            ),
            label: 'اطلاعات پایه',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(
              Icons.menu_book_rounded,
              color: MoadianColors.primary,
            ),
            label: 'راهنما',
          ),
        ],
      ),
    );
  }
}
