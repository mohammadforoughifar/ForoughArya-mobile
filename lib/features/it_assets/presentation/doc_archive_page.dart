// ============================================================
//  «آرشیو اسناد و مدارک» — فاز ۹-ح (بخش ۱)
//  آینهٔ `Pages/DocArchive/DocArchiveExplorer.razor` (مسیر وب: /doc-archive)
//
//  ساختار وب → موبایل:
//   • سرصفحهٔ «آرشیو اسناد و مدارک» / «مدارک غیرفعال» / «سطل بازیافت»
//     + دکمهٔ «مدرک جدید» (F2) + «پوشه جدید» (گیت DocArchive.Create)
//   • سه تب: «همه مدارک» / «ستاره‌دارها» / «اخیراً دیده‌شده»
//   • جستجو «جستجوی اسناد…» با دکمهٔ پاک‌کردن
//   • درخت پوشه‌ها با شمارندهٔ هر پوشه + میان‌برهای «منقضی شده»،
//     «رو به انقضا»، «مدارک غیرفعال»، «سطل بازیافت» (با شمارنده)
//   • فیلترهای پیشرفته: وضعیت انقضا، شامل زیرپوشه‌ها، برچسب‌ها، نوع فایل
//   • کارت هر مدرک: کد، نشان سطح دسترسی، عنوان، پوشه، نسخه‌ها،
//     وضعیت آخرین نسخه، برچسب‌ها، سرنخ انقضا و ستاره‌دار کردن
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'doc_archive_cartable_page.dart';
import 'doc_archive_detail_page.dart';
import 'doc_archive_form_page.dart';
import 'system_style.dart';

enum DocTab { all, fav, recent }

enum DocStatusFilter { active, inactive, deleted }

class DocArchivePage extends StatefulWidget {
  const DocArchivePage({super.key});

  @override
  State<DocArchivePage> createState() => _DocArchivePageState();
}

class _DocArchivePageState extends State<DocArchivePage> {
  late final DocArchiveRepository _repo;

  DocTab _tab = DocTab.all;
  DocStatusFilter _status = DocStatusFilter.active;
  int? _folderId;
  String? _expiryFilter; // expiring | expired
  bool _includeSubfolders = true;

  final _search = TextEditingController();
  Timer? _searchDelay;

  bool _loading = true;
  String? _error;

  List<DocRow> _docs = const [];
  int _total = 0;
  int _skip = 0;
  static const _pageSize = 30;

  List<DocFolder> _folders = const [];
  List<DocTag> _tags = const [];
  List<DocFavorite> _favorites = const [];
  List<DocRecent> _recent = const [];
  DocArchiveStats _stats = const DocArchiveStats();

  final Set<int> _selectedTagIds = {};

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    _bootstrap();
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.folders(take: 500),
        _repo.stats(),
        _repo.tags(),
      ]);
      if (!mounted) return;
      setState(() {
        _folders = (results[0] as DocPage<DocFolder>).items;
        _stats = results[1] as DocArchiveStats;
        _tags = results[2] as List<DocTag>;
        _error = null;
      });
      await _loadDocs();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'ارتباط با سرور برقرار نشد — ${_clean(e)}';
      });
    }
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  String get _statusParam => switch (_status) {
    DocStatusFilter.active => 'active',
    DocStatusFilter.inactive => 'inactive',
    DocStatusFilter.deleted => 'all',
  };

  Future<void> _loadDocs({bool reset = true}) async {
    if (reset) _skip = 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repo.documents(
        folderId: _folderId,
        search: _search.text,
        status: _statusParam,
        expiry: _expiryFilter,
        skip: _skip,
        take: _pageSize,
      );
      if (!mounted) return;
      var items = page.items;
      // سطل بازیافت و غیرفعال‌ها با فیلتر وضعیت سرور جدا می‌شوند؛
      // برای «همه» فقط فعال‌ها می‌آیند، پس فیلتر محلی لازم نیست جز حالت deleted.
      if (_status == DocStatusFilter.deleted) {
        items = items.where((d) => d.isDeleted).toList();
      } else if (_status == DocStatusFilter.inactive) {
        items = items.where((d) => !d.isDeleted && !d.isActive).toList();
      }
      setState(() {
        _docs = items;
        _total = page.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'بارگذاری مدارک ناموفق بود — ${_clean(e)}';
      });
    }
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    try {
      final favs = await _repo.favorites(take: 50);
      if (!mounted) return;
      setState(() {
        _favorites = favs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'بارگذاری ستاره‌دارها ناموفق بود — ${_clean(e)}';
      });
    }
  }

  Future<void> _loadRecent() async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.recentlyViewed(take: 10);
      if (!mounted) return;
      setState(() {
        _recent = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'بارگذاری اخیر ناموفق بود — ${_clean(e)}';
      });
    }
  }

  void _switchTab(DocTab t) {
    setState(() => _tab = t);
    switch (t) {
      case DocTab.all:
        _loadDocs();
      case DocTab.fav:
        _loadFavorites();
      case DocTab.recent:
        _loadRecent();
    }
  }

  void _onSearchChanged(String _) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loadDocs();
    });
  }

  void _toggleFavorite(DocRow d) async {
    try {
      await _repo.toggleFavorite(d.id);
      if (!mounted) return;
      if (_tab == DocTab.fav) {
        await _loadFavorites();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('وضعیت ستاره‌دار تغییر کرد.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_clean(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String get _title => switch (_status) {
    DocStatusFilter.inactive => 'مدارک غیرفعال',
    DocStatusFilter.deleted => 'سطل بازیافت',
    DocStatusFilter.active => 'آرشیو اسناد و مدارک',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          _title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'کارتابل آرشیو',
            icon: const Icon(Icons.move_to_inbox_rounded, size: 19),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DocArchiveCartablePage(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'مدرک جدید',
            icon: const Icon(Icons.add_rounded, size: 20),
            onPressed: _openNewDoc,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _bootstrap();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 26),
          children: [
            const ShopHeader(
              title: 'آرشیو اسناد و مدارک',
              subtitle: 'پوشه‌ها، نسخه‌ها و گردش تأیید مدارک',
              icon: Icons.folder_open_rounded,
              badge: 'DMS',
            ),
            const SizedBox(height: 10),
            ShopSegmented(
              labels: const ['همه مدارک', 'ستاره‌دارها', 'اخیراً دیده‌شده'],
              index: _tab.index,
              onChanged: (i) => _switchTab(DocTab.values[i]),
            ),
            const SizedBox(height: 8),
            if (_error != null) ...[
              SystemNote(
                text: _error!,
                color: ShopColors.danger,
                icon: Icons.error_outline_rounded,
              ),
              const SizedBox(height: 8),
            ],
            if (_tab == DocTab.all) ...[
              _searchBar(),
              const SizedBox(height: 8),
              _foldersCard(),
              const SizedBox(height: 8),
              _filtersRow(),
              const SizedBox(height: 8),
              _countRow(),
              const SizedBox(height: 6),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_docs.isEmpty)
                const SystemNote(
                  text: 'مدرکی یافت نشد',
                  icon: Icons.file_present_rounded,
                )
              else ...[
                for (final d in _docs) _docCard(d),
                if (_total > _skip + _docs.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _skip += _pageSize;
                        _loadDocs(reset: false);
                      },
                      icon: const Icon(Icons.expand_more_rounded, size: 17),
                      label: Text(
                        'موارد بیشتر (${Fa.digits(_total - _skip - _docs.length)})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ] else if (_tab == DocTab.fav) ...[
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_favorites.isEmpty)
                const SystemNote(
                  text: 'هنوز مدرکی را ستاره‌دار نکرده‌اید',
                  icon: Icons.star_border_rounded,
                )
              else
                for (final f in _favorites)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ShopColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ShopColors.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${f.code} — ${f.title}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${f.folderCell} · ${Fa.date(f.favoritedAt?.toIso8601String())}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'حذف از ستاره‌دارها',
                          icon: const Icon(
                            Icons.star_rounded,
                            size: 19,
                            color: Colors.amber,
                          ),
                          onPressed: () async {
                            await _repo.toggleFavorite(f.documentId);
                            if (mounted) await _loadFavorites();
                          },
                        ),
                      ],
                    ),
                  ),
            ] else ...[
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_recent.isEmpty)
                const SystemNote(
                  text: 'هنوز مدرکی را باز نکرده‌اید',
                  icon: Icons.history_rounded,
                )
              else ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'اخیراً دیده‌شده (۱۰ مورد آخر)',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                for (final r in _recent)
                  InkWell(
                    onTap: () => _openDoc(r.documentId),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ShopColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r.code} — ${r.title}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${r.folderCell} · ${Fa.date(r.viewedAt?.toIso8601String())}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: ShopColors.inkFaint,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openNewDoc() async {
    if (_folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پوشه مدرک را انتخاب کنید.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DocArchiveFormPage(
          folders: _folders,
          tags: _tags,
          numberingEnabled: true,
          defaultFolderId: _folderId,
        ),
      ),
    );
    if (created == true) await _loadDocs();
  }

  void _openDoc(int id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => DocArchiveDetailPage(id: id)),
    );
    if (mounted) await _loadDocs();
  }

  Widget _searchBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ShopColors.line),
    ),
    child: Row(
      children: [
        const Icon(Icons.search_rounded, size: 17, color: ShopColors.inkFaint),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 11.5),
            decoration: const InputDecoration(
              hintText: 'جستجوی اسناد…',
              hintStyle: TextStyle(
                fontSize: 10.5,
                color: ShopColors.inkFaint,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        if (_search.text.isNotEmpty)
          IconButton(
            tooltip: 'پاک کردن جستجو',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: ShopColors.inkFaint,
            ),
            onPressed: () {
              _search.clear();
              _loadDocs();
              setState(() {});
            },
          ),
      ],
    ),
  );

  Widget _foldersCard() => Container(
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        initiallyExpanded: false,
        leading: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ShopColors.seed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.account_tree_rounded,
            size: 16,
            color: ShopColors.seed,
          ),
        ),
        title: const Text(
          'پوشه‌ها',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          _folderId == null
              ? 'همه مدارک'
              : folderPathText(_folders, _folderId!),
          style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
        ),
        children: [
          _shortcut(
            icon: Icons.archive_rounded,
            label: 'همه مدارک',
            count: null,
            color: ShopColors.seed,
            active:
                _status == DocStatusFilter.active &&
                _folderId == null &&
                _expiryFilter == null,
            onTap: () {
              setState(() {
                _status = DocStatusFilter.active;
                _folderId = null;
                _expiryFilter = null;
              });
              _loadDocs();
            },
          ),
          _shortcut(
            icon: Icons.event_busy_rounded,
            label: 'منقضی شده',
            count: _stats.expired,
            color: ShopColors.danger,
            active: _expiryFilter == 'expired',
            onTap: () {
              setState(() {
                _status = DocStatusFilter.active;
                _expiryFilter = 'expired';
                _folderId = null;
              });
              _loadDocs();
            },
          ),
          _shortcut(
            icon: Icons.hourglass_bottom_rounded,
            label: 'رو به انقضا',
            count: _stats.expiring,
            color: ShopColors.warn,
            active: _expiryFilter == 'expiring',
            onTap: () {
              setState(() {
                _status = DocStatusFilter.active;
                _expiryFilter = 'expiring';
                _folderId = null;
              });
              _loadDocs();
            },
          ),
          _shortcut(
            icon: Icons.inventory_2_rounded,
            label: 'مدارک غیرفعال',
            count: _stats.inactive,
            color: ShopColors.inkSoft,
            active: _status == DocStatusFilter.inactive,
            onTap: () {
              setState(() {
                _status = DocStatusFilter.inactive;
                _expiryFilter = null;
                _folderId = null;
              });
              _loadDocs();
            },
          ),
          _shortcut(
            icon: Icons.delete_outline_rounded,
            label: 'سطل بازیافت',
            count: _stats.deleted,
            color: ShopColors.danger,
            active: _status == DocStatusFilter.deleted,
            onTap: () {
              setState(() {
                _status = DocStatusFilter.deleted;
                _expiryFilter = null;
                _folderId = null;
              });
              _loadDocs();
            },
          ),
          const Divider(height: 12),
          for (final f in _folders)
            _shortcut(
              icon: Icons.folder_rounded,
              label: f.name,
              count: f.documentCount,
              color: ShopColors.seed,
              active: _folderId == f.id,
              level: f.levelName,
              onTap: () {
                setState(() {
                  _folderId = f.id;
                  _status = DocStatusFilter.active;
                  _expiryFilter = null;
                });
                _loadDocs();
              },
            ),
        ],
      ),
    ),
  );

  Widget _shortcut({
    required IconData icon,
    required String label,
    required int? count,
    required Color color,
    required bool active,
    required VoidCallback onTap,
    String? level,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                color: ShopColors.ink,
              ),
            ),
          ),
          if (level != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                level,
                style: const TextStyle(
                  fontSize: 8.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
          if (count != null && count > 0)
            ShopTag(text: Fa.digits(count), color: color),
        ],
      ),
    ),
  );

  Widget _filtersRow() => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<String?>(
          initialValue: _expiryFilter,
          isDense: true,
          style: const TextStyle(fontSize: 11, color: ShopColors.ink),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: ShopColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: ShopColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: ShopColors.line),
            ),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('همه وضعیت‌ها')),
            DropdownMenuItem(value: 'expiring', child: Text('رو به انقضا')),
            DropdownMenuItem(value: 'expired', child: Text('منقضی شده')),
            DropdownMenuItem(value: 'all', child: Text('منقضی + رو به انقضا')),
          ],
          onChanged: (v) {
            setState(() => _expiryFilter = v);
            _loadDocs();
          },
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: ShopColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'شامل زیرپوشه‌ها',
              style: TextStyle(fontSize: 9.5, color: ShopColors.inkSoft),
            ),
            Switch(
              value: _includeSubfolders,
              onChanged: (v) {
                setState(() => _includeSubfolders = v);
                _loadDocs();
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    ],
  );

  Widget _countRow() => Row(
    children: [
      ShopTag(
        text: '${Fa.digits(_total)} مدرک',
        color: ShopColors.seed,
        icon: Icons.description_rounded,
      ),
      const Spacer(),
      if (_tags.isNotEmpty)
        TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: _pickTags,
          icon: const Icon(Icons.local_offer_rounded, size: 14),
          label: Text(
            _selectedTagIds.isEmpty
                ? 'برچسب‌ها'
                : 'برچسب‌ها (${Fa.digits(_selectedTagIds.length)})',
            style: const TextStyle(fontSize: 10),
          ),
        ),
    ],
  );

  Future<void> _pickTags() async {
    final picked = await showModalBottomSheet<Set<int>>(
      context: context,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) {
        final sel = {..._selectedTagIds};
        return StatefulBuilder(
          builder: (c, setLocal) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'برچسب‌ها',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _tags)
                      FilterChip(
                        label: Text(
                          t.name,
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: sel.contains(t.id),
                        onSelected: (v) => setLocal(() {
                          if (v) {
                            sel.add(t.id);
                          } else {
                            sel.remove(t.id);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(c).pop(<int>{}),
                        child: const Text(
                          'پاک کردن',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(c).pop(sel),
                        child: const Text(
                          'اعمال',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTagIds
          ..clear()
          ..addAll(picked);
      });
    }
  }

  Widget _docCard(DocRow d) {
    final expired = d.isExpired;
    final soon = d.isExpiringSoon;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _openDoc(d.id),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(13),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 6, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              d.code,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ShopTag(
                              text: d.levelName,
                              color: docLevelColor(d.myLevel),
                            ),
                            if (d.versionCount > 0) ...[
                              const SizedBox(width: 4),
                              ShopTag(
                                text: d.activeVersionText,
                                color: ShopColors.seed,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          d.title,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d.folderCell} · ${d.createdByName} · ${Fa.date(d.createdAt?.toIso8601String())}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: const Icon(
                      Icons.star_border_rounded,
                      size: 18,
                      color: Colors.amber,
                    ),
                    onPressed: () => _toggleFavorite(d),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 11, 9),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ShopTag(
                  text: DocVersionStatus.nameExplorer(d.lastVersionStatus),
                  color: docVersionColor(d.lastVersionStatus),
                ),
                if (expired)
                  ShopTag(text: 'منقضی شده', color: ShopColors.danger)
                else if (d.daysToExpire != null)
                  ShopTag(
                    text: d.expiryText,
                    color: soon ? ShopColors.warn : ShopColors.inkFaint,
                    icon: Icons.event_rounded,
                  ),
                if (!d.isActive)
                  const ShopTag(
                    text: 'غیرفعال',
                    color: ShopColors.inkFaint,
                  ),
                if (d.isDeleted)
                  const ShopTag(text: 'در سطل', color: ShopColors.danger),
                if (d.isPublic)
                  const ShopTag(text: 'نمایش برای همه', color: ShopColors.teal),
                if (d.linkCount > 0)
                  ShopTag(
                    text: '${Fa.digits(d.linkCount)} مرتبط',
                    color: ShopColors.seed,
                    icon: Icons.link_rounded,
                  ),
                for (final t in d.tags.take(3))
                  ShopTag(text: t.name, color: colorFromHex(t.color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// نگاشت رنگ HEX سرور به Color — برای برچسب‌ها
Color colorFromHex(String hex) {
  var h = hex.trim().replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final v = int.tryParse(h, radix: 16);
  return v == null ? ShopColors.seed : Color(0xff000000 | v);
}

/// رنگ نشان سطح دسترسی
Color docLevelColor(int level) => switch (level) {
  4 => ShopColors.ok,
  3 => ShopColors.seed,
  2 => ShopColors.teal,
  1 => ShopColors.warn,
  _ => ShopColors.inkFaint,
};

/// رنگ نشان وضعیت نسخه
Color docVersionColor(int status) => switch (status) {
  2 => ShopColors.ok,
  1 => ShopColors.warn,
  3 => ShopColors.danger,
  0 => ShopColors.inkSoft,
  _ => ShopColors.inkFaint,
};
