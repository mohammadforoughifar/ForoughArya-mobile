// ============================================================
//  «دبیرخانه یکپارچه اتوماسیون اداری توکا» — نسخهٔ بومی اندروید
//  هم‌تراز ۱۰۰٪ با وب (`OutgoingDabirkhane.razor` + `IntegratedIncomingPanel.razor`
//  + `IncomingReservationManager.razor`):
//    • سوییچر دوگانهٔ دبیرخانه: «نامه‌های صادره» ↔ «نامه‌های وارده»
//    • ۴ کارت شاخص زنده (در انتظار ثبت و ارسال، ثبت و ارسال شده، بایگانی شده، کل امضاشده)
//    • ۴ صف دبیرخانه صادره: در انتظار ثبت | ثبت‌شده | درخت بایگانی دبیرخانه | همه
//    • جستجوی پیشرفته ۹ فیلتره با تقویم شمسی (روش ارسال، فرستنده، سربرگ، مقصد، محرمانگی، فوریت…)
//    • شیت هوشمند «ثبت و ارسال دبیرخانه» با فیلدهای پویا بر اساس ۷ روش ارسال وب + ارسال ایمیل
//    • چاپ رسمی دو نسخه‌ای («با رونوشت» / «بدون رونوشت» — A4 و A5) + نمایش درخت گردش نامه
//    • مدیریت کامل «رزرو شماره اندیکاتور» (۱ تا ۲۰ شماره) برای نامه‌های وارده/داخلی/صادره
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/web_access.dart';
import '../../../core/utils/web_files.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/email_repository.dart';
import '../data/office_repository.dart';
import '../models/email_models.dart';
import '../models/letter_models.dart';
import '../models/office_common.dart';
import 'letter_detail_page.dart';
import 'letter_editor_page.dart';
import 'office_style.dart';

enum DabirkhaneMode { sadere, varede }

enum DabirkhaneTab { pending, registered, archived, all }

class OfficeDabirkhanePage extends StatefulWidget {
  const OfficeDabirkhanePage({
    super.key,
    this.initialMode = DabirkhaneMode.sadere,
    this.initialTab = DabirkhaneTab.pending,
    this.embedded = false,
    this.openReservationsOnStart = false,
  });

  final DabirkhaneMode initialMode;
  final DabirkhaneTab initialTab;
  final bool embedded;
  final bool openReservationsOnStart;

  @override
  State<OfficeDabirkhanePage> createState() => _OfficeDabirkhanePageState();
}

class _OfficeDabirkhanePageState extends State<OfficeDabirkhanePage> {
  OfficeAutomationRepository get _repo =>
      Provider.of<OfficeAutomationRepository?>(context, listen: false) ??
      OfficeAutomationRepository(context.read<ApiClient>());

  EmailRepository get _emailRepo =>
      Provider.of<EmailRepository?>(context, listen: false) ??
      EmailRepository(context.read<ApiClient>());

  late DabirkhaneMode _mode = widget.initialMode;
  late DabirkhaneTab _tab = widget.initialTab;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // --- وضعیت دبیرخانه صادره ---
  DabirkhaneStats _stats = const DabirkhaneStats();
  List<LetterListItem> _items = const [];
  List<ArchiveNode> _archiveTree = const [];
  List<LetterRecipient> _creators = const [];
  List<Map<String, dynamic>> _companies = const [];
  bool _loading = true;
  String? _error;

  // فیلترهای پیشرفتهٔ دبیرخانه صادره
  String _fMethod = '';
  int _fCreatorId = 0;
  int _fCompanyId = 0;
  String _fOrg = '';
  String _fMahramanegi = '';
  String _fForiat = '';
  bool? _fAttachment;
  DateTime? _fFrom;
  DateTime? _fTo;
  bool _searchAllScopes = false;

  // --- وضعیت دبیرخانه وارده ---
  String _incomingView = 'registered'; // registered | archived
  List<LetterListItem> _incomingItems = const [];
  int _incomingRegisteredTotal = 0;
  int _incomingArchivedTotal = 0;
  final Set<int> _selectedIncomingIds = <int>{};

  int get _activeFilterCount {
    var c = 0;
    if (_fMethod.isNotEmpty) c++;
    if (_fCreatorId > 0) c++;
    if (_fCompanyId > 0) c++;
    if (_fOrg.trim().isNotEmpty) c++;
    if (_fMahramanegi.isNotEmpty) c++;
    if (_fForiat.isNotEmpty) c++;
    if (_fAttachment != null) c++;
    if (_fFrom != null || _fTo != null) c++;
    if (_searchAllScopes) c++;
    return c;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _reloadAll();
      if (widget.openReservationsOnStart && mounted) {
        _openReservationSheet();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadAll() async {
    if (_mode == DabirkhaneMode.sadere) {
      await Future.wait([
        _loadOutgoingDabirkhane(),
        _loadLookups(),
      ]);
    } else {
      await _loadIncomingDabirkhane();
    }
  }

  Future<void> _loadLookups() async {
    try {
      final res = await Future.wait([
        _repo.dabirkhaneCreators().catchError((_) => const <LetterRecipient>[]),
        _repo.companies().catchError((_) => const <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _creators = res[0] as List<LetterRecipient>;
        _companies = res[1] as List<Map<String, dynamic>>;
      });
    } catch (_) {}
  }

  Future<void> _loadOutgoingDabirkhane() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statsFut = _repo.dabirkhaneStats().catchError(
        (_) => const DabirkhaneStats(),
      );
      if (_tab == DabirkhaneTab.archived && !_searchAllScopes) {
        final tree = await _repo.dabirkhaneArchiveTree();
        final st = await statsFut;
        if (!mounted) return;
        setState(() {
          _archiveTree = tree;
          _stats = st;
          _loading = false;
        });
        return;
      }

      bool? registeredOnly;
      bool? archivedOnly;
      if (!_searchAllScopes) {
        switch (_tab) {
          case DabirkhaneTab.pending:
            registeredOnly = false;
            archivedOnly = false;
          case DabirkhaneTab.registered:
            registeredOnly = true;
            archivedOnly = false;
          case DabirkhaneTab.archived:
            archivedOnly = true;
          case DabirkhaneTab.all:
            break;
        }
      }

      final page = await _repo.dabirkhane(
        page: 1,
        pageSize: 60,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        registeredOnly: registeredOnly,
        archivedOnly: archivedOnly,
        sendMethod: _fMethod.isEmpty ? null : _fMethod,
        creatorUserId: _fCreatorId > 0 ? _fCreatorId : null,
        companyId: _fCompanyId > 0 ? _fCompanyId : null,
        receiverOrganization: _fOrg.trim().isEmpty ? null : _fOrg.trim(),
        mahramanegi: _fMahramanegi.isEmpty ? null : _fMahramanegi,
        foriat: _fForiat.isEmpty ? null : _fForiat,
        hasAttachment: _fAttachment,
        fromDate: _fFrom,
        toDate: _fTo,
      );
      final st = await statsFut;
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _stats = st;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadIncomingDabirkhane() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim();
      final regFut = _repo.incomingSent(page: 1, pageSize: 50, search: q);
      final arcFut = _repo.incomingArchive(page: 1, pageSize: 50, search: q);
      final results = await Future.wait([regFut, arcFut]);
      if (!mounted) return;
      setState(() {
        _incomingRegisteredTotal = results[0].totalCount;
        _incomingArchivedTotal = results[1].totalCount;
        _incomingItems = _incomingView == 'archived'
            ? results[1].items
            : results[0].items;
        _selectedIncomingIds.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 340), _reloadAll);
  }

  void _clearFilters() {
    setState(() {
      _fMethod = '';
      _fCreatorId = 0;
      _fCompanyId = 0;
      _fOrg = '';
      _fMahramanegi = '';
      _fForiat = '';
      _fAttachment = null;
      _fFrom = null;
      _fTo = null;
      _searchAllScopes = false;
    });
    _loadOutgoingDabirkhane();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? OfficeColors.danger : const Color(0xff14594f),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  //  عملیات دبیرخانه (ثبت و ارسال، چاپ دو نسخه‌ای، گردش، بایگانی، رزرو اندیکاتور)
  // ============================================================

  Future<void> _openRegisterSheet(LetterListItem item) async {
    List<EmailAccount> dabirAccounts = const [];
    try {
      dabirAccounts = await _emailRepo.dabirkhaneAccounts();
      if (dabirAccounts.isEmpty) {
        final all = await _emailRepo.accounts();
        dabirAccounts = all.where((a) => a.isDabirkhane || a.isActive).toList();
      }
    } catch (_) {}
    if (!mounted) return;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DabirkhaneRegisterSheet(
        item: item,
        repo: _repo,
        dabirAccounts: dabirAccounts,
      ),
    );
    if (ok == true) {
      _toast('نامه در دبیرخانه ثبت و ارسال شد.');
      await _loadOutgoingDabirkhane();
    }
  }

  Future<void> _openPrintSheet(LetterListItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String size = 'A4';
        bool withCopy = true;
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setS) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xff3357b0).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.print_rounded,
                            color: Color(0xff3357b0),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'چاپ رسمی دبیرخانه — ${Fa.digits(item.sadereNumber ?? item.letterNumber)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xff66779c),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'اندازه کاغذ سربرگ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            selected: size == 'A4',
                            label: const Center(child: Text('سربرگ A4')),
                            onSelected: (_) => setS(() => size = 'A4'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            selected: size == 'A5',
                            label: const Center(child: Text('سربرگ A5')),
                            onSelected: (_) => setS(() => size = 'A5'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'نسخهٔ چاپ دبیرخانه',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    _SelectableOptionTile(
                      selected: withCopy,
                      title: 'نسخهٔ کامل (با رونوشت‌گیرندگان)',
                      subtitle: 'مناسب پروندهٔ بایگانی داخلی و رونوشت واحدها',
                      icon: Icons.copy_all_rounded,
                      onTap: () => setS(() => withCopy = true),
                    ),
                    const SizedBox(height: 6),
                    _SelectableOptionTile(
                      selected: !withCopy,
                      title: 'نسخهٔ اصل گیرنده (بدون رونوشت)',
                      subtitle: 'مناسب ارسال رسمی به سازمان مقصد',
                      icon: Icons.verified_outlined,
                      onTap: () => setS(() => withCopy = false),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff3357b0),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: busy
                          ? null
                          : () async {
                              setS(() => busy = true);
                              try {
                                final resp = await _repo.outgoingPrint(
                                  item.letterId,
                                  size: size,
                                  withCopy: withCopy,
                                );
                                final bytes = resp.data;
                                if (bytes == null || bytes.isEmpty) {
                                  throw Exception('فایل چاپی از سرور دریافت نشد.');
                                }
                                final fileName =
                                    'sadere_${item.letterId}_${size}_${withCopy ? 'copy' : 'orig'}.pdf';
                                if (!await webDeliver(bytes, fileName)) {
                                  final dir = await getTemporaryDirectory();
                                  final file = File('${dir.path}/$fileName');
                                  await file.writeAsBytes(bytes, flush: true);
                                  final res = await OpenFilex.open(file.path);
                                  if (res.type != ResultType.done) {
                                    await Share.shareXFiles([XFile(file.path)]);
                                  }
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                _toast(e.toString(), error: true);
                              } finally {
                                if (ctx.mounted) setS(() => busy = false);
                              }
                            },
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: Text(
                        busy ? 'در حال تولید PDF سربرگ…' : 'دریافت و نمایش نسخهٔ چاپی',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGardeshSheet(LetterKind kind, LetterListItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GardeshTreeSheet(
        repo: _repo,
        kind: kind,
        letterId: item.letterId,
        title: item.title,
      ),
    );
  }

  Future<void> _openArchivePickerForOutgoing(List<int> letterIds) async {
    if (letterIds.isEmpty) return;
    List<ArchiveNode> tree = const [];
    try {
      tree = await _repo.dabirkhaneArchiveTree();
    } catch (_) {}
    if (!mounted) return;

    final folders = _flattenFolders(tree);
    final newFolderCtrl = TextEditingController();

    final chosenFolderId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'انتخاب پوشهٔ بایگانی رسمی دبیرخانه',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newFolderCtrl,
                          decoration: InputDecoration(
                            hintText: 'ساخت پوشهٔ جدید در بایگانی دبیرخانه…',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final t = newFolderCtrl.text.trim();
                          if (t.isEmpty) return;
                          try {
                            await _repo.addDabirkhaneFolder(t);
                            newFolderCtrl.clear();
                            final fresh = await _repo.dabirkhaneArchiveTree();
                            setS(() {
                              folders
                                ..clear()
                                ..addAll(_flattenFolders(fresh));
                            });
                          } catch (e) {
                            _toast(e.toString(), error: true);
                          }
                        },
                        icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                        label: const Text('ایجاد'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (folders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'هنوز پوشه‌ای در بایگانی دبیرخانه ساخته نشده است. ابتدا یک پوشه بسازید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xff66779c)),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: folders.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final f = folders[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.folder_rounded,
                              color: Color(0xff46536b),
                            ),
                            title: Text(
                              '${'  ' * f.depth}${f.node.title}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            trailing: const Icon(Icons.chevron_left_rounded),
                            onTap: () => Navigator.pop(ctx, f.node.id),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    newFolderCtrl.dispose();
    if (chosenFolderId == null) return;
    try {
      await _repo.archiveDabirkhaneLetters(
        folderId: chosenFolderId,
        letterIds: letterIds,
      );
      _toast('در بایگانی رسمی دبیرخانه ثبت شد.');
      await _loadOutgoingDabirkhane();
    } catch (e) {
      _toast(e.toString(), error: true);
    }
  }

  List<({ArchiveNode node, int depth})> _flattenFolders(
    List<ArchiveNode> nodes, [
    int depth = 0,
  ]) {
    final out = <({ArchiveNode node, int depth})>[];
    for (final n in nodes) {
      if (n.isFolder) {
        out.add((node: n, depth: depth));
        out.addAll(_flattenFolders(n.children, depth + 1));
      }
    }
    return out;
  }

  Future<void> _openReservationSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReservationManagerSheet(repo: _repo),
    );
  }

  Future<void> _openAdvancedFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                14,
                18,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: Color(0xff3357b0)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'جستجوی پیشرفتهٔ دبیرخانه صادره',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _clearFilters();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.restart_alt_rounded, size: 17),
                        label: const Text('پاک‌سازی'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _fMethod,
                    decoration: _inputDec('روش ارسال دبیرخانه'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('همه روش‌ها')),
                      for (final m in LetterSendMethodSpec.allMethods)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) => setS(() => _fMethod = v ?? ''),
                  ),
                  const SizedBox(height: 10),
                  if (_creators.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _creators.any((c) => c.userId == _fCreatorId)
                          ? _fCreatorId
                          : 0,
                      decoration: _inputDec('فرستنده / ثبت‌کننده'),
                      items: [
                        const DropdownMenuItem(value: 0, child: Text('همه ثبت‌کنندگان')),
                        for (final c in _creators)
                          DropdownMenuItem(
                            value: c.userId,
                            child: Text(c.label, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setS(() => _fCreatorId = v ?? 0),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_companies.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _companies.any(
                            (c) => pickInt(c, ['id', 'Id']) == _fCompanyId,
                          )
                          ? _fCompanyId
                          : 0,
                      decoration: _inputDec('شرکت صادرکننده (سربرگ)'),
                      items: [
                        const DropdownMenuItem(value: 0, child: Text('همه شرکت‌ها')),
                        for (final c in _companies)
                          DropdownMenuItem(
                            value: pickInt(c, ['id', 'Id']),
                            child: Text(
                              pickStr(c, ['name', 'Name']),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setS(() => _fCompanyId = v ?? 0),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextFormField(
                    initialValue: _fOrg,
                    decoration: _inputDec('نام سازمان مقصد'),
                    onChanged: (v) => _fOrg = v,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _fMahramanegi,
                          decoration: _inputDec('محرمانگی'),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('همه')),
                            DropdownMenuItem(value: 'عادی', child: Text('عادی')),
                            DropdownMenuItem(value: 'محرمانه', child: Text('محرمانه')),
                            DropdownMenuItem(value: 'سری', child: Text('سری')),
                          ],
                          onChanged: (v) => setS(() => _fMahramanegi = v ?? ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _fForiat,
                          decoration: _inputDec('فوریت'),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('همه')),
                            DropdownMenuItem(value: 'عادی', child: Text('عادی')),
                            DropdownMenuItem(value: 'فوری', child: Text('فوری')),
                            DropdownMenuItem(value: 'آنی', child: Text('آنی')),
                          ],
                          onChanged: (v) => setS(() => _fForiat = v ?? ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _fAttachment == null
                        ? ''
                        : (_fAttachment! ? 'true' : 'false'),
                    decoration: _inputDec('وضعیت پیوست'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('فرقی ندارد')),
                      DropdownMenuItem(value: 'true', child: Text('فقط پیوست‌دار')),
                      DropdownMenuItem(value: 'false', child: Text('بدون پیوست')),
                    ],
                    onChanged: (v) => setS(() {
                      _fAttachment = v == 'true'
                          ? true
                          : (v == 'false' ? false : null);
                    }),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final range = await showJalaliDateRangePicker(
                        context,
                        initialStart: _fFrom,
                        initialEnd: _fTo,
                      );
                      if (range != null) {
                        setS(() {
                          _fFrom = range.start;
                          _fTo = range.end;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: Text(
                      (_fFrom == null && _fTo == null)
                          ? 'انتخاب بازه تاریخ صدور (شمسی)'
                          : jalaliRangeLabel(_fFrom, _fTo),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _searchAllScopes,
                    onChanged: (v) => setS(() => _searchAllScopes = v ?? false),
                    title: const Text(
                      'جستجو در همهٔ نامه‌های امضاشده (صرف‌نظر از تب جاری)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff3357b0),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(ctx);
                      _loadOutgoingDabirkhane();
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(
                      'اعمال فیلترهای دبیرخانه',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static InputDecoration _inputDec(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  // ============================================================
  //  رابط کاربری اصلی
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<AuthController?>(context)?.session;
    final access = WebAccess(session, unrestrictedWhenNull: true);

    if (!access.canSeeDabirkhane && !access.canSeeIncomingLetters) {
      return Scaffold(
        backgroundColor: OfficeColors.bg,
        appBar: widget.embedded
            ? null
            : AppBar(title: const Text('دبیرخانه یکپارچه توکا')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'شما مجوز دسترسی به «دبیرخانه یکپارچه اتوماسیون اداری توکا» را ندارید.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }

    final content = Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _reloadAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (!widget.embedded)
              SliverToBoxAdapter(child: _buildStandaloneHero(access)),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                14,
                widget.embedded ? 12 : 14,
                14,
                96,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildModeSwitcherBar(access),
                  const SizedBox(height: 12),
                  if (_mode == DabirkhaneMode.sadere)
                    ..._buildOutgoingSection(access)
                  else
                    ..._buildIncomingSection(access),
                ]),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xfff7f9fe),
      body: content,
      floatingActionButton: _mode == DabirkhaneMode.varede &&
              access.canCreateIncomingLetter
          ? FloatingActionButton.extended(
              heroTag: 'dabirkhane_incoming_create_fab',
              backgroundColor: const Color(0xff1466a6),
              foregroundColor: Colors.white,
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const LetterEditorPage(kind: LetterKind.incoming),
                  ),
                );
                if (created == true) await _loadIncomingDabirkhane();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'ثبت نامه وارده جدید',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
    );
  }

  Widget _buildStandaloneHero(WebAccess access) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xffffffff), Color(0xffe9effa)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xff8a6a24), width: 1.3),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff2547a8),
                  side: const BorderSide(color: Color(0xffdce3ee)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 21),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff8a6a24), Color(0xffc9a24b)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x338a6a24),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.markunread_mailbox_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'دبیرخانه یکپارچه توکا',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xff173a63),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'شماره‌گذاری اندیکاتور، ثبت ارسال، رونوشت، چاپ سربرگ و بایگانی رسمی',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xff5a6a8c), fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (access.canSeeDabirkhane)
                IconButton(
                  tooltip: 'رزرو شماره اندیکاتور',
                  onPressed: _openReservationSheet,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff8a6a24),
                    side: const BorderSide(color: Color(0xffdce3ee)),
                  ),
                  icon: const Icon(Icons.tag_rounded, size: 20),
                ),
              IconButton(
                tooltip: 'به‌روزرسانی',
                onPressed: _loading ? null : _reloadAll,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitcherBar(WebAccess access) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdce3ee)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff26314e).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ModePill(
                  active: _mode == DabirkhaneMode.sadere,
                  icon: Icons.north_east_rounded,
                  label: 'دبیرخانه صادره',
                  badge: _stats.pending > 0 ? Fa.digits(_stats.pending) : null,
                  activeColor: const Color(0xff3357b0),
                  onTap: () {
                    if (_mode == DabirkhaneMode.sadere) return;
                    setState(() => _mode = DabirkhaneMode.sadere);
                    _reloadAll();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ModePill(
                  active: _mode == DabirkhaneMode.varede,
                  icon: Icons.south_west_rounded,
                  label: 'دبیرخانه وارده',
                  badge: _incomingRegisteredTotal > 0
                      ? Fa.digits(_incomingRegisteredTotal)
                      : null,
                  activeColor: const Color(0xff1466a6),
                  onTap: () {
                    if (_mode == DabirkhaneMode.varede) return;
                    setState(() => _mode = DabirkhaneMode.varede);
                    _reloadAll();
                  },
                ),
              ),
            ],
          ),
          if (access.canSeeDabirkhane) ...[
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openReservationSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xfffafbfe),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffdce3ee)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.pin_outlined,
                      size: 17,
                      color: Color(0xff3357b0),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'مدیریت و رزرو شماره اندیکاتور دبیرخانه',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff2c3a58),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: Color(0xff66779c),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  //  بخش دبیرخانه نامه‌های صادره (`OutgoingDabirkhane.razor`)
  // ============================================================

  List<Widget> _buildOutgoingSection(WebAccess access) {
    return [
      // ۴ کارت آمار زنده دبیرخانه
      LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: w,
                child: _DabirStatTile(
                  label: 'در انتظار ثبت و ارسال',
                  value: _stats.pending,
                  icon: Icons.hourglass_top_rounded,
                  color: const Color(0xffb4771e),
                  selected: _tab == DabirkhaneTab.pending,
                  onTap: () {
                    setState(() => _tab = DabirkhaneTab.pending);
                    _loadOutgoingDabirkhane();
                  },
                ),
              ),
              SizedBox(
                width: w,
                child: _DabirStatTile(
                  label: 'ثبت و ارسال شده',
                  value: _stats.registered,
                  icon: Icons.verified_rounded,
                  color: const Color(0xff1f6e45),
                  selected: _tab == DabirkhaneTab.registered,
                  onTap: () {
                    setState(() => _tab = DabirkhaneTab.registered);
                    _loadOutgoingDabirkhane();
                  },
                ),
              ),
              SizedBox(
                width: w,
                child: _DabirStatTile(
                  label: 'بایگانی دبیرخانه',
                  value: _stats.archived,
                  icon: Icons.inventory_2_rounded,
                  color: const Color(0xff46536b),
                  selected: _tab == DabirkhaneTab.archived,
                  onTap: () {
                    setState(() => _tab = DabirkhaneTab.archived);
                    _loadOutgoingDabirkhane();
                  },
                ),
              ),
              SizedBox(
                width: w,
                child: _DabirStatTile(
                  label: 'کل نامه‌های امضاشده',
                  value: _stats.total,
                  icon: Icons.mark_email_read_rounded,
                  color: const Color(0xff3357b0),
                  selected: _tab == DabirkhaneTab.all,
                  onTap: () {
                    setState(() => _tab = DabirkhaneTab.all);
                    _loadOutgoingDabirkhane();
                  },
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),

      // تب‌های ۴گانه + نوار جستجو و فیلتر پیشرفته
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffdce3ee)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TabChip(
                    label: 'در انتظار ثبت',
                    active: _tab == DabirkhaneTab.pending,
                    onTap: () {
                      setState(() => _tab = DabirkhaneTab.pending);
                      _loadOutgoingDabirkhane();
                    },
                  ),
                  const SizedBox(width: 6),
                  _TabChip(
                    label: 'ثبت‌شده',
                    active: _tab == DabirkhaneTab.registered,
                    onTap: () {
                      setState(() => _tab = DabirkhaneTab.registered);
                      _loadOutgoingDabirkhane();
                    },
                  ),
                  const SizedBox(width: 6),
                  _TabChip(
                    label: 'درخت بایگانی',
                    icon: Icons.account_tree_outlined,
                    active: _tab == DabirkhaneTab.archived,
                    onTap: () {
                      setState(() => _tab = DabirkhaneTab.archived);
                      _loadOutgoingDabirkhane();
                    },
                  ),
                  const SizedBox(width: 6),
                  _TabChip(
                    label: 'همه نامه‌ها',
                    active: _tab == DabirkhaneTab.all,
                    onTap: () {
                      setState(() => _tab = DabirkhaneTab.all);
                      _loadOutgoingDabirkhane();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText:
                          'جستجو در شماره صادره، عنوان، مقصد، تحویل‌گیرنده، کد رهگیری…',
                      hintStyle: const TextStyle(fontSize: 11.5),
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                _loadOutgoingDabirkhane();
                              },
                              icon: const Icon(Icons.close_rounded, size: 17),
                            ),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xfffafbfe),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(color: Color(0xffdce3ee)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(color: Color(0xffdce3ee)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _activeFilterCount > 0,
                  label: Text(Fa.digits(_activeFilterCount)),
                  backgroundColor: const Color(0xff3357b0),
                  child: IconButton.filledTonal(
                    tooltip: 'فیلتر پیشرفته دبیرخانه',
                    onPressed: _openAdvancedFilterSheet,
                    icon: const Icon(Icons.tune_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 42),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error != null)
        _ErrorBanner(message: _error!, onRetry: _loadOutgoingDabirkhane)
      else if (_tab == DabirkhaneTab.archived && !_searchAllScopes)
        _buildDabirkhaneArchiveTreeSection()
      else if (_items.isEmpty)
        const _EmptySecretariatBox(
          icon: Icons.markunread_mailbox_outlined,
          title: 'نامه‌ای در این صف وجود ندارد',
          subtitle:
              'نامه‌های صادره پس از تکمیل امضای همهٔ امضاکنندگان و صدور شماره صادره، به صورت خودکار وارد صف دبیرخانه می‌شوند.',
        )
      else
        for (final item in _items)
          _OutgoingSecretariatCard(
            item: item,
            onView: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LetterDetailPage(
                    kind: LetterKind.outgoing,
                    letterId: item.letterId,
                  ),
                ),
              );
              await _loadOutgoingDabirkhane();
            },
            onGardesh: () => _openGardeshSheet(LetterKind.outgoing, item),
            onPrint: () => _openPrintSheet(item),
            onRegister: () => _openRegisterSheet(item),
            onArchive: item.isArchived
                ? () async {
                    try {
                      await _repo.unarchiveDabirkhaneLetter(item.letterId);
                      _toast('نامه از بایگانی دبیرخانه خارج شد.');
                      await _loadOutgoingDabirkhane();
                    } catch (e) {
                      _toast(e.toString(), error: true);
                    }
                  }
                : () => _openArchivePickerForOutgoing([item.letterId]),
          ),
    ];
  }

  Widget _buildDabirkhaneArchiveTreeSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdce3ee)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_tree_rounded,
                color: Color(0xff46536b),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'درخت پوشه‌های بایگانی رسمی دبیرخانه',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _promptNewDabirkhaneFolder(),
                icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                label: const Text('پوشه جدید', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_archiveTree.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'بایگانی دبیرخانه خالی است. با دکمهٔ «پوشه جدید» دسته‌بندی رسمی بسازید.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xff66779c)),
              ),
            )
          else
            for (final n in _archiveTree) _buildArchiveTreeNode(n, 0),
        ],
      ),
    );
  }

  Widget _buildArchiveTreeNode(ArchiveNode node, int depth) {
    if (node.isFolder) {
      return Padding(
        padding: EdgeInsetsDirectional.only(start: depth * 12.0),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 6),
          leading: const Icon(Icons.folder_rounded, color: Color(0xff46536b)),
          title: Text(
            '${node.title} (${Fa.digits(node.letterCount)})',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (act) async {
              if (act == 'sub') {
                await _promptNewDabirkhaneFolder(parentId: node.id);
              } else if (act == 'del') {
                try {
                  await _repo.deleteDabirkhaneFolder(node.id);
                  await _loadOutgoingDabirkhane();
                } catch (e) {
                  _toast(e.toString(), error: true);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'sub', child: Text('افزودن زیرپوشه')),
              PopupMenuItem(value: 'del', child: Text('حذف پوشه')),
            ],
          ),
          children: [
            for (final ch in node.children) _buildArchiveTreeNode(ch, depth + 1),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * 12.0 + 8),
      child: ListTile(
        dense: true,
        leading: const Icon(
          Icons.description_outlined,
          color: Color(0xff3357b0),
          size: 19,
        ),
        title: Text(
          node.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (node.sadereNumber != null) 'شماره: ${Fa.digits(node.sadereNumber!)}',
            if (node.receiverOrganization != null) node.receiverOrganization!,
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5),
        ),
        trailing: IconButton(
          tooltip: 'خروج از بایگانی',
          icon: const Icon(Icons.unarchive_outlined, size: 18),
          onPressed: node.letterId == null
              ? null
              : () async {
                  try {
                    await _repo.unarchiveDabirkhaneLetter(node.letterId!);
                    await _loadOutgoingDabirkhane();
                  } catch (e) {
                    _toast(e.toString(), error: true);
                  }
                },
        ),
        onTap: node.letterId == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LetterDetailPage(
                    kind: LetterKind.outgoing,
                    letterId: node.letterId!,
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _promptNewDabirkhaneFolder({int parentId = 0}) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            parentId == 0 ? 'ایجاد پوشهٔ اصلی دبیرخانه' : 'ایجاد زیرپوشه جدید',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: _inputDec('عنوان پوشه بایگانی'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ایجاد پوشه'),
            ),
          ],
        ),
      ),
    );
    final t = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || t.isEmpty) return;
    try {
      await _repo.addDabirkhaneFolder(t, sub: parentId > 0, parentId: parentId);
      await _loadOutgoingDabirkhane();
    } catch (e) {
      _toast(e.toString(), error: true);
    }
  }

  // ============================================================
  //  بخش دبیرخانه نامه‌های وارده (`IntegratedIncomingPanel.razor`)
  // ============================================================

  List<Widget> _buildIncomingSection(WebAccess access) {
    return [
      LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: w,
                child: _DabirStatTile(
                  label: 'ثبت و ارسال شده',
                  value: _incomingRegisteredTotal,
                  icon: Icons.fact_check_rounded,
                  color: const Color(0xff1466a6),
                  selected: _incomingView == 'registered',
                  onTap: () {
                    setState(() => _incomingView = 'registered');
                    _loadIncomingDabirkhane();
                  },
                ),
              ),
              SizedBox(
                width: w,
                child: _DabirStatTile(
                  label: 'بایگانی دبیرخانه وارده',
                  value: _incomingArchivedTotal,
                  icon: Icons.archive_rounded,
                  color: const Color(0xff46536b),
                  selected: _incomingView == 'archived',
                  onTap: () {
                    setState(() => _incomingView = 'archived');
                    _loadIncomingDabirkhane();
                  },
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffdce3ee)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _TabChip(
                  label: 'ثبت‌شده‌ها',
                  active: _incomingView == 'registered',
                  onTap: () {
                    setState(() => _incomingView = 'registered');
                    _loadIncomingDabirkhane();
                  },
                ),
                const SizedBox(width: 6),
                _TabChip(
                  label: 'بایگانی‌شده‌ها',
                  active: _incomingView == 'archived',
                  onTap: () {
                    setState(() => _incomingView = 'archived');
                    _loadIncomingDabirkhane();
                  },
                ),
                const Spacer(),
                if (_selectedIncomingIds.isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      for (final id in _selectedIncomingIds.toList()) {
                        try {
                          await _repo.toggleIncomingBayegani(id);
                        } catch (_) {}
                      }
                      _toast('نامه‌های انتخابی بایگانی شدند.');
                      await _loadIncomingDabirkhane();
                    },
                    icon: const Icon(Icons.archive_rounded, size: 16),
                    label: Text(
                      'بایگانی (${Fa.digits(_selectedIncomingIds.length)})',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'جستجو در عنوان، شماره ثبت اندیکاتور، سازمان فرستنده…',
                hintStyle: const TextStyle(fontSize: 11.5),
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                isDense: true,
                filled: true,
                fillColor: const Color(0xfffafbfe),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: Color(0xffdce3ee)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: Color(0xffdce3ee)),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 42),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error != null)
        _ErrorBanner(message: _error!, onRetry: _loadIncomingDabirkhane)
      else if (_incomingItems.isEmpty)
        const _EmptySecretariatBox(
          icon: Icons.move_to_inbox_rounded,
          title: 'نامهٔ وارده‌ای در این بخش یافت نشد',
          subtitle:
              'از دکمهٔ پایین صفحه می‌توانید نامهٔ واردهٔ جدید را با شماره ثبت اندیکاتور در دبیرخانه ثبت کنید.',
        )
      else
        for (final l in _incomingItems)
          _IncomingSecretariatCard(
            item: l,
            archived: _incomingView == 'archived',
            selected: _selectedIncomingIds.contains(l.letterId),
            canEdit: access.canCreateIncomingLetter,
            onToggleSelect: _incomingView == 'registered'
                ? () => setState(() {
                    if (!_selectedIncomingIds.remove(l.letterId)) {
                      _selectedIncomingIds.add(l.letterId);
                    }
                  })
                : null,
            onView: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LetterDetailPage(
                    kind: LetterKind.incoming,
                    letterId: l.letterId,
                    erjaId: l.erjaId,
                  ),
                ),
              );
              await _loadIncomingDabirkhane();
            },
            onGardesh: () => _openGardeshSheet(LetterKind.incoming, l),
            onEdit: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => LetterEditorPage(
                    kind: LetterKind.incoming,
                    editingId: l.letterId,
                  ),
                ),
              );
              if (changed == true) await _loadIncomingDabirkhane();
            },
            onToggleArchive: () async {
              try {
                await _repo.toggleIncomingBayegani(l.letterId);
                _toast(
                  _incomingView == 'archived'
                      ? 'از بایگانی خارج شد.'
                      : 'به بایگانی منتقل شد.',
                );
                await _loadIncomingDabirkhane();
              } catch (e) {
                _toast(e.toString(), error: true);
              }
            },
          ),
    ];
  }
}

// ============================================================
//  ویجت‌های اختصاصی لوکس دبیرخانه یکپارچه
// ============================================================

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.active,
    required this.icon,
    required this.label,
    required this.activeColor,
    required this.onTap,
    this.badge,
  });

  final bool active;
  final IconData icon;
  final String label;
  final String? badge;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: active ? activeColor : Colors.transparent,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: active ? Colors.white : const Color(0xff44547a),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : const Color(0xff2c3a58),
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.22)
                      : activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: active ? Colors.white : activeColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DabirStatTile extends StatelessWidget {
  const _DabirStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : const Color(0xffdce3ee),
            width: selected ? 1.6 : 1,
          ),
          gradient: selected
              ? LinearGradient(
                  colors: [color.withValues(alpha: 0.09), Colors.white],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fa.number(value),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff66779c),
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

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(999),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: active ? const Color(0xff3357b0) : const Color(0xfff0f3fa),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : const Color(0xff44547a),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : const Color(0xff2c3a58),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OutgoingSecretariatCard extends StatelessWidget {
  const _OutgoingSecretariatCard({
    required this.item,
    required this.onView,
    required this.onGardesh,
    required this.onPrint,
    required this.onRegister,
    required this.onArchive,
  });

  final LetterListItem item;
  final VoidCallback onView;
  final VoidCallback onGardesh;
  final VoidCallback onPrint;
  final VoidCallback onRegister;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final registered = item.dabirkhaneSabt;
    final statusColor =
        registered ? const Color(0xff1f6e45) : const Color(0xffb4771e);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffdce3ee)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff1e2a45).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff1f6e45).withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    Fa.digits(item.sadereNumber ?? item.letterNumber),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff14564a),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff1e2a45),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniTag(
                  icon: registered
                      ? Icons.verified_rounded
                      : Icons.schedule_rounded,
                  label: registered ? 'ثبت و ارسال شده' : 'در انتظار ثبت دبیرخانه',
                  color: statusColor,
                ),
                if (item.isConfidential)
                  _MiniTag(
                    icon: Icons.lock_outline_rounded,
                    label: item.mahramanegi,
                    color: OfficeColors.danger,
                  ),
                if (item.isUrgent)
                  _MiniTag(
                    icon: Icons.bolt_rounded,
                    label: item.foriat,
                    color: const Color(0xffea580c),
                  ),
                if (item.isArchived)
                  _MiniTag(
                    icon: Icons.inventory_2_outlined,
                    label: item.archiveFolderTitle == null
                        ? 'بایگانی‌شده'
                        : 'پوشه: ${item.archiveFolderTitle}',
                    color: const Color(0xff46536b),
                  ),
                if (item.hasAttachment)
                  const _MiniTag(
                    icon: Icons.attach_file_rounded,
                    label: 'پیوست‌دار',
                    color: Color(0xff44547a),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if ((item.receiverOrganization ?? '').isNotEmpty)
                  'مقصد: ${item.receiverOrganization!}${(item.receiverName ?? '').isNotEmpty ? ' (${item.receiverName})' : ''}',
                if (item.sender.isNotEmpty) 'ایجادکننده: ${item.sender}',
                if ((item.companyName ?? '').isNotEmpty) 'سربرگ: ${item.companyName}',
                if (item.dateSadere != null) 'صدور: ${jalaliShort(item.dateSadere!)}',
              ].join('  •  '),
              style: const TextStyle(
                fontSize: 11.2,
                color: Color(0xff44547a),
                height: 1.6,
              ),
            ),
            if (registered) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xfff0fdf4),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xffbbf7d0)),
                ),
                child: Text(
                  [
                    if ((item.sendMethod ?? '').isNotEmpty)
                      'روش ارسال: ${item.sendMethod}',
                    if ((item.delivererName ?? '').isNotEmpty)
                      'تحویل‌گیرنده: ${item.delivererName}',
                    if ((item.trackingCode ?? '').isNotEmpty)
                      'رهگیری: ${Fa.digits(item.trackingCode!)}',
                    if ((item.destRegNumber ?? '').isNotEmpty)
                      'شماره ثبت مقصد: ${Fa.digits(item.destRegNumber!)}',
                    if ((item.destEmail ?? '').isNotEmpty)
                      'ایمیل: ${item.destEmail}',
                    if ((item.destFax ?? '').isNotEmpty)
                      'فکس: ${Fa.digits(item.destFax!)}',
                  ].join('  |  '),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff174d29),
                    height: 1.55,
                  ),
                ),
              ),
            ],
            const Divider(height: 18),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: registered
                        ? const Color(0xff14594f)
                        : const Color(0xff3357b0),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                  ),
                  onPressed: onRegister,
                  icon: Icon(
                    registered ? Icons.edit_note_rounded : Icons.send_and_archive_rounded,
                    size: 16,
                  ),
                  label: Text(
                    registered ? 'ویرایش ثبت دبیرخانه' : 'ثبت و ارسال دبیرخانه',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _ActionPillButton(
                  icon: Icons.visibility_outlined,
                  label: 'نمایش',
                  onTap: onView,
                ),
                _ActionPillButton(
                  icon: Icons.account_tree_outlined,
                  label: 'گردش',
                  onTap: onGardesh,
                ),
                _ActionPillButton(
                  icon: Icons.print_outlined,
                  label: 'چاپ رسمی',
                  onTap: onPrint,
                ),
                _ActionPillButton(
                  icon: item.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  label: item.isArchived ? 'خروج از بایگانی' : 'بایگانی',
                  onTap: onArchive,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingSecretariatCard extends StatelessWidget {
  const _IncomingSecretariatCard({
    required this.item,
    required this.archived,
    required this.selected,
    required this.canEdit,
    required this.onView,
    required this.onGardesh,
    required this.onEdit,
    required this.onToggleArchive,
    this.onToggleSelect,
  });

  final LetterListItem item;
  final bool archived;
  final bool selected;
  final bool canEdit;
  final VoidCallback? onToggleSelect;
  final VoidCallback onView;
  final VoidCallback onGardesh;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? const Color(0xff1466a6) : const Color(0xffdce3ee),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onToggleSelect != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onToggleSelect!(),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xff1466a6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  Fa.digits(item.numberSabt ?? item.letterNumber),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff14594f),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if ((item.senderOrganization ?? item.sender).isNotEmpty)
                'فرستنده: ${item.senderOrganization ?? item.sender}',
              if ((item.numberLetterVarede ?? '').isNotEmpty)
                'شماره مبدأ: ${Fa.digits(item.numberLetterVarede!)}',
              if (item.date != null) 'تاریخ: ${jalaliShort(item.date!)}',
            ].join('  •  '),
            style: const TextStyle(fontSize: 11.2, color: Color(0xff44547a)),
          ),
          const Divider(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ActionPillButton(
                icon: Icons.visibility_outlined,
                label: 'نمایش و ارجاع',
                onTap: onView,
              ),
              _ActionPillButton(
                icon: Icons.account_tree_outlined,
                label: 'گردش نامه',
                onTap: onGardesh,
              ),
              if (canEdit)
                _ActionPillButton(
                  icon: Icons.edit_outlined,
                  label: 'ویرایش',
                  onTap: onEdit,
                ),
              _ActionPillButton(
                icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                label: archived ? 'خروج از بایگانی' : 'بایگانی',
                onTap: onToggleArchive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      side: const BorderSide(color: Color(0xffd4dbe8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 15, color: const Color(0xff2c3a58)),
    label: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xff2c3a58),
      ),
    ),
  );
}

class _SelectableOptionTile extends StatelessWidget {
  const _SelectableOptionTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(13),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xff3357b0).withValues(alpha: 0.08)
            : const Color(0xfffafbfe),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected ? const Color(0xff3357b0) : const Color(0xffdce3ee),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: selected ? const Color(0xff3357b0) : const Color(0xff66779c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xff66779c),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? const Color(0xff3357b0) : const Color(0xffb9c3d9),
          ),
        ],
      ),
    ),
  );
}

class _EmptySecretariatBox extends StatelessWidget {
  const _EmptySecretariatBox({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffdce3ee)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 42, color: const Color(0xffb9c3d9)),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xff66779c),
            height: 1.7,
          ),
        ),
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
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xfffef2f2),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xfffecaca)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: OfficeColors.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: Color(0xff991b1b)),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('تلاش مجدد')),
      ],
    ),
  );
}

// ============================================================
//  شیت ثبت و ارسال دبیرخانه (`OutgoingDabirkhane.razor` خطوط ۳۹۰ تا ۵۶۰)
// ============================================================

class _DabirkhaneRegisterSheet extends StatefulWidget {
  const _DabirkhaneRegisterSheet({
    required this.item,
    required this.repo,
    required this.dabirAccounts,
  });

  final LetterListItem item;
  final OfficeAutomationRepository repo;
  final List<EmailAccount> dabirAccounts;

  @override
  State<_DabirkhaneRegisterSheet> createState() =>
      _DabirkhaneRegisterSheetState();
}

class _DabirkhaneRegisterSheetState extends State<_DabirkhaneRegisterSheet> {
  late String _method = widget.item.sendMethod ?? '';
  late final _delivererCtrl = TextEditingController(
    text: widget.item.delivererName ?? '',
  );
  late final _trackingCtrl = TextEditingController(
    text: widget.item.trackingCode ?? '',
  );
  late final _faxCtrl = TextEditingController(text: widget.item.destFax ?? '');
  late final _destRegCtrl = TextEditingController(
    text: widget.item.destRegNumber ?? '',
  );
  late final _destEmailCtrl = TextEditingController(
    text: widget.item.destEmail ?? '',
  );
  final _noteCtrl = TextEditingController();

  bool _alsoSendEmail = false;
  int _emailAccountId = 0;
  bool _busy = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    if (widget.dabirAccounts.isNotEmpty) {
      _emailAccountId = widget.dabirAccounts.first.id;
    }
  }

  @override
  void dispose() {
    _delivererCtrl.dispose();
    _trackingCtrl.dispose();
    _faxCtrl.dispose();
    _destRegCtrl.dispose();
    _destEmailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final spec = LetterSendMethodSpec.of(_method);
    if (_method.trim().isEmpty) {
      setState(() => _validationError = 'روش ارسال نامه را انتخاب کنید.');
      return;
    }
    if (spec.needsDelivererName && _delivererCtrl.text.trim().isEmpty) {
      setState(() => _validationError = 'نام تحویل‌گیرنده الزامی است.');
      return;
    }
    if (spec.needsFax && _faxCtrl.text.trim().isEmpty) {
      setState(() => _validationError = 'شماره فکس مقصد الزامی است.');
      return;
    }
    if (spec.needsDestRegNumber && _destRegCtrl.text.trim().isEmpty) {
      setState(() => _validationError = 'شماره ثبت مقصد برای ECE الزامی است.');
      return;
    }
    final sendEmail = spec.needsDestEmail || _alsoSendEmail;
    if (sendEmail && _destEmailCtrl.text.trim().isEmpty) {
      setState(() => _validationError = 'آدرس ایمیل مقصد را وارد کنید.');
      return;
    }

    setState(() {
      _busy = true;
      _validationError = null;
    });
    try {
      await widget.repo.dabirkhaneRegister(widget.item.letterId, {
        'sendMethod': _method,
        'destRegNumber': _destRegCtrl.text.trim().isEmpty
            ? null
            : _destRegCtrl.text.trim(),
        'delivererName': _delivererCtrl.text.trim().isEmpty
            ? null
            : _delivererCtrl.text.trim(),
        'trackingCode': _trackingCtrl.text.trim().isEmpty
            ? null
            : _trackingCtrl.text.trim(),
        'destFax': _faxCtrl.text.trim().isEmpty ? null : _faxCtrl.text.trim(),
        'sendByEmail': sendEmail,
        'destEmail': _destEmailCtrl.text.trim().isEmpty
            ? null
            : _destEmailCtrl.text.trim(),
        'emailAccountId': _emailAccountId > 0 ? _emailAccountId : null,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _validationError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = LetterSendMethodSpec.of(_method);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.markunread_mailbox_rounded,
                    color: Color(0xff3357b0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ثبت دبیرخانه — ${Fa.digits(widget.item.sadereNumber ?? widget.item.letterNumber)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                '${widget.item.title}${widget.item.receiverOrganization != null ? ' — ${widget.item.receiverOrganization}' : ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xff44547a)),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue:
                    LetterSendMethodSpec.allMethods.contains(_method)
                        ? _method
                        : null,
                decoration: InputDecoration(
                  labelText: 'روش ارسال نامه *',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  for (final m in LetterSendMethodSpec.allMethods)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) => setState(() {
                  _method = v ?? '';
                  _validationError = null;
                }),
              ),
              if (spec.hint.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffe9effa),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    spec.hint,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xff20304f),
                    ),
                  ),
                ),
              ],
              if (spec.needsDelivererName) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _delivererCtrl,
                  decoration: InputDecoration(
                    labelText: 'نام تحویل‌گیرنده / پیک *',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              if (spec.needsTrackingCode) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _trackingCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'کد رهگیری مرسوله پستی (اختیاری)',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              if (spec.needsFax) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _faxCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'شماره فکس مقصد *',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _destRegCtrl,
                decoration: InputDecoration(
                  labelText: spec.needsDestRegNumber
                      ? 'شماره ثبت مقصد (ECE) *'
                      : 'شماره ثبت دبیرخانه مقصد (اختیاری)',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (!spec.needsDestEmail && _method.isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _alsoSendEmail,
                  onChanged: (v) => setState(() => _alsoSendEmail = v ?? false),
                  title: const Text(
                    'ارسال هم‌زمان نسخهٔ PDF با پست الکترونیک رسمی دبیرخانه',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              if (spec.needsDestEmail || _alsoSendEmail) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _destEmailCtrl,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'آدرس ایمیل مقصد *',
                    hintText: 'office@organization.ir',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (widget.dabirAccounts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _emailAccountId,
                    decoration: InputDecoration(
                      labelText: 'حساب ایمیل رسمی دبیرخانه',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      for (final a in widget.dabirAccounts)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            a.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _emailAccountId = v ?? 0),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'توضیحات دبیرخانه (اختیاری)',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _validationError!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OfficeColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff3357b0),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_and_archive_rounded, size: 18),
                label: Text(
                  _busy ? 'در حال ثبت در دبیرخانه…' : 'ثبت قطعی و ارسال دبیرخانه',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  شیت مدیریت رزرو شماره اندیکاتور (`IncomingReservationManager.razor`)
// ============================================================

class _ReservationManagerSheet extends StatefulWidget {
  const _ReservationManagerSheet({required this.repo});
  final OfficeAutomationRepository repo;

  @override
  State<_ReservationManagerSheet> createState() =>
      _ReservationManagerSheetState();
}

class _ReservationManagerSheetState extends State<_ReservationManagerSheet> {
  int _typeForm = 3; // 3=وارده، 2=صادره، 1=داخلی
  int _count = 1;
  bool _loading = true;
  bool _reserving = false;
  List<LetterNumberReservation> _list = const [];
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final r = await widget.repo.listReservations(typeForm: _typeForm);
      if (!mounted) return;
      setState(() {
        _list = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _reserve() async {
    setState(() {
      _reserving = true;
      _err = null;
    });
    try {
      await widget.repo.reserveNumbers(typeForm: _typeForm, count: _count);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _reserving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.tag_rounded, color: Color(0xff3357b0)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'رزرو شماره ثبت اندیکاتور دبیرخانه',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: 3, label: Text('وارده')),
                  ButtonSegment(value: 2, label: Text('صادره')),
                  ButtonSegment(value: 1, label: Text('داخلی')),
                ],
                selected: {_typeForm},
                onSelectionChanged: (s) {
                  setState(() => _typeForm = s.first);
                  _load();
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfffafbfe),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffdce3ee)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'تعداد:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _count > 1
                              ? () => setState(() => _count--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Text(
                          Fa.digits(_count),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _count < 20
                              ? () => setState(() => _count++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff3357b0),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _reserving ? null : _reserve,
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: Text(_reserving ? 'در حال رزرو…' : 'رزرو شماره'),
                    ),
                  ],
                ),
              ),
              if (_err != null) ...[
                const SizedBox(height: 8),
                Text(
                  _err!,
                  style: const TextStyle(fontSize: 11.5, color: OfficeColors.danger),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'شماره‌های رزروشدهٔ فعلی:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'هنوز شماره‌ای برای این بخش رزرو نشده است.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xff66779c)),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = _list[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.pin_rounded,
                          color: Color(0xff3357b0),
                        ),
                        title: Text(
                          Fa.digits(r.numberSabt),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (r.userName.isNotEmpty) r.userName,
                            if (r.dateReservation != null)
                              jalaliShort(r.dateReservation!),
                          ].join(' • '),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: r.isUsed
                                ? const Color(0xfff0f3fa)
                                : const Color(0xffdcfce7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            r.isUsed ? 'استفاده شده' : 'آماده استفاده',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: r.isUsed
                                  ? const Color(0xff66779c)
                                  : const Color(0xff1f5c33),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  شیت نمایش درخت گردش نامه (`GardeshModal.razor`)
// ============================================================

class _GardeshTreeSheet extends StatefulWidget {
  const _GardeshTreeSheet({
    required this.repo,
    required this.kind,
    required this.letterId,
    required this.title,
  });

  final OfficeAutomationRepository repo;
  final LetterKind kind;
  final int letterId;
  final String title;

  @override
  State<_GardeshTreeSheet> createState() => _GardeshTreeSheetState();
}

class _GardeshTreeSheetState extends State<_GardeshTreeSheet> {
  bool _loading = true;
  List<GardeshNode> _nodes = const [];

  @override
  void initState() {
    super.initState();
    widget.repo
        .gardesh(widget.kind, widget.letterId)
        .then((v) {
          if (mounted) {
            setState(() {
              _nodes = v;
              _loading = false;
            });
          }
        })
        .catchError((_) {
          if (mounted) setState(() => _loading = false);
        });
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_rounded, color: Color(0xff3357b0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'گردش نامه — ${widget.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_nodes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'هنوز ارجاعی برای این نامه ثبت نشده است.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xff66779c)),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final n in _nodes) _buildNode(n, 0),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _buildNode(GardeshNode n, int depth) => Padding(
    padding: EdgeInsetsDirectional.only(start: depth * 14.0, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xfffafbfe),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffdce3ee)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${n.sender}  ←  ${n.receiver}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    n.isRead ? 'مشاهده‌شده ✓' : 'خوانده‌نشده',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: n.isRead
                          ? const Color(0xff1f6e45)
                          : const Color(0xffb4771e),
                    ),
                  ),
                ],
              ),
              if ((n.amalgarTitle ?? '').isNotEmpty || n.matnErja.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    [
                      if ((n.amalgarTitle ?? '').isNotEmpty) n.amalgarTitle!,
                      if (n.matnErja.isNotEmpty) n.matnErja,
                    ].join(': '),
                    style: const TextStyle(
                      fontSize: 11.2,
                      color: Color(0xff44547a),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final c in n.children) _buildNode(c, depth + 1),
      ],
    ),
  );
}
