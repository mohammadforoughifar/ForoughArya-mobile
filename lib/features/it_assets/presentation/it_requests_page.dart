// ============================================================
//  درخواست خدمت IT — فاز ۹-ب
//  آینهٔ `Pages/ItAssets/ItRequests.razor` (مسیر وب: /it-requests)
//
//  • سرصفحه: «درخواست خدمات IT» / «ثبت درخواست پشتیبانی، تخصیص کارشناس و
//    پیگیری وضعیت انجام» + دکمهٔ «درخواست جدید» (با گیت CanCreate)
//  • تب‌ها با شمارنده، دقیقاً مثل وب:
//      «درخواست‌های من»  → تعداد همهٔ درخواست‌های من
//      «کارتابل کارشناس» → تعداد درخواست‌های با وضعیت Assigned (اگر IsExpert)
//      «کارتابل مدیر IT» → تعداد درخواست‌های با وضعیت New (اگر IsManager)
//      «شرکت‌های راه‌دور» → فقط مدیر
//  • فیلترهای کارتابل مدیر: «فقط درخواست‌های شرکت‌های راه‌دور»، انتخاب شرکت،
//    جستجو («جستجو: شماره، موضوع، نام…»)
//  • حالت خالی: «درخواستی وجود ندارد» + «ثبت اولین درخواست»
//  • صفحه‌بندی ۹ ردیفی با «قبلی/بعدی» و «N درخواست»
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/it_perms.dart';
import '../data/it_request_repository.dart';
import '../models/it_request_models.dart';
import 'it_request_detail_page.dart';
import 'it_request_form_page.dart';
import 'it_remote_companies_page.dart';

class ItRequestsPage extends StatefulWidget {
  const ItRequestsPage({super.key});

  @override
  State<ItRequestsPage> createState() => _ItRequestsPageState();
}

class _ItRequestsPageState extends State<ItRequestsPage> {
  late final ItRequestRepository _repo;
  late final ItPerms _perms;

  ItAccess _access = const ItAccess();
  List<ItClientCompany> _companies = const [];

  String _tab = 'mine';
  int _page = 1;
  int _total = 0;
  List<ItRequestItem> _items = const [];
  bool _loading = true;
  String? _error;

  // فیلترهای کارتابل مدیر
  bool _onlyExternal = false;
  int? _companyId;
  final _search = TextEditingController();

  // شمارندهٔ تب‌ها — از دادهٔ بارگذاری‌شده مثل وب
  int _mineCount = 0;
  int _expertAssigned = 0;
  int _managerNew = 0;

  int get _totalPages =>
      _total <= 0 ? 1 : ((_total - 1) ~/ ItRequestRepository.pageSize) + 1;

  @override
  void initState() {
    super.initState();
    _repo = ItRequestRepository(context.read<ApiClient>());
    _perms = ItPerms(context.read<AuthController>().session);
    _bootstrap();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _bootstrap() async {
    try {
      final access = await _repo.myAccess();
      if (!mounted) return;
      setState(() => _access = access);
      // مثل وب: مدیر شرکت‌های راه‌دور را برای فیلتر می‌گیرد
      if (access.isManager) {
        try {
          final c = await _repo.clientCompanies();
          if (mounted) setState(() => _companies = c);
        } catch (_) {}
      }
    } catch (_) {}
    await _load();
    await _loadCounters();
  }

  /// شمارندهٔ تب‌ها: «درخواست‌های من» از همان صفحه، دو کارتابل دیگر از
  /// درخواست‌های وضعیت‌دار (مثل وب که از لیست بارگذاری‌شده می‌شمارد).
  Future<void> _loadCounters() async {
    try {
      if (_access.isExpert) {
        final e = await _repo.expertInbox();
        if (mounted) {
          setState(() {
            _expertAssigned = e.items
                .where((r) => r.status == ItRequestStatus.assigned)
                .length;
          });
        }
      }
      if (_access.isManager) {
        final m = await _repo.managerInbox();
        if (mounted) {
          setState(() {
            _managerNew = m.items
                .where((r) => r.status == ItRequestStatus.created)
                .length;
          });
        }
      }
      if (_tab == 'mine') {
        if (mounted) setState(() => _mineCount = _total);
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final skip = (_page - 1) * ItRequestRepository.pageSize;
    try {
      Paged<ItRequestItem> res;
      switch (_tab) {
        case 'expert':
          res = await _repo.expertInbox(skip: skip);
        case 'manager':
          res = await _repo.managerInbox(
            skip: skip,
            onlyExternal: _onlyExternal,
            companyId: _companyId,
            search: _search.text,
          );
        default:
          res = await _repo.mine(skip: skip);
      }
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _total = res.total;
        if (_tab == 'mine') _mineCount = res.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  void _switchTab(String tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _page = 1;
      _items = const [];
    });
    _load();
  }

  void _goPage(int p) {
    final target = p.clamp(1, _totalPages);
    if (target == _page) return;
    setState(() => _page = target);
    _load();
  }

  Future<void> _openNew() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ItRequestFormPage()),
    );
    if (created == true) {
      setState(() => _page = 1);
      await _load();
      await _loadCounters();
    }
  }

  Future<void> _openDetail(ItRequestItem r, {bool requesterView = false}) async {
    // مثل وب: باز کردن جزئیات، «جدید» را رویت‌شده می‌کند
    if (!r.seen) {
      try {
        await _repo.markSeen(r.id);
      } catch (_) {}
    }
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ItRequestDetailPage(
          requestId: r.id,
          access: _access,
          requesterView: requesterView,
        ),
      ),
    );
    if (changed == true) {
      await _load();
      await _loadCounters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'درخواست خدمت IT',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'به‌روزرسانی',
          ),
        ],
      ),
      floatingActionButton: _access.canCreate
          ? FloatingActionButton.extended(
              backgroundColor: ShopColors.seed,
              onPressed: _openNew,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'درخواست جدید',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
          children: [
            const ShopHeader(
              title: 'درخواست خدمات IT',
              subtitle:
                  'ثبت درخواست پشتیبانی، تخصیص کارشناس و پیگیری وضعیت انجام',
              icon: Icons.headset_mic_rounded,
              badge: 'IT',
            ),
            const SizedBox(height: 10),
            _tabs(),
            if (_tab == 'manager' && _access.isManager) ...[
              const SizedBox(height: 8),
              _managerFilters(),
            ],
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ShopEmpty(
                title: 'درخواست‌ها بارگذاری نشد',
                subtitle: _error,
                icon: Icons.error_outline_rounded,
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    const ShopEmpty(
                      title: 'درخواستی وجود ندارد',
                      subtitle: 'در این کارتابل هنوز درخواستی ثبت نشده است.',
                      icon: Icons.inbox_rounded,
                    ),
                    if (_tab == 'mine' && _access.canCreate)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: FilledButton.icon(
                          onPressed: _openNew,
                          style: FilledButton.styleFrom(
                            backgroundColor: ShopColors.seed,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text(
                            'ثبت اولین درخواست',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else ...[
              ..._items.map(
                (r) => _card(r, requesterView: _tab == 'mine'),
              ),
              if (_totalPages > 1) _pager(),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '${Fa.number(_total)} درخواست',
                  style: const TextStyle(
                    fontSize: 10,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------ تب‌ها
  Widget _tabs() {
    final tabs = <({String key, String label, IconData icon, int badge})>[
      (
        key: 'mine',
        label: 'درخواست‌های من',
        icon: Icons.person_rounded,
        badge: _mineCount,
      ),
      if (_access.isExpert)
        (
          key: 'expert',
          label: 'کارتابل کارشناس',
          icon: Icons.build_rounded,
          badge: _expertAssigned,
        ),
      if (_access.isManager)
        (
          key: 'manager',
          label: 'کارتابل مدیر IT',
          icon: Icons.manage_accounts_rounded,
          badge: _managerNew,
        ),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in tabs)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _switchTab(t.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _tab == t.key ? ShopColors.seed : ShopColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _tab == t.key ? ShopColors.seed : ShopColors.line,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t.icon,
                      size: 14,
                      color: _tab == t.key ? Colors.white : ShopColors.inkSoft,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _tab == t.key ? Colors.white : ShopColors.inkSoft,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _tab == t.key
                            ? Colors.white.withValues(alpha: 0.25)
                            : ShopColors.bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        Fa.number(t.badge),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _tab == t.key
                              ? Colors.white
                              : ShopColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // شرکت‌های راه‌دور — فقط مدیر (مثل لینک وب)
        if (_access.isManager && _perms.canSeeRemoteCompanies)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ItRemoteCompaniesPage(),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ShopColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ShopColors.line),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hub_rounded,
                      size: 14,
                      color: ShopColors.inkSoft,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'شرکت‌های راه‌دور',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------ فیلترهای مدیر
  Widget _managerFilters() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Switch(
              value: _onlyExternal,
              activeThumbColor: ShopColors.seed,
              onChanged: (v) {
                setState(() {
                  _onlyExternal = v;
                  _page = 1;
                });
                _load();
              },
            ),
            const Expanded(
              child: Text(
                'فقط درخواست‌های شرکت‌های راه‌دور',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _companyId ?? 0,
                isExpanded: true,
                style: const TextStyle(
                  fontSize: 11,
                  color: ShopColors.ink,
                  fontFamily: 'Vazirmatn',
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(),
                  labelText: 'شرکت',
                  labelStyle: TextStyle(fontSize: 10),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 0,
                    child: Text('همهٔ شرکت‌ها', style: TextStyle(fontSize: 11)),
                  ),
                  for (final c in _companies)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.name} (${c.code})',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  setState(() {
                    _companyId = (v ?? 0) == 0 ? null : v;
                    _page = 1;
                  });
                  _load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _search,
          style: const TextStyle(fontSize: 11.5),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'جستجو: شماره، موضوع، نام…',
            hintStyle: TextStyle(fontSize: 10.5),
            prefixIcon: Icon(Icons.search_rounded, size: 16),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            setState(() => _page = 1);
            _load();
          },
        ),
      ],
    ),
  );

  // ------------------------------------------------ کارت درخواست
  Widget _card(ItRequestItem r, {required bool requesterView}) {
    final status = _statusColor(r.status, requesterView: requesterView);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(r, requesterView: requesterView),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 5, color: status.line),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 5,
                                runSpacing: 3,
                                children: [
                                  if (r.isNew)
                                    const ShopTag(
                                      text: '● جدید',
                                      color: ShopColors.danger,
                                    ),
                                  if (r.isExternal)
                                    ShopTag(
                                      text: r.companyName ?? 'شرکت راه‌دور',
                                      color: ShopColors.seed,
                                      icon: Icons.apartment_rounded,
                                    ),
                                  Text(
                                    r.title,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            ShopTag(text: status.label, color: status.color),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ShopColors.bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ShopColors.line,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Text(
                            r.number.isEmpty ? '—' : r.number,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: ShopColors.inkSoft,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ShopTag(
                              text: ItRequestType.label(r.requestType),
                              color: ShopColors.inkFaint,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person_outline_rounded,
                                  size: 12,
                                  color: ShopColors.inkFaint,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  r.requesterName,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: ShopColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                            if ((r.systemLabel ?? '').trim().isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.desktop_windows_rounded,
                                    size: 12,
                                    color: ShopColors.inkFaint,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    r.systemLabel!,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: ShopColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Divider(color: ShopColors.line, height: 1),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 11,
                              color: ShopColors.inkFaint,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              Fa.date(r.createdAt?.toIso8601String(),
                                  time: false),
                              style: const TextStyle(
                                fontSize: 9,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                            const Spacer(),
                            if (r.attachmentCount > 0) ...[
                              const Icon(
                                Icons.attach_file_rounded,
                                size: 11,
                                color: ShopColors.inkFaint,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                Fa.number(r.attachmentCount),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // مثل وب: مدیر می‌بیند چند کارشناس پاسخ داده‌اند
                            if (!requesterView && r.assignments.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.forum_outlined,
                                    size: 11,
                                    color: r.allReportsSubmitted
                                        ? ShopColors.ok
                                        : ShopColors.warn,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${Fa.number(r.reportsSubmitted)}/'
                                    '${Fa.number(r.assignments.length)} گزارش',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: r.allReportsSubmitted
                                          ? ShopColors.ok
                                          : ShopColors.warn,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
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

  ({Color color, Color line, String label}) _statusColor(
    String status, {
    required bool requesterView,
  }) => switch (status) {
    ItRequestStatus.created => (
      color: ShopColors.inkFaint,
      line: ShopColors.inkFaint,
      label: ItRequestStatus.label(status, requesterView: requesterView),
    ),
    ItRequestStatus.assigned => (
      color: ShopColors.warn,
      line: ShopColors.warn,
      label: ItRequestStatus.label(status, requesterView: requesterView),
    ),
    ItRequestStatus.managerApproved => (
      color: Color(0xff0284c7),
      line: Color(0xff0284c7),
      label: ItRequestStatus.label(status, requesterView: requesterView),
    ),
    ItRequestStatus.completed => (
      color: ShopColors.ok,
      line: ShopColors.ok,
      label: ItRequestStatus.label(status, requesterView: requesterView),
    ),
    ItRequestStatus.rejected => (
      color: ShopColors.danger,
      line: ShopColors.danger,
      label: ItRequestStatus.label(status, requesterView: requesterView),
    ),
    _ => (
      color: ShopColors.inkFaint,
      line: ShopColors.inkFaint,
      label: status,
    ),
  };

  Widget _pager() => Row(
    children: [
      OutlinedButton(
        onPressed: _page <= 1 ? null : () => _goPage(_page - 1),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: const Text('قبلی', style: TextStyle(fontSize: 10.5)),
      ),
      Expanded(
        child: Center(
          child: Text(
            'صفحهٔ ${Fa.number(_page)} از ${Fa.number(_totalPages)}',
            style: const TextStyle(fontSize: 10, color: ShopColors.inkSoft),
          ),
        ),
      ),
      OutlinedButton(
        onPressed: _page >= _totalPages ? null : () => _goPage(_page + 1),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: const Text('بعدی', style: TextStyle(fontSize: 10.5)),
      ),
    ],
  );
}
