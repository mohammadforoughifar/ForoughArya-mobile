// ============================================================
//  «مدرک جدید / ویرایش مدرک» — فاز ۹-ح (بخش ۱)
//  آینهٔ `Pages/DocArchive/DocumentFormModal.razor`
//
//  بخش ۱ — مشخصات مدرک: عنوان* («مثلاً: قرارداد همکاری ۱۴۰۴»)، پوشه*،
//    کد مدرک* (با شماره‌گذار خودکار «خودکار»)، شماره مدرک مشتری،
//    تاریخ انقضا (----/--/--)، توضیحات
//  بخش ۲ — نسخه و امنیت: «فقط یک نسخه فعال» / «چند نسخه هم‌زمان فعال»،
//    «فعال‌سازی نسخه اول (بدون تأییدکننده)»، «نمایش برای همه کاربران»،
//    «دانلود برای همه کاربران»، «تأیید رمز برای مشاهده و دانلود»،
//    «واترمارک نام کاربر و زمان مشاهده»
//  بخش ۳ — برچسب‌ها و ارتباطات: انتخاب برچسب، تأییدکنندگان (با ترتیب)،
//    مدارک مرتبط
//  دکمه‌ها: «انصراف» / «ذخیره» — با همان سه پیام اعتبارسنجی وب
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'doc_archive_detail_page.dart' show DocLinkRow;
import 'doc_archive_page.dart' show colorFromHex;
import 'system_style.dart';

class DocArchiveFormPage extends StatefulWidget {
  const DocArchiveFormPage({
    super.key,
    required this.folders,
    required this.tags,
    this.numberingEnabled = false,
    this.defaultFolderId,
    this.existing,
    this.existingTagIds = const [],
    this.existingLinkIds = const [],
    this.existingApproverIds = const [],
    this.initialLinks = const [],
    this.initialUsers = const [],
  });

  final List<DocFolder> folders;
  final List<DocTag> tags;
  final bool numberingEnabled;
  final int? defaultFolderId;
  final DocRow? existing;
  final List<int> existingTagIds;
  final List<int> existingLinkIds;
  final List<int> existingApproverIds;
  final List<DocLinkRow> initialLinks;
  final List<DocLookup> initialUsers;

  /// سازندهٔ میان‌بر برای «فرم خالی»
  static Widget empty({
    required List<DocFolder> folders,
    required List<DocTag> tags,
    bool numberingEnabled = false,
    int? folderId,
  }) => DocArchiveFormPage(
    folders: folders,
    tags: tags,
    numberingEnabled: numberingEnabled,
    defaultFolderId: folderId,
  );

  @override
  State<DocArchiveFormPage> createState() => _DocArchiveFormPageState();
}

class _DocArchiveFormPageState extends State<DocArchiveFormPage> {
  late final DocArchiveRepository _repo;

  final _title = TextEditingController();
  final _code = TextEditingController();
  final _customerCode = TextEditingController();
  final _description = TextEditingController();

  int _folderId = 0;
  DateTime? _expireDate;
  bool _multiActive = false;
  bool _firstVersionActive = false;
  bool _isPublic = false;
  bool _publicCanDownload = false;
  bool _requireConfirm = false;
  bool _watermark = false;

  late final Set<int> _tagIds = {...widget.existingTagIds};
  late List<int> _linkIds = [...widget.existingLinkIds];
  late List<int> _approverIds = [...widget.existingApproverIds];

  List<DocLookup> _users = const [];
  List<DocLookup> _documents = const [];
  bool _lookupsLoading = true;

  bool _saving = false;
  String? _formError;
  bool _codeExists = false;

  bool get _isEdit => (widget.existing?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _code.text = e.code;
      _customerCode.text = e.customerCode ?? '';
      _description.text = '';
      _folderId = e.folderId;
      _expireDate = e.expireDate;
      _multiActive = e.allowMultipleActiveVersions;
      _isPublic = e.isPublic;
      _publicCanDownload = false;
      _requireConfirm = e.requireDownloadConfirm;
      _watermark = e.watermarkPreview;
    }
    if (_folderId == 0) _folderId = widget.defaultFolderId ?? 0;
    _users = widget.initialUsers;
    _loadLookups();
  }

  @override
  void dispose() {
    _title.dispose();
    _code.dispose();
    _customerCode.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final l = await _repo.lookups();
      if (!mounted) return;
      setState(() {
        _users = l.users;
        _documents = l.documents;
        _lookupsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _lookupsLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _formError = null);

    // همان ترتیب و همان پیام‌های وب
    final err = validateDocForm(
      title: _title.text,
      code: _code.text,
      numberingEnabled: widget.numberingEnabled,
      isNew: !_isEdit,
      folderId: _folderId,
    );
    if (err != null) {
      setState(() {
        _formError = err;
        _codeExists = err == 'کد مدرک اجباری است.';
      });
      return;
    }

    setState(() => _saving = true);
    final input = DocSaveInput(
      id: widget.existing?.id ?? 0,
      folderId: _folderId,
      title: _title.text,
      code: _code.text,
      customerCode: _customerCode.text,
      description: _description.text,
      expireDate: _expireDate,
      allowMultipleActiveVersions: _multiActive,
      firstVersionActive: _firstVersionActive,
      isPublic: _isPublic,
      publicCanDownload: _publicCanDownload,
      requireDownloadConfirm: _requireConfirm,
      watermarkPreview: _watermark,
      tagIds: _tagIds.toList(),
      approvers: _approverIds,
      linkedDocumentIds: _linkIds,
    );

    try {
      if (_isEdit) {
        await _repo.updateDocument(input);
      } else {
        await _repo.createDocument(input);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = e
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
        title: Text(
          _isEdit ? 'ویرایش مدرک' : 'مدرک جدید',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'ذخیره',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 26),
        children: [
          if (_formError != null) ...[
            SystemNote(
              text: _formError!,
              color: ShopColors.danger,
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 8),
          ],
          _section(
            title: 'مشخصات مدرک',
            icon: Icons.file_present_rounded,
            children: [
              ShopField(
                label: 'عنوان مدرک',
                required: true,
                child: TextField(
                  controller: _title,
                  style: const TextStyle(fontSize: 11.5),
                  decoration: _dec('مثلاً: قرارداد همکاری ۱۴۰۴'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (!_isEdit && widget.numberingEnabled)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'با شماره‌گذار خودکار، خالی گذاشتن کد مجاز است و کد خودکار تخصیص می‌یابد.',
                    style: TextStyle(
                      fontSize: 9,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                ),
              ShopField(
                label: 'پوشه',
                required: true,
                child: DropdownButtonFormField<int>(
                  initialValue: _folderId == 0 ? null : _folderId,
                  isDense: true,
                  style: const TextStyle(fontSize: 11, color: ShopColors.ink),
                  decoration: _dec('انتخاب پوشه…'),
                  items: [
                    for (final f in widget.folders)
                      DropdownMenuItem(
                        value: f.id,
                        child: Text(
                          f.titleWithLevel,
                          style: const TextStyle(fontSize: 10.5),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _folderId = v ?? 0),
                ),
              ),
              ShopField(
                label: 'کد مدرک',
                required: !(!_isEdit && widget.numberingEnabled),
                child: TextField(
                  controller: _code,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 11.5),
                  decoration: _dec(
                    (!_isEdit && widget.numberingEnabled) ? 'خودکار' : '',
                  ),
                  onSubmitted: (v) async {
                    if (v.trim().isEmpty) return;
                    try {
                      final taken = await _repo.codeExists(v);
                      if (mounted) setState(() => _codeExists = taken);
                    } catch (_) {}
                  },
                ),
              ),
              if (_codeExists)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'این کد قبلاً ثبت شده است.',
                    style: TextStyle(fontSize: 9.5, color: ShopColors.danger),
                  ),
                ),
              ShopField(
                label: 'شماره مدرک مشتری',
                child: TextField(
                  controller: _customerCode,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 11.5),
                  decoration: _dec(''),
                ),
              ),
              ShopField(
                label: 'تاریخ انقضا',
                child: _dateButton(
                  _expireDate,
                  (d) => setState(() => _expireDate = d),
                  placeholder: '----/--/--',
                  allowClear: true,
                ),
              ),
              ShopField(
                label: 'توضیحات',
                child: TextField(
                  controller: _description,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 11.5),
                  decoration: _dec(''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _section(
            title: 'نسخه و امنیت',
            icon: Icons.shield_rounded,
            children: [
              const Text(
                'نسخه‌های فعال',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              ShopSegmented(
                labels: const [
                  'فقط یک نسخه فعال',
                  'چند نسخه هم‌زمان فعال',
                ],
                index: _multiActive ? 1 : 0,
                onChanged: (i) => setState(() => _multiActive = i == 1),
              ),
              if (!_isEdit)
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _firstVersionActive,
                  onChanged: (v) => setState(() => _firstVersionActive = v),
                  title: const Text(
                    'فعال‌سازی نسخه اول (بدون تأییدکننده)',
                    style: TextStyle(fontSize: 10.5),
                  ),
                ),
              const Divider(height: 18),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _isPublic,
                onChanged: (v) => setState(() {
                  _isPublic = v;
                  if (!v) _publicCanDownload = false;
                }),
                title: const Text(
                  'نمایش برای همه کاربران',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _publicCanDownload,
                onChanged: _isPublic
                    ? (v) => setState(() => _publicCanDownload = v)
                    : null,
                title: const Text(
                  'دانلود برای همه کاربران',
                  style: TextStyle(fontSize: 10.5),
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _requireConfirm,
                onChanged: (v) => setState(() => _requireConfirm = v),
                title: const Text(
                  'تأیید رمز برای مشاهده و دانلود',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.danger,
                  ),
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _watermark,
                onChanged: (v) => setState(() => _watermark = v),
                title: const Text(
                  'واترمارک نام کاربر و زمان مشاهده',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _section(
            title: 'برچسب‌ها و ارتباطات',
            icon: Icons.local_offer_rounded,
            children: [
              const Text(
                'برچسب‌ها',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              if (widget.tags.isEmpty)
                const Text(
                  'بدون برچسب',
                  style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in widget.tags)
                      InkWell(
                        onTap: () => setState(() {
                          if (!_tagIds.remove(t.id)) _tagIds.add(t.id);
                        }),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _tagIds.contains(t.id)
                                ? colorFromHex(t.color)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colorFromHex(t.color)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _tagIds.contains(t.id)
                                    ? Icons.check_circle_rounded
                                    : Icons.local_offer_rounded,
                                size: 12,
                                color: _tagIds.contains(t.id)
                                    ? Colors.white
                                    : colorFromHex(t.color),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                t.name,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: _tagIds.contains(t.id)
                                      ? Colors.white
                                      : ShopColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              _pickerTile(
                label: 'تأییدکنندگان',
                icon: Icons.alt_route_rounded,
                emptyText: 'بدون تأییدکننده؛ تأیید مستقیم',
                selected: [
                  for (final id in _approverIds)
                    _users.firstWhere(
                      (u) => u.id == id,
                      orElse: () => DocLookup(id: id, name: '#$id'),
                    ).name,
                ],
                onTap: () => _pickMulti(
                  title: 'تأییدکنندگان',
                  items: _users,
                  selected: _approverIds,
                  onDone: (ids) => setState(() => _approverIds = ids),
                  keepOrder: true,
                ),
              ),
              _pickerTile(
                label: 'مدارک مرتبط',
                icon: Icons.link_rounded,
                emptyText: 'انتخاب نشده',
                selected: [
                  for (final id in _linkIds)
                    _documents.firstWhere(
                      (u) => u.id == id,
                      orElse: () => DocLookup(id: id, name: '#$id'),
                    ).name,
                ],
                onTap: () => _pickMulti(
                  title: 'مدارک مرتبط',
                  items: _documents,
                  selected: _linkIds,
                  onDone: (ids) => setState(() => _linkIds = ids),
                ),
              ),
              if (_lookupsLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'در حال بارگذاری کاربران و مدارک…',
                    style: TextStyle(fontSize: 9, color: ShopColors.inkFaint),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                  child: const Text(
                    'انصراف',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 17),
                  label: const Text(
                    'ذخیره',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: ShopColors.seed),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );

  Widget _pickerTile({
    required String label,
    required IconData icon,
    required String emptyText,
    required List<String> selected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xfff9fbfe),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ShopColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: ShopColors.inkSoft),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 16,
                  color: ShopColors.inkFaint,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (selected.isEmpty)
              Text(
                emptyText,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: ShopColors.inkFaint,
                ),
              )
            else
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (var i = 0; i < selected.length; i++)
                    ShopTag(
                      text: selected.length > 1 && label == 'تأییدکنندگان'
                          ? '${Fa.digits(i + 1)}. ${selected[i]}'
                          : selected[i],
                      color: ShopColors.seed,
                    ),
                ],
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickMulti({
    required String title,
    required List<DocLookup> items,
    required List<int> selected,
    required ValueChanged<List<int>> onDone,
    bool keepOrder = false,
  }) async {
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) {
        final cur = [...selected];
        var q = '';
        return StatefulBuilder(
          builder: (c, setLocal) {
            final filtered = q.trim().isEmpty
                ? items
                : items
                      .where((i) => i.name.contains(q.trim()))
                      .toList();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(c).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(c).size.height * 0.62,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(c).pop(cur),
                            child: const Text(
                              'تأیید',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        onChanged: (v) => setLocal(() => q = v),
                        style: const TextStyle(fontSize: 11),
                        decoration: _dec('جستجو…'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final it in filtered)
                            CheckboxListTile(
                              dense: true,
                              value: cur.contains(it.id),
                              onChanged: (v) => setLocal(() {
                                if (v == true) {
                                  cur.add(it.id);
                                } else {
                                  cur.remove(it.id);
                                }
                              }),
                              title: Text(
                                it.name,
                                style: const TextStyle(fontSize: 10.5),
                              ),
                            ),
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(18),
                              child: Text(
                                'موردی یافت نشد',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ShopColors.inkFaint,
                                ),
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
        );
      },
    );
    if (picked != null) onDone(keepOrder ? picked : picked.toList());
  }

  Widget _dateButton(
    DateTime? value,
    ValueChanged<DateTime?> onChanged, {
    String? placeholder,
    bool allowClear = false,
  }) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: DateTime(now.year - 20),
              lastDate: DateTime(now.year + 30),
            );
            if (picked != null) onChanged(picked);
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 42),
            alignment: Alignment.centerRight,
            foregroundColor: ShopColors.ink,
            side: const BorderSide(color: ShopColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.event_rounded, size: 15),
          label: Text(
            value == null
                ? (placeholder ?? ' انتخاب تاریخ')
                : Fa.date(value.toIso8601String(), time: false),
            style: TextStyle(
              fontSize: 11,
              color: value == null ? ShopColors.inkFaint : ShopColors.ink,
            ),
          ),
        ),
      ),
      if (allowClear && value != null)
        IconButton(
          tooltip: 'پاک کردن',
          icon: const Icon(Icons.close_rounded, size: 17),
          onPressed: () => onChanged(null),
        ),
    ],
  );

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
    isDense: true,
    filled: true,
    fillColor: const Color(0xfff9fbfe),
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ShopColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ShopColors.line),
    ),
  );
}
