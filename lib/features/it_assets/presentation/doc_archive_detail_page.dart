// ============================================================
//  «صفحهٔ مدرک» — فاز ۹-ح (بخش ۱)
//  آینهٔ `Pages/DocArchive/DocumentView.razor` (مسیر وب: /doc-archive/documents/{id})
//
//  • سرصفحهٔ «کد — عنوان» با نشان‌های «نمایش برای همه» / «محرمانه» /
//    «واترمارک» / «غیرفعال»
//  • اطلاعات: پوشه، شماره مدرک مشتری، تاریخ انقضا (+ «N روز گذشته»)،
//    سیاست ورژن، دسترسی شما، تگ‌ها، توضیحات
//  • «نام مدرک غیرفعال است و فقط‌خواندنی می‌باشد.» با دلیل و تاریخ
//  • سطح «مشاهده» ⇒ «دسترسی شما روی این مدرک در سطح «مشاهده» است؛ …»
//  • ورژن‌ها: «ورژن N» + «فعال» / «فریز — در گردش» / وضعیت + گردش تأییدکنندگان
//  • تاریخچه رویدادها با فیلتر نوع رویداد + مدارک مرتبط
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'doc_archive_form_page.dart';
import 'doc_permission_sheet.dart';
import 'doc_version_sheet.dart';
import 'doc_archive_page.dart' show colorFromHex, docLevelColor, docVersionColor;
import 'system_style.dart';

class DocArchiveDetailPage extends StatefulWidget {
  const DocArchiveDetailPage({super.key, required this.id});

  final int id;

  @override
  State<DocArchiveDetailPage> createState() => _DocArchiveDetailPageState();
}

class _DocArchiveDetailPageState extends State<DocArchiveDetailPage> {
  late final DocArchiveRepository _repo;

  bool _loading = true;
  String? _error;
  DocRow? _doc;
  List<DocVersionRow> _versions = const [];
  List<DocLogRow> _logs = const [];
  List<DocLinkRow> _links = const [];
  String? _logFilter;

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _repo.documentRaw(widget.id);
      if (!mounted) return;
      setState(() {
        _doc = DocRow.fromJson(raw);
        _versions = DocVersionRow.listFrom(raw['versions']);
        _logs = DocLogRow.listFrom(raw['logs']);
        _links = DocLinkRow.listFrom(raw['links']);
        _loading = false;
      });
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

  List<DocLogRow> get _filteredLogs => _logFilter == null
      ? _logs
      : _logs.where((l) => l.action == _logFilter).toList();

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          doc == null ? 'مدرک' : doc.code,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (doc != null && doc.isActive && doc.myLevel >= DocLevel.write)
            IconButton(
              tooltip: 'ثبت ورژن جدید',
              icon: const Icon(Icons.layers_rounded, size: 19),
              onPressed: _newVersion,
            ),
          if (doc != null && doc.myLevel >= DocLevel.read)
            IconButton(
              tooltip: 'مقایسه دو ورژن',
              icon: const Icon(Icons.compare_arrows_rounded, size: 20),
              onPressed: _compare,
            ),
          if (doc != null && doc.myLevel >= DocLevel.write)
            IconButton(
              tooltip: 'ویرایش مدرک',
              icon: const Icon(Icons.edit_rounded, size: 19),
              onPressed: _edit,
            ),
          if (doc != null && doc.myLevel >= DocLevel.full) ...[
            IconButton(
              tooltip: 'دسترسی اختصاصی',
              icon: const Icon(Icons.people_alt_rounded, size: 19),
              onPressed: _editPermissions,
            ),
            IconButton(
              tooltip: doc.isActive ? 'غیرفعال کردن مدرک' : 'فعال کردن مدرک',
              icon: Icon(
                doc.isActive
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                size: 22,
                color: doc.isActive ? ShopColors.ok : ShopColors.inkFaint,
              ),
              onPressed: _toggleActive,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              padding: const EdgeInsets.all(14),
              children: [
                SystemNote(
                  text: 'بارگذاری مدرک ناموفق بود — $_error',
                  color: ShopColors.danger,
                  icon: Icons.error_outline_rounded,
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _load,
                  child: const Text(
                    'تلاش دوباره',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 26),
              children: [
                _headerCard(doc!),
                const SizedBox(height: 8),
                _infoCard(doc),
                if (!doc.isActive) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: ShopColors.inkFaint.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 15,
                              color: ShopColors.inkSoft,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'این مدرک غیرفعال است و فقط‌خواندنی می‌باشد.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((doc.deactivateReason ?? '').isNotEmpty)
                          Text(
                            'دلیل: ${doc.deactivateReason}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: ShopColors.inkSoft,
                            ),
                          ),
                        if (doc.deactivatedAt != null)
                          Text(
                            'توسط ${doc.deactivatedByName ?? ''} در ${Fa.date(doc.deactivatedAt!.toIso8601String())}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (doc.myLevel == DocLevel.view) ...[
                  const SizedBox(height: 8),
                  const SystemNote(
                    text:
                        'دسترسی شما روی این مدرک در سطح «مشاهده» است؛ محتوا، ورژن‌ها و پیوست‌ها نمایش داده نمی‌شود.',
                    color: ShopColors.warn,
                    icon: Icons.visibility_rounded,
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  _versionsCard(),
                  const SizedBox(height: 8),
                  _logsCard(),
                  if (_links.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _linksCard(),
                  ],
                ],
              ],
            ),
    );
  }

  Future<void> _edit() async {
    final doc = _doc!;
    final lookups = await _repo.lookups();
    final folders = (await _repo.folders(take: 500)).items;
    final tags = await _repo.tags();
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DocArchiveFormPage(
          folders: folders,
          tags: tags,
          numberingEnabled: lookups.codeNumberingEnabled,
          existing: doc,
          existingTagIds: doc.tags.map((t) => t.id).toList(),
          existingLinkIds: _links.map((l) => l.linkedDocumentId).toList(),
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Widget _headerCard(DocRow d) => Container(
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xff4f7ce8), Color(0xff2547a8)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.all(Radius.circular(15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.description_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                d.title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            _whiteTag(d.code),
            if (d.isPublic) _whiteTag('نمایش برای همه'),
            if (d.requireDownloadConfirm) _whiteTag('محرمانه'),
            if (d.watermarkPreview) _whiteTag('واترمارک'),
            if (!d.isActive) _whiteTag('غیرفعال'),
            if (d.isDeleted) _whiteTag('در سطل بازیافت'),
          ],
        ),
      ],
    ),
  );

  Widget _whiteTag(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
  );

  Widget _infoCard(DocRow d) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(label: 'پوشه', value: d.folderCell),
        InfoRow(label: 'شماره مدرک مشتری', value: d.customerCodeCell, ltr: true),
        InfoRow(
          label: 'تاریخ انقضا',
          value: d.expireDate == null
              ? '—'
              : Fa.date(d.expireDate!.toIso8601String(), time: false),
          valueColor: d.isExpired ? ShopColors.danger : null,
        ),
        if (d.isExpired)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ShopTag(
              text: '${Fa.digits((d.daysToExpire ?? 0).abs())} روز است منقضی شده',
              color: ShopColors.danger,
            ),
          )
        else if (d.daysToExpire != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ShopTag(
              text: d.expiryText,
              color: d.isExpiringSoon ? ShopColors.warn : ShopColors.inkFaint,
              icon: Icons.event_rounded,
            ),
          ),
        InfoRow(
          label: 'سیاست ورژن',
          value: d.allowMultipleActiveVersions
              ? 'چند ورژن فعال هم‌زمان'
              : 'فقط یک ورژن فعال',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const SizedBox(
                width: 96,
                child: Text(
                  'دسترسی شما',
                  style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
                ),
              ),
              ShopTag(text: d.levelName, color: docLevelColor(d.myLevel)),
            ],
          ),
        ),
        if (d.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final t in d.tags)
                  ShopTag(text: t.name, color: colorFromHex(t.color)),
              ],
            ),
          ),
        InfoRow(label: 'ثبت‌کننده', value: d.createdByName),
        InfoRow(
          label: 'تاریخ ثبت',
          value: Fa.date(d.createdAt?.toIso8601String()),
        ),
        if ((d.contentSnippet ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            d.contentSnippet!,
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.8,
              color: ShopColors.inkSoft,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _versionsCard() => Container(
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              const Icon(
                Icons.layers_rounded,
                size: 15,
                color: ShopColors.seed,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'ورژن‌ها',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ShopTag(text: Fa.digits(_versions.length), color: ShopColors.seed),
            ],
          ),
        ),
        if (_versions.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 14),
            child: Text(
              'ورژنی ثبت نشده است',
              style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(
              children: [
                for (final v in _versions) _versionRow(v),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _versionRow(DocVersionRow v) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: v.isActive
          ? const Color(0xfff3fdf6)
          : const Color(0xfff9fbfe),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(
        color: v.isActive
            ? ShopColors.ok.withValues(alpha: 0.35)
            : ShopColors.line,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 5,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ShopTag(
              text: 'ورژن ${Fa.digits(v.versionNo)}',
              color: ShopColors.seed,
            ),
            if (v.isActive)
              const ShopTag(text: 'فعال', color: ShopColors.ok),
            if (v.isFrozen)
              const ShopTag(text: 'فریز — در گردش', color: ShopColors.warn),
            ShopTag(
              text: DocVersionStatus.nameView(v.status),
              color: docVersionColor(v.status),
            ),
            if (v.isMyTurn)
              const ShopTag(text: 'نوبت شما', color: ShopColors.danger),
          ],
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            if (v.isMyTurn && _doc != null && _doc!.myLevel >= DocLevel.write) ...[
              _miniBtn(
                'تایید',
                Icons.check_circle_outline_rounded,
                ShopColors.ok,
                () => _approve(v, true),
              ),
              _miniBtn(
                'رد',
                Icons.cancel_outlined,
                ShopColors.danger,
                () => _approve(v, false),
              ),
            ],
            if (!v.isActive && _doc != null && _doc!.myLevel >= DocLevel.full)
              _miniBtn(
                'فعال‌سازی این ورژن',
                Icons.play_circle_outline_rounded,
                ShopColors.seed,
                () => _setActive(v),
              ),
            if (_doc != null && _doc!.myLevel >= DocLevel.read)
              _miniBtn(
                'پیوست‌ها',
                Icons.attach_file_rounded,
                ShopColors.inkSoft,
                () => _attachments(v),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${v.createdByName} — ${Fa.date(v.createdAt?.toIso8601String())}',
          style: const TextStyle(fontSize: 9, color: ShopColors.inkFaint),
        ),
        if ((v.changeNote ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'شرح تغییرات: ',
                    style: TextStyle(color: ShopColors.inkFaint),
                  ),
                  TextSpan(text: v.changeNote),
                ],
              ),
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.7,
                color: ShopColors.inkSoft,
              ),
            ),
          ),
        if (v.expireDate != null)
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'انقضای ورژن: ',
                  style: TextStyle(color: ShopColors.inkFaint),
                ),
                TextSpan(
                  text: Fa.date(v.expireDate!.toIso8601String(), time: false),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.7,
              color: ShopColors.inkSoft,
            ),
          ),
        if (v.approvers.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'گردش:',
                style: TextStyle(fontSize: 9, color: ShopColors.inkFaint),
              ),
              for (final a in v.approvers)
                ShopTag(
                  text: '${a.userName} ${switch (a.status) {
                    1 => '✔',
                    2 => '✘',
                    _ => '…',
                  }}',
                  color: switch (a.status) {
                    1 => ShopColors.ok,
                    2 => ShopColors.danger,
                    _ => ShopColors.inkFaint,
                  },
                ),
            ],
          ),
        ],
      ],
    ),
  );

  /// دکمهٔ کوچک اقدام داخل کارت ورژن
  Widget _miniBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => TextButton.icon(
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 26),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      foregroundColor: color,
      visualDensity: VisualDensity.compact,
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 13),
    label: Text(
      label,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );

  Future<void> _approve(DocVersionRow v, bool approve) async {
    final msg = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => DocApprovalSheet(version: v, approve: approve),
    );
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    }
  }

  Future<void> _setActive(DocVersionRow v) async {
    try {
      await _repo.setVersionActive(v.id, true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ورژن فعال شد.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e
                .toString()
                .replaceFirst('ApiException: ', '')
                .replaceFirst('Exception: ', '')
                .trim(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _attachments(DocVersionRow v) async {
    final doc = _doc!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(c).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(c).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'پیوست‌های ورژن ${Fa.digits(v.versionNo)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => Navigator.of(c).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  child: DocAttachmentsBlock(
                    versionId: v.id,
                    canUpload:
                        doc.myLevel >= DocLevel.write && !v.isFrozen,
                    canDeleteAny: doc.myLevel >= DocLevel.full,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _newVersion() async {
    final doc = _doc!;
    final lookups = await _repo.lookups();
    if (!mounted) return;
    final msg = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => DocNewVersionSheet(
        documentId: doc.id,
        documentTitle: '${doc.code} — ${doc.title}',
        users: lookups.users,
      ),
    );
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    }
  }

  void _compare() {
    final doc = _doc!;
    if (_versions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برای مقایسه حداقل دو ورژن لازم است.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocComparePage(
          documentId: doc.id,
          versions: _versions,
        ),
      ),
    );
  }

  Widget _logsCard() => Container(
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        leading: const Icon(
          Icons.history_rounded,
          size: 16,
          color: ShopColors.seed,
        ),
        title: Text(
          'تاریخچه رویدادها (${Fa.digits(_logs.length)})',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
        ),
        children: [
          if (_logs.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _logFilter,
              isDense: true,
              style: const TextStyle(fontSize: 10.5, color: ShopColors.ink),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: const Color(0xfff9fbfe),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: ShopColors.line),
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    'همه رویدادها (${Fa.digits(_logs.length)})',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                for (final g in _logCounts.entries)
                  DropdownMenuItem(
                    value: g.key,
                    child: Text(
                      '${DocLogRow.actionName(g.key)} (${Fa.digits(g.value)})',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _logFilter = v),
            ),
          const SizedBox(height: 6),
          if (_filteredLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'رویدادی ثبت نشده است.',
                style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
              ),
            )
          else
            for (final l in _filteredLogs)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShopTag(
                      text: DocLogRow.actionName(l.action),
                      color: ShopColors.seed,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((l.detail ?? '').isNotEmpty)
                            Text(
                              l.detail!,
                              style: const TextStyle(
                                fontSize: 9.5,
                                height: 1.7,
                              ),
                            ),
                          Text(
                            '${l.userName} · ${Fa.date(l.createdAt?.toIso8601String())}',
                            style: const TextStyle(
                              fontSize: 8.5,
                              color: ShopColors.inkFaint,
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
  );

  Map<String, int> get _logCounts {
    final m = <String, int>{};
    for (final l in _logs) {
      m[l.action] = (m[l.action] ?? 0) + 1;
    }
    return Map.fromEntries(
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  Widget _linksCard() => Container(
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        leading: const Icon(
          Icons.link_rounded,
          size: 16,
          color: ShopColors.seed,
        ),
        title: Text(
          'مدارک مرتبط (${Fa.digits(_links.length)})',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
        ),
        children: [
          for (final l in _links)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 5,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${l.code} — ${l.title}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (l.activeVersionNo > 0)
                    ShopTag(
                      text: 'v${Fa.digits(l.activeVersionNo)}',
                      color: ShopColors.ok,
                    ),
                  if (!l.isActive)
                    const ShopTag(
                      text: 'غیرفعال',
                      color: ShopColors.inkFaint,
                    ),
                  if ((l.customerCode ?? '').isNotEmpty)
                    Text(
                      '(مشتری: ${l.customerCode})',
                      style: const TextStyle(
                        fontSize: 9,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  // ---------- فاز ۹-ط: فعال/غیرفعال و دسترسی اختصاصی ----------

  /// همان متن‌های مودال وب (`DocumentView.razor`)
  Future<void> _toggleActive() async {
    final doc = _doc!;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          doc.isActive ? 'غیرفعال کردن مدرک' : 'فعال کردن مدرک',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (doc.isActive) ...[
              const Text(
                'با غیرفعال کردن، این مدرک فقط‌خواندنی می‌شود و به زیرمنوی «مدارک غیرفعال» منتقل می‌گردد. کارهای باز آن در کارتابل‌ها بسته می‌شوند.',
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.9,
                  color: ShopColors.warn,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'دلیل غیرفعال‌سازی',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: reason,
                maxLines: 2,
                style: const TextStyle(fontSize: 11),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText:
                      'مثلاً: منسوخ شده و با مدرک جدید جایگزین گردید',
                  hintStyle: TextStyle(fontSize: 9.5),
                  border: OutlineInputBorder(),
                ),
              ),
            ] else
              const Text(
                'مدرک دوباره فعال شده و همه عملیات روی آن مجاز می‌شود.',
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.9,
                  color: ShopColors.seed,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('انصراف', style: TextStyle(fontSize: 11)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: doc.isActive
                  ? ShopColors.danger
                  : ShopColors.ok,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('تایید', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.setDocumentActive(
        id: doc.id,
        isActive: !doc.isActive,
        reason: reason.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            doc.isActive ? 'مدرک غیرفعال شد.' : 'مدرک فعال شد.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e
                .toString()
                .replaceFirst('ApiException: ', '')
                .replaceFirst('Exception: ', '')
                .trim(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editPermissions() async {
    final doc = _doc!;
    final lookups = await _repo.lookups();
    final perms = await _repo.documentPermissionsRaw(doc.id);
    if (!mounted) return;
    final result = await showModalBottomSheet<DocPermResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) => DocPermissionSheet(
        users: lookups.users,
        roles: lookups.roles,
        initialItems: perms,
        isPublic: doc.isPublic,
        requireDownloadConfirm: doc.requireDownloadConfirm,
        watermarkPreview: doc.watermarkPreview,
      ),
    );
    if (result == null) return;
    try {
      await _repo.saveDocumentPermissions(
        doc.id,
        isPublic: result.isPublic,
        publicCanDownload: result.publicCanDownload,
        requireDownloadConfirm: result.requireDownloadConfirm,
        watermarkPreview: result.watermarkPreview,
        items: result.items,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('دسترسی‌ها ذخیره شد.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e
                .toString()
                .replaceFirst('ApiException: ', '')
                .replaceFirst('Exception: ', '')
                .trim(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

}

// ============================================================
//  مدل‌های کمکی صفحهٔ جزئیات
// ============================================================

class DocVersionRow {
  const DocVersionRow({
    this.id = 0,
    this.versionNo = 0,
    this.title,
    this.changeNote,
    this.expireDate,
    this.status = 0,
    this.isActive = false,
    this.isFrozen = false,
    this.createdByName = '',
    this.createdAt,
    this.attachmentCount = 0,
    this.isMyTurn = false,
    this.approvers = const [],
  });

  final int id;
  final int versionNo;
  final String? title;
  final String? changeNote;
  final DateTime? expireDate;
  final int status;
  final bool isActive;
  final bool isFrozen;
  final String createdByName;
  final DateTime? createdAt;
  final int attachmentCount;
  final bool isMyTurn;
  final List<DocApproverRow> approvers;

  static List<DocVersionRow> listFrom(Object? v) {
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) {
      final j = Map<String, dynamic>.from(e);
      return DocVersionRow(
        id: (j['id'] as num?)?.toInt() ?? 0,
        versionNo: (j['versionNo'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString(),
        changeNote: j['changeNote']?.toString(),
        expireDate: Fa.parseServerDate(j['expireDate']),
        status: (j['status'] as num?)?.toInt() ?? 0,
        isActive: j['isActive'] == true,
        isFrozen: j['isFrozen'] == true,
        createdByName: j['createdByName']?.toString() ?? '',
        createdAt: Fa.parseServerDate(j['createdAt']),
        attachmentCount: (j['attachmentCount'] as num?)?.toInt() ?? 0,
        isMyTurn: j['isMyTurn'] == true,
        approvers: DocApproverRow.listFrom(j['approvers']),
      );
    }).toList();
  }
}

class DocApproverRow {
  const DocApproverRow({
    this.userId = 0,
    this.userName = '',
    this.order = 0,
    this.status = 0,
    this.comment,
  });
  final int userId;
  final String userName;
  final int order;
  final int status;
  final String? comment;

  static List<DocApproverRow> listFrom(Object? v) {
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) {
      final j = Map<String, dynamic>.from(e);
      return DocApproverRow(
        userId: (j['userId'] as num?)?.toInt() ?? 0,
        userName: j['userName']?.toString() ?? '',
        order: (j['order'] as num?)?.toInt() ?? 0,
        status: (j['status'] as num?)?.toInt() ?? 0,
        comment: j['comment']?.toString(),
      );
    }).toList();
  }
}

class DocLinkRow {
  const DocLinkRow({
    this.id = 0,
    this.linkedDocumentId = 0,
    this.code = '',
    this.customerCode,
    this.title = '',
    this.note,
    this.isActive = true,
    this.activeVersionNo = 0,
  });
  final int id;
  final int linkedDocumentId;
  final String code;
  final String? customerCode;
  final String title;
  final String? note;
  final bool isActive;
  final int activeVersionNo;

  static List<DocLinkRow> listFrom(Object? v) {
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) {
      final j = Map<String, dynamic>.from(e);
      return DocLinkRow(
        id: (j['id'] as num?)?.toInt() ?? 0,
        linkedDocumentId: (j['linkedDocumentId'] as num?)?.toInt() ?? 0,
        code: j['code']?.toString() ?? '',
        customerCode: j['customerCode']?.toString(),
        title: j['title']?.toString() ?? '',
        note: j['note']?.toString(),
        isActive: j['isActive'] != false,
        activeVersionNo: (j['activeVersionNo'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }
}
