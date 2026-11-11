// ============================================================
//  «جستجوی هوشمند آرشیو» — فاز ۹-ی (بخش ۳)
//  آینهٔ `Pages/DocArchive/DocSearch.razor` (مسیر وب: /doc-archive/search)
//
//  • جستجوی معنایی: `POST api/doc-archive/semantic-search`
//    (حالت «معنایی» / «کلیدواژه‌ای» از `semantic` پاسخ + `note`)
//  • جستجوی پیشرفته/تمام‌متن: `POST api/doc-archive/search-page`
//    با فیلتر نوع فایل، وضعیت، انقضا و جستجو در محتوا (`contentSearch`)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'doc_archive_detail_page.dart';
import 'doc_archive_page.dart' show colorFromHex;
import 'system_style.dart';

class DocSearchPage extends StatefulWidget {
  const DocSearchPage({super.key});

  @override
  State<DocSearchPage> createState() => _DocSearchPageState();
}

class _DocSearchPageState extends State<DocSearchPage> {
  late final DocArchiveRepository _repo;
  final _q = TextEditingController();

  bool _semanticMode = true;
  bool _includeContent = true;
  String _status = 'active';
  String _expiryStatus = 'all';
  final Set<String> _fileTypes = {};
  final Set<int> _tagIds = {};

  // ---- فاز ۹-ک: بازه‌های تاریخ، پیوست و افراد ----
  DateTime? _createdFrom;
  DateTime? _createdTo;
  DateTime? _expiryFrom;
  DateTime? _expiryTo;
  bool? _hasAttachment;
  int? _approverUserId;
  int? _createdByUserId;

  List<DocLookup> _users = const [];
  List<DocTag> _tags = const [];

  bool _loading = false;
  String? _error;

  DocSemanticResult? _semantic;
  DocPage<DocRow>? _page;

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final lookups = await _repo.lookups();
      final tags = await _repo.tags();
      if (!mounted) return;
      setState(() {
        _users = lookups.users;
        _tags = tags;
      });
    } catch (_) {}
  }

  DocSearchFilter _filter({int page = 1}) => DocSearchFilter(
    page: page,
    pageSize: 25,
    search: _q.text,
    contentSearch: _includeContent ? _q.text : null,
    status: _status,
    expiryStatus: _expiryStatus,
    fileTypes: _fileTypes.toList(),
    tagIds: _tagIds.toList(),
    createdFrom: _createdFrom,
    createdTo: _createdTo,
    expiryFrom: _expiryFrom,
    expiryTo: _expiryTo,
    hasAttachment: _hasAttachment,
    approverUserId: _approverUserId,
    createdByUserId: _createdByUserId,
  );

  void _clearFilters() => setState(() {
    _includeContent = true;
    _fileTypes.clear();
    _tagIds.clear();
    _createdFrom = null;
    _createdTo = null;
    _expiryFrom = null;
    _expiryTo = null;
    _hasAttachment = null;
    _approverUserId = null;
    _createdByUserId = null;
  });

  Widget _dateChip(
    String label,
    DateTime? value,
    void Function(DateTime?) onSet,
    Future<void> Function() onPick,
  ) => InkWell(
    onTap: onPick,
    borderRadius: BorderRadius.circular(20),
    child: Chip(
    avatar: Icon(
      value == null ? Icons.event_rounded : Icons.event_available_rounded,
      size: 13,
      color: value == null ? ShopColors.inkFaint : ShopColors.seed,
    ),
    label: Text(
      value == null ? label : '$label: ${jalaliShort(value)}',
      style: const TextStyle(fontSize: 9),
    ),
    visualDensity: VisualDensity.compact,
    onDeleted: value == null ? null : () => onSet(null),
    deleteIcon: const Icon(Icons.close_rounded, size: 12),
    ),
  );

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run({int page = 1}) async {
    final err = validateSemanticQuery(_q.text);
    // در حالت جستجوی پیشرفته، عبارت خالی هم مجاز است (فیلتر فقط)
    if (_semanticMode && err != null) {
      setState(() => _error = err);
      return;
    }
    if (!_semanticMode) {
      final dateErr = validateSearchDates(_filter());
      if (dateErr != null) {
        setState(() => _error = dateErr);
        return;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_semanticMode) {
        final res = await _repo.semanticSearch(
          DocSemanticRequest(query: _q.text.trim()),
        );
        if (!mounted) return;
        setState(() {
          _semantic = res;
          _page = null;
          _loading = false;
        });
      } else {
        final res = await _repo.searchPage(_filter(page: page));
        if (!mounted) return;
        setState(() {
          _page = res;
          _semantic = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '')
            .trim();
      });
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
          'جستجوی هوشمند آرشیو',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 26),
        children: [
          const ShopHeader(
            title: 'جستجوی هوشمند آرشیو',
            subtitle: 'جستجوی معنایی و تمام‌متن در اسناد و مدارک',
            icon: Icons.manage_search_rounded,
            badge: 'AI',
          ),
          const SizedBox(height: 10),
          ShopSegmented(
            labels: const ['جستجوی معنایی', 'جستجوی پیشرفته'],
            index: _semanticMode ? 0 : 1,
            onChanged: (i) => setState(() => _semanticMode = i == 0),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _q,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _run(),
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: _semanticMode
                        ? 'مثلاً: قرارداد نگهداری تجهیزات سال گذشته'
                        : 'جستجو در عنوان و محتوای مدارک…',
                    hintStyle: const TextStyle(
                      fontSize: 9.5,
                      color: ShopColors.inkFaint,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: const Color(0xfff9fbfe),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: ShopColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: ShopColors.line),
                    ),
                  ),
                ),
                if (!_semanticMode) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'نوع فایل',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final t in kDocFileTypes)
                        ChoiceChip(
                          label: Text(
                            t.value,
                            style: const TextStyle(fontSize: 9),
                          ),
                          visualDensity: VisualDensity.compact,
                          selected: _fileTypes.contains(t.key),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _fileTypes.add(t.key);
                            } else {
                              _fileTypes.remove(t.key);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _includeContent,
                    onChanged: (v) => setState(() => _includeContent = v),
                    title: const Text(
                      'جستجو در محتوای فایل‌ها و OCR',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isDense: true,
                          initialValue: _status,
                          style: const TextStyle(
                            fontSize: 10,
                            color: ShopColors.ink,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'وضعیت',
                            labelStyle: TextStyle(fontSize: 9),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('فعال'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('غیرفعال'),
                            ),
                            DropdownMenuItem(
                              value: 'trash',
                              child: Text('سطل بازیافت'),
                            ),
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('همه'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _status = v ?? _status),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isDense: true,
                          initialValue: _expiryStatus,
                          style: const TextStyle(
                            fontSize: 10,
                            color: ShopColors.ink,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'وضعیت انقضا',
                            labelStyle: TextStyle(fontSize: 9),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('همه'),
                            ),
                            DropdownMenuItem(
                              value: 'expired',
                              child: Text('منقضی شده'),
                            ),
                            DropdownMenuItem(
                              value: 'expiring',
                              child: Text('نزدیک انقضا'),
                            ),
                            DropdownMenuItem(
                              value: 'valid',
                              child: Text('معتبر'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _expiryStatus = v ?? _expiryStatus),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'فیلترهای پیشرفته',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                    ),
                    if (_filter().activeCount > 0)
                      ShopTag(
                        text: '${Fa.digits(_filter().activeCount)} فیلتر فعال',
                        color: ShopColors.seed,
                      ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 26),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        foregroundColor: ShopColors.inkFaint,
                      ),
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 13),
                      label: const Text(
                        'پاک کردن',
                        style: TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    _dateChip(
                      'ثبت از',
                      _createdFrom,
                      (d) => setState(() => _createdFrom = d),
                      () => _pickDate(true, true),
                    ),
                    _dateChip(
                      'ثبت تا',
                      _createdTo,
                      (d) => setState(() => _createdTo = d),
                      () => _pickDate(true, false),
                    ),
                    _dateChip(
                      'انقضا از',
                      _expiryFrom,
                      (d) => setState(() => _expiryFrom = d),
                      () => _pickDate(false, true),
                    ),
                    _dateChip(
                      'انقضا تا',
                      _expiryTo,
                      (d) => setState(() => _expiryTo = d),
                      () => _pickDate(false, false),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'پیوست:',
                      style: TextStyle(fontSize: 9.5, color: ShopColors.inkSoft),
                    ),
                    ChoiceChip(
                      label: const Text('همه', style: TextStyle(fontSize: 9)),
                      visualDensity: VisualDensity.compact,
                      selected: _hasAttachment == null,
                      onSelected: (_) => setState(() => _hasAttachment = null),
                    ),
                    ChoiceChip(
                      label: const Text(
                        'دارای پیوست',
                        style: TextStyle(fontSize: 9),
                      ),
                      visualDensity: VisualDensity.compact,
                      selected: _hasAttachment == true,
                      onSelected: (_) => setState(() => _hasAttachment = true),
                    ),
                    ChoiceChip(
                      label: const Text(
                        'بدون پیوست',
                        style: TextStyle(fontSize: 9),
                      ),
                      visualDensity: VisualDensity.compact,
                      selected: _hasAttachment == false,
                      onSelected: (_) => setState(() => _hasAttachment = false),
                    ),
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final t in _tags)
                        FilterChip(
                          label: Text(
                            t.name,
                            style: const TextStyle(fontSize: 9),
                          ),
                          visualDensity: VisualDensity.compact,
                          selected: _tagIds.contains(t.id),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _tagIds.add(t.id);
                            } else {
                              _tagIds.remove(t.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _userDrop(true)),
                    const SizedBox(width: 8),
                    Expanded(child: _userDrop(false)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : () => _run(),
                    icon: _loading
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search_rounded, size: 16),
                    label: Text(
                      _semanticMode ? 'جستجوی معنایی' : 'جستجو',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_error != null) ...[
            SystemNote(
              text: _error!,
              color: ShopColors.danger,
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 8),
          ],
          if (_semantic != null) ..._semanticResult(_semantic!),
          if (_page != null) ..._pageResult(_page!),
        ],
      ),
    );
  }

  List<Widget> _semanticResult(DocSemanticResult r) => [
    Row(
      children: [
        ShopTag(
          text: r.modeLabel,
          color: r.semantic ? ShopColors.accent : ShopColors.inkFaint,
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(width: 6),
        ShopTag(
          text: '${Fa.digits(r.hits.length)} نتیجه',
          color: ShopColors.seed,
        ),
        const SizedBox(width: 6),
        ShopTag(
          text: '${Fa.digits(r.totalCandidates)} کاندید',
          color: ShopColors.inkFaint,
        ),
      ],
    ),
    if ((r.note ?? '').isNotEmpty) ...[
      const SizedBox(height: 6),
      SystemNote(
        text: r.note!,
        color: ShopColors.warn,
        icon: Icons.info_outline_rounded,
      ),
    ],
    const SizedBox(height: 8),
    if (r.hits.isEmpty)
      const SystemNote(
        text: 'نتیجه‌ای یافت نشد.',
        color: ShopColors.inkFaint,
        icon: Icons.search_off_rounded,
      )
    else
      for (final h in r.hits)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: ShopColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ShopColors.line),
          ),
          child: ListTile(
            dense: true,
            title: Text(
              h.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${h.code} · ${h.folderName}',
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
                if (h.snippet.isNotEmpty)
                  Text(
                    h.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      height: 1.7,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: [
                    ShopTag(
                      text: 'تطابق ${Fa.digits((h.score * 100).round())}٪',
                      color: ShopColors.accent,
                    ),
                    ShopTag(
                      text: DocLevel.name(h.myLevel),
                      color: ShopColors.inkFaint,
                    ),
                    for (final t in h.tags)
                      ShopTag(
                        text: t.name,
                        color: colorFromHex(t.color),
                      ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_left_rounded, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DocArchiveDetailPage(id: h.documentId),
              ),
            ),
          ),
        ),
  ];

  List<Widget> _pageResult(DocPage<DocRow> p) => [
    Row(
      children: [
        ShopTag(
          text: '${Fa.digits(p.total)} نتیجه',
          color: ShopColors.seed,
        ),
        const SizedBox(width: 6),
        Text(
          'صفحه ${Fa.digits(p.page)} از ${Fa.digits((p.total / p.pageSize).ceil().clamp(1, 9999))}',
          style: const TextStyle(fontSize: 9, color: ShopColors.inkFaint),
        ),
      ],
    ),
    const SizedBox(height: 8),
    if (p.items.isEmpty)
      const SystemNote(
        text: 'مدرکی یافت نشد.',
        color: ShopColors.inkFaint,
        icon: Icons.search_off_rounded,
      )
    else
      for (final d in p.items)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: ShopColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ShopColors.line),
          ),
          child: ListTile(
            dense: true,
            title: Text(
              d.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              '${d.code} · ${d.folderCell}',
              style: const TextStyle(
                fontSize: 8.5,
                color: ShopColors.inkFaint,
              ),
            ),
            trailing: const Icon(Icons.chevron_left_rounded, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DocArchiveDetailPage(id: d.id),
              ),
            ),
          ),
        ),
    if (p.total > p.pageSize)
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: p.page <= 1 ? null : () => _run(page: p.page - 1),
              child: const Text('قبلی', style: TextStyle(fontSize: 10.5)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: p.hasNext ? () => _run(page: p.page + 1) : null,
              child: const Text('بعدی', style: TextStyle(fontSize: 10.5)),
            ),
          ),
        ],
      ),
  ];

  Widget _userDrop(bool isApprover) => DropdownButtonFormField<int?>(
    isDense: true,
    initialValue: isApprover ? _approverUserId : _createdByUserId,
    style: const TextStyle(fontSize: 10, color: ShopColors.ink),
    decoration: InputDecoration(
      isDense: true,
      labelText: isApprover ? 'گردش‌دهنده' : 'ثبت‌کننده',
      labelStyle: const TextStyle(fontSize: 9),
      border: const OutlineInputBorder(),
    ),
    items: [
      const DropdownMenuItem<int?>(value: null, child: Text('همه')),
      for (final u in _users)
        DropdownMenuItem<int?>(
          value: u.id,
          child: Text(u.name, style: const TextStyle(fontSize: 10)),
        ),
    ],
    onChanged: (v) => setState(() {
      if (isApprover) {
        _approverUserId = v;
      } else {
        _createdByUserId = v;
      }
    }),
  );

  Future<void> _pickDate(bool isCreated, bool isFrom) async {
    final current = isCreated
        ? (isFrom ? _createdFrom : _createdTo)
        : (isFrom ? _expiryFrom : _expiryTo);
    final picked = await showJalaliDatePicker(
      context,
      initial: current,
      title: isCreated ? 'تاریخ ثبت' : 'تاریخ انقضا',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isCreated) {
        if (isFrom) {
          _createdFrom = picked;
        } else {
          _createdTo = picked;
        }
      } else {
        if (isFrom) {
          _expiryFrom = picked;
        } else {
          _expiryTo = picked;
        }
      }
    });
  }
}