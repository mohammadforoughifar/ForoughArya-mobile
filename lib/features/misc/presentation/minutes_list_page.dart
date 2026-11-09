// ============================================================
//  صفحهٔ فهرست صورتجلسه‌ها — زیرمجموعهٔ ماژول «فرم‌های متفرقه»
//  مسیر سرور: GET /api/meeting-minutes  (هدر X-Company-Id)
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../../home/models/home_models.dart';
import '../../home/presentation/company_picker_sheet.dart';
import '../data/minutes_repository.dart';
import '../models/minutes_models.dart';
import 'minutes_detail_page.dart';
import 'minutes_editor_page.dart';
import 'misc_style.dart';

class MinutesListPage extends StatefulWidget {
  const MinutesListPage({super.key});

  @override
  State<MinutesListPage> createState() => _MinutesListPageState();
}

class _MinutesListPageState extends State<MinutesListPage> {
  late final MinutesRepository _repo =
      Provider.of<MinutesRepository?>(context, listen: false) ??
      MinutesRepository(context.read<ApiClient>());

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  CompanyContext _companies = CompanyContext.empty;
  List<MinutesListItem> _items = const [];
  int _total = 0;
  String _status = ''; // '' | 'InReview' | 'Closed'
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = await _repo.fetchCompanies();
      if (!mounted) return;
      _companies = CompanyContext(
        companies: ctx.companies,
        activeCompanyId: _repo.api.companyId ?? ctx.activeCompanyId,
      );
      final res = await _repo.fetchList(
        search: _searchCtrl.text,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _total = res.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _reloadList() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.fetchList(
        search: _searchCtrl.text,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _total = res.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reloadList);
  }

  Future<void> _openCompanyPicker() async {
    if (_companies.companies.isEmpty) {
      try {
        final ctx = await _repo.fetchCompanies();
        if (!mounted) return;
        setState(() => _companies = ctx);
      } catch (_) {}
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompanyPickerSheet(
        context_: _companies,
        activeId: _repo.api.companyId ?? _companies.activeCompanyId,
        onPick: (c) async {
          await _repo.selectCompany(c.id);
          if (!mounted) return;
          setState(() {
            _companies = CompanyContext(
              companies: _companies.companies,
              activeCompanyId: c.id,
            );
          });
          await _reloadList();
        },
      ),
    );
  }

  Future<void> _openCreate() async {
    final newId = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const MinutesEditorPage()),
    );
    if (newId == null || !mounted) return;
    await _reloadList();
    if (!mounted || newId <= 0) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MinutesDetailPage(minutesId: newId)),
    );
    if (mounted) await _reloadList();
  }

  Future<void> _openDetail(MinutesListItem m) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MinutesDetailPage(minutesId: m.id)),
    );
    if (changed == true && mounted) {
      await _reloadList();
    }
  }

  String get _activeCompanyLabel {
    final cid = _repo.api.companyId ?? _companies.activeCompanyId;
    for (final c in _companies.companies) {
      if (c.id == cid) return c.name;
    }
    return cid != null && cid > 0 ? 'شرکت #${Fa.digits(cid)}' : 'انتخاب شرکت';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: MiscColors.bg,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'minutes_new_fab',
          onPressed: _openCreate,
          backgroundColor: MiscColors.teal,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'ثبت صورتجلسه',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: MiscColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'صورتجلسه‌ها',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                Fa.digits(_total),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'فرم‌های متفرقه • مصوبات و امضای جلسات',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _openCompanyPicker,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 145),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.business_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _activeCompanyLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.expand_more_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 13, color: MiscColors.ink),
                decoration: InputDecoration(
                  hintText: 'جست‌وجو در عنوان یا ثبت‌کننده…',
                  hintStyle: const TextStyle(
                    fontSize: 12.5,
                    color: MiscColors.inkFaint,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: MiscColors.inkFaint,
                  ),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 17),
                          onPressed: () {
                            _searchCtrl.clear();
                            _reloadList();
                          },
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipBtn(
                      label: 'همهٔ وضعیت‌ها',
                      selected: _status.isEmpty,
                      onTap: () {
                        setState(() => _status = '');
                        _reloadList();
                      },
                    ),
                    const SizedBox(width: 7),
                    _FilterChipBtn(
                      label: 'در حال بررسی',
                      selected: _status == 'InReview',
                      onTap: () {
                        setState(() => _status = 'InReview');
                        _reloadList();
                      },
                    ),
                    const SizedBox(width: 7),
                    _FilterChipBtn(
                      label: 'اتمام نهایی',
                      selected: _status == 'Closed',
                      onTap: () {
                        setState(() => _status = 'Closed');
                        _reloadList();
                      },
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

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(label: 'در حال دریافت صورتجلسه‌ها…');
    }
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          child: MinutesAccessDiagnosticCard(
            error: _error!,
            onRetry: _initAndLoad,
            onPickCompany: _openCompanyPicker,
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reloadList,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: MiscColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: MiscColors.line),
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: MiscColors.teal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      size: 30,
                      color: MiscColors.teal,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'صورتجلسه‌ای در گردش شما یافت نشد',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: MiscColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'در شرکت انتخابی، فقط صورتجلسه‌هایی نمایش داده می‌شوند که شما ایجادکنندهٔ آن باشید، یا پس از «ارسال به گردش» جزو حاضرین/غایبینِ مطلع‌شده یا مسئول اجرا/پیگیری یکی از بندها باشید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.85,
                      color: MiscColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _openCreate,
                        style: FilledButton.styleFrom(
                          backgroundColor: MiscColors.teal,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('ثبت صورتجلسه جدید'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openCompanyPicker,
                        icon: const Icon(Icons.business_rounded, size: 17),
                        label: const Text('تغییر شرکت فعال'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reloadList,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _MinutesCard(
          item: _items[i],
          onTap: () => _openDetail(_items[i]),
        ),
      ),
    );
  }
}

class _FilterChipBtn extends StatelessWidget {
  const _FilterChipBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: selected ? MiscColors.teal : Colors.white,
        ),
      ),
    ),
  );
}

class _MinutesCard extends StatelessWidget {
  const _MinutesCard({required this.item, required this.onTap});

  final MinutesListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = MiscColors.forMinutesStatus(item.status);
    return Material(
      color: MiscColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MiscColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: MiscColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${Fa.digits(item.id)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: MiscColors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MinutesStatusBadge(status: item.status),
                  const Spacer(),
                  Text(
                    formatJalaliDate(item.meetingDate),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: MiscColors.inkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: MiscColors.ink,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              if (item.itemCount > 0) ...[
                Row(
                  children: [
                    Text(
                      'پیشرفت بندها: ${Fa.digits(item.itemDoneCount)} از ${Fa.digits(item.itemCount)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: MiscColors.inkSoft,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${Fa.digits((item.progress * 100).round())}٪',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 5.5,
                    backgroundColor: MiscColors.line,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 14.5,
                    color: MiscColors.inkFaint,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.createdByName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: MiscColors.inkSoft,
                      ),
                    ),
                  ),
                  _StatChip(
                    icon: Icons.people_outline_rounded,
                    text: Fa.digits(item.attendeeCount),
                    color: MiscColors.ok,
                  ),
                  if (item.absentCount > 0) ...[
                    const SizedBox(width: 6),
                    _StatChip(
                      icon: Icons.person_off_outlined,
                      text: Fa.digits(item.absentCount),
                      color: MiscColors.danger,
                    ),
                  ],
                  if (item.attachmentCount > 0) ...[
                    const SizedBox(width: 6),
                    _StatChip(
                      icon: Icons.attach_file_rounded,
                      text: Fa.digits(item.attachmentCount),
                      color: MiscColors.seed,
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

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}
