// ============================================================
//  «ثبت ورژن جدید» + پیوست‌ها + «تایید/رد» + «مقایسهٔ دو نسخه»
//  فاز ۹-ی — آینهٔ مودال‌های `DocumentView.razor` و اندپوینت‌های
//  `POST documents/versions`، `POST documents/approval`،
//  `GET documents/{id}/compare` و `api/attachments/DocVersion/{id}`
// ============================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'doc_archive_detail_page.dart' show DocVersionRow;
import 'system_style.dart';

// ============================================================
//  شیت «ثبت ورژن جدید»
// ============================================================

class DocNewVersionSheet extends StatefulWidget {
  const DocNewVersionSheet({
    super.key,
    required this.documentId,
    required this.documentTitle,
    this.users = const [],
  });

  final int documentId;
  final String documentTitle;
  final List<DocLookup> users;

  @override
  State<DocNewVersionSheet> createState() => _DocNewVersionSheetState();
}

class _DocNewVersionSheetState extends State<DocNewVersionSheet> {
  late final DocArchiveRepository _repo;
  final _title = TextEditingController();
  final _changeNote = TextEditingController();

  DateTime? _expireDate;
  bool _sendToFlow = true;
  bool _activateOnApprove = true;
  final List<int> _approvers = [];
  final List<PlatformFile> _files = [];

  bool _saving = false;
  String? _error;
  String _progressText = '';

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _title.dispose();
    _changeNote.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.pickFiles();
    if (res.isEmpty) return;
    setState(() => _files.addAll(res));
  }

  Future<void> _save() async {
    final err = validateVersionForm(changeNote: _changeNote.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _progressText = '';
    });
    try {
      final versionId = await _repo.createVersion(
        DocVersionInput(
          documentId: widget.documentId,
          title: _title.text,
          changeNote: _changeNote.text,
          expireDate: _expireDate,
          sendToFlow: _sendToFlow,
          activateOnApprove: _activateOnApprove,
          approverUserIds: _approvers,
        ),
      );

      // آپلود پیوست‌ها روی نسخهٔ تازه‌ساخته‌شده (همان ترتیب وب)
      var failed = 0;
      for (final f in _files) {
        final bytes = await _readPicked(f);
        if (bytes == null) {
          failed++;
          continue;
        }
        setState(() => _progressText = 'بارگذاری ${f.name}…');
        try {
          await _repo.uploadAttachment(
            versionId: versionId,
            fileName: f.name,
            bytes: bytes,
          );
        } catch (_) {
          failed++;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        failed == 0
            ? 'نسخه ثبت شد.'
            : 'نسخه ثبت شد؛ $failed پیوست بارگذاری نشد.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_rounded,
                    size: 17,
                    color: ShopColors.seed,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'ثبت ورژن جدید',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'ثبت ورژن',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                children: [
                  Text(
                    widget.documentTitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    SystemNote(
                      text: _error!,
                      color: ShopColors.danger,
                      icon: Icons.error_outline_rounded,
                    ),
                  ],
                  const SizedBox(height: 8),
                  ShopField(
                    label: 'عنوان ورژن',
                    child: TextField(
                      controller: _title,
                      style: const TextStyle(fontSize: 11),
                      decoration: _dec('پیش‌فرض: عنوان مدرک'),
                    ),
                  ),
                  ShopField(
                    label: 'تاریخ انقضای ورژن',
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: ShopColors.ink,
                        side: const BorderSide(color: ShopColors.line),
                        alignment: Alignment.centerRight,
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _expireDate ?? now,
                          firstDate: DateTime(now.year - 20),
                          lastDate: DateTime(now.year + 30),
                        );
                        if (picked != null) {
                          setState(() => _expireDate = picked);
                        }
                      },
                      icon: const Icon(Icons.event_rounded, size: 15),
                      label: Text(
                        _expireDate == null
                            ? '----/--/--'
                            : Fa.date(
                                _expireDate!.toIso8601String(),
                                time: false,
                              ),
                        style: const TextStyle(fontSize: 10.5),
                      ),
                    ),
                  ),
                  if (_expireDate != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _expireDate = null),
                        child: const Text(
                          'پاک کردن تاریخ',
                          style: TextStyle(fontSize: 9.5),
                        ),
                      ),
                    ),
                  ShopField(
                    label: 'شرح تغییرات',
                    required: true,
                    child: TextField(
                      controller: _changeNote,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 11),
                      decoration: _dec(''),
                    ),
                  ),
                  ShopField(
                    label: 'نفرات گردش این ورژن',
                    hint: 'خالی = استفاده از نفرات پیش‌فرض مدرک',
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: ShopColors.ink,
                        side: const BorderSide(color: ShopColors.line),
                        alignment: Alignment.centerRight,
                      ),
                      onPressed: _pickApprovers,
                      icon: const Icon(Icons.alt_route_rounded, size: 15),
                      label: Text(
                        _approvers.isEmpty
                            ? 'انتخاب افراد…'
                            : _approvers
                                  .map((id) => _nameOf(id))
                                  .join(' / '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  ShopField(
                    label: 'پیوست‌های این ورژن',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xfff9fbfe),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.cloud_upload_rounded,
                            size: 26,
                            color: ShopColors.seed,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'افزودن فایل از گوشی',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'پس از ثبت ورژن، فایل‌ها خودکار آپلود می‌شوند (حداکثر ۱۰ مگابایت هر فایل)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8.5,
                              height: 1.8,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: _pickFiles,
                            icon: const Icon(Icons.attach_file_rounded, size: 14),
                            label: const Text(
                              'انتخاب فایل',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_files.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final f in _files)
                            Chip(
                              label: Text(
                                f.name,
                                style: const TextStyle(fontSize: 9),
                              ),
                              onDeleted: () => setState(() => _files.remove(f)),
                            ),
                        ],
                      ),
                    ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _sendToFlow,
                    onChanged: (v) => setState(() => _sendToFlow = v),
                    title: const Text(
                      'ارسال به گردش تایید',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: const Text(
                      'ورژن فریز شده و تا تایید کامل، فعال نمی‌شود.',
                      style: TextStyle(fontSize: 8.5),
                    ),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _activateOnApprove,
                    onChanged: (v) => setState(() => _activateOnApprove = v),
                    title: const Text(
                      'پس از تایید، خودکار فعال شود',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_progressText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _progressText,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: ShopColors.seed,
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
  }

  String _nameOf(int id) {
    for (final u in widget.users) {
      if (u.id == id) return u.name;
    }
    return '#$id';
  }

  Future<void> _pickApprovers() async {
    final sel = [..._approvers];
    var q = '';
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) {
          final list = q.trim().isEmpty
              ? widget.users
              : widget.users.where((u) => u.name.contains(q.trim())).toList();
          return SizedBox(
            height: MediaQuery.of(c).size.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'نفرات گردش',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(c).pop(sel),
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
                    decoration: _dec('نام نفر را تایپ کنید…'),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    children: [
                      for (final u in list)
                        CheckboxListTile(
                          dense: true,
                          value: sel.contains(u.id),
                          onChanged: (v) => setLocal(() {
                            if (v == true) {
                              sel.add(u.id);
                            } else {
                              sel.remove(u.id);
                            }
                          }),
                          title: Text(
                            u.name,
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (picked != null) {
      setState(
        () => _approvers
          ..clear()
          ..addAll(picked),
      );
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
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

// ============================================================
//  شیت «تایید / رد ورژن»
// ============================================================

class DocApprovalSheet extends StatefulWidget {
  const DocApprovalSheet({
    super.key,
    required this.version,
    required this.approve,
  });

  final DocVersionRow version;
  final bool approve;

  @override
  State<DocApprovalSheet> createState() => _DocApprovalSheetState();
}

class _DocApprovalSheetState extends State<DocApprovalSheet> {
  late final DocArchiveRepository _repo;
  final _comment = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.submitApproval(
        DocApprovalInput(
          versionId: widget.version.id,
          approve: widget.approve,
          comment: _comment.text,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(widget.approve ? 'ورژن تایید شد.' : 'ورژن رد شد.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.approve ? 'تایید ورژن' : 'رد ورژن',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
            Text(
              'ورژن ${Fa.digits(widget.version.versionNo)}',
              style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
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
            const Text(
              'توضیح / نظر',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _comment,
              maxLines: 3,
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'نظر خود را بنویسید...',
                hintStyle: TextStyle(fontSize: 9.5),
                border: OutlineInputBorder(),
              ),
            ),
            if (!widget.approve) ...[
              const SizedBox(height: 8),
              const Text(
                'با رد کردن، ورژن از حالت فریز خارج شده و برای اصلاح به ثبت‌کننده برمی‌گردد.',
                style: TextStyle(
                  fontSize: 9,
                  height: 1.8,
                  color: ShopColors.warn,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      'انصراف',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.approve
                          ? ShopColors.ok
                          : ShopColors.danger,
                    ),
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            widget.approve
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            size: 16,
                          ),
                    label: Text(
                      widget.approve ? 'تایید' : 'رد',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  صفحهٔ «مقایسهٔ دو نسخه»
// ============================================================

class DocComparePage extends StatefulWidget {
  const DocComparePage({
    super.key,
    required this.documentId,
    required this.versions,
  });

  final int documentId;

  /// نسخه‌ها به ترتیب نزولی (جدیدترین اول)
  final List<DocVersionRow> versions;

  @override
  State<DocComparePage> createState() => _DocComparePageState();
}

class _DocComparePageState extends State<DocComparePage> {
  late final DocArchiveRepository _repo;
  DocVersionCompare? _result;
  bool _loading = false;
  String? _error;

  late int _from;
  late int _to;

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    // پیش‌فرض: قدیمی‌ترین و جدیدترین
    _to = widget.versions.isEmpty ? 0 : widget.versions.first.id;
    _from = widget.versions.length > 1
        ? widget.versions.last.id
        : (widget.versions.isEmpty ? 0 : widget.versions.first.id);
    _load();
  }

  Future<void> _load() async {
    if (_from == 0 || _to == 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.compareVersions(
        documentId: widget.documentId,
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _result = res;
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

  String _label(DocVersionRow v) =>
      'ورژن ${Fa.digits(v.versionNo)} — ${DocVersionStatus.nameView(v.status)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'مقایسه دو ورژن',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _from == 0 ? null : _from,
                  isDense: true,
                  style: const TextStyle(fontSize: 10.5, color: ShopColors.ink),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'نسخه مبدأ (قدیمی‌تر)',
                    labelStyle: TextStyle(fontSize: 9),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final v in widget.versions)
                      DropdownMenuItem(
                        value: v.id,
                        child: Text(
                          _label(v),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _from = v ?? _from);
                    _load();
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _to == 0 ? null : _to,
                  isDense: true,
                  style: const TextStyle(fontSize: 10.5, color: ShopColors.ink),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'نسخه مقصد (جدیدتر)',
                    labelStyle: TextStyle(fontSize: 9),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final v in widget.versions)
                      DropdownMenuItem(
                        value: v.id,
                        child: Text(
                          _label(v),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _to = v ?? _to);
                    _load();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SystemNote(
              text: _error!,
              color: ShopColors.danger,
              icon: Icons.error_outline_rounded,
            )
          else if (_result != null) ...[
            Row(
              children: [
                ShopTag(
                  text: _result!.summaryFa,
                  color: _result!.changeCount == 0
                      ? ShopColors.inkFaint
                      : ShopColors.warn,
                  icon: Icons.compare_arrows_rounded,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_result!.documentCode} — ${_result!.documentTitle}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _diffSection('فیلدهای اصلی', _result!.fields),
            const SizedBox(height: 8),
            _diffSection('نفرات گردش', _result!.approvers),
            const SizedBox(height: 8),
            _diffSection('پیوست‌ها', _result!.attachments),
            if (_result!.between.isNotEmpty) ...[
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
                    Text(
                      'رویدادهای بین دو ورژن (${Fa.digits(_result!.between.length)})',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final l in _result!.between)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShopTag(
                              text: DocLogRow.actionName(l.action),
                              color: ShopColors.seed,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${l.detail ?? ''}\n${l.userName} · ${Fa.date(l.createdAt?.toIso8601String())}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  height: 1.7,
                                  color: ShopColors.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _diffSection(String title, List<DocDiffRow> rows) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        if (rows.isEmpty)
          const Text(
            'موردی برای مقایسه نیست.',
            style: TextStyle(fontSize: 9, color: ShopColors.inkFaint),
          )
        else
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: r.isChanged
                      ? ShopColors.warn.withValues(alpha: 0.07)
                      : const Color(0xfff9fbfe),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.field,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (r.isChanged)
                          ShopTag(text: r.kindLabel, color: ShopColors.warn),
                      ],
                    ),
                    if (r.isChanged)
                      Text(
                        '${r.leftCell}  →  ${r.rightCell}',
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 9,
                          height: 1.8,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ],
    ),
  );
}

// ============================================================
//  بلوک پیوست‌های یک نسخه (داخل صفحهٔ مدرک)
// ============================================================

class DocAttachmentsBlock extends StatefulWidget {
  const DocAttachmentsBlock({
    super.key,
    required this.versionId,
    required this.canUpload,
    required this.canDeleteAny,
  });

  final int versionId;
  final bool canUpload;
  final bool canDeleteAny;

  @override
  State<DocAttachmentsBlock> createState() => _DocAttachmentsBlockState();
}

class _DocAttachmentsBlockState extends State<DocAttachmentsBlock> {
  late final DocArchiveRepository _repo;
  List<DocAttachment> _items = const [];
  bool _loading = true;
  bool _uploading = false;
  int _sent = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.attachments(widget.versionId);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final res = await FilePicker.pickFiles();
    if (res.isEmpty) return;
    setState(() => _uploading = true);
    var tooLarge = 0;
    for (final f in res) {
      final bytes = await _readPicked(f);
      if (bytes == null) continue;
      try {
        await _repo.uploadAttachment(
          versionId: widget.versionId,
          fileName: f.name,
          bytes: bytes,
          onProgress: (s, t) {
            if (!mounted) return;
            setState(() {
              _sent = s;
              _total = t;
            });
          },
        );
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    if (tooLarge > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$tooLarge فایل رد شد — $kAttachmentTooLarge'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await _load();
  }

  Future<void> _delete(DocAttachment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          'حذف پیوست',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'پیوست «${a.fileName}» حذف شود؟',
          style: const TextStyle(fontSize: 10.5, height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('انصراف', style: TextStyle(fontSize: 11)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('حذف', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteAttachment(a.id);
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

  Future<void> _preview(DocAttachment a) async {
    if (a.isImage) {
      try {
        final bytes = await _repo.attachmentBytes(a.id);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (c) => Dialog(
            backgroundColor: Colors.black,
            child: InteractiveViewer(
              child: Image.memory(
                Uint8List.fromList(bytes),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'پیش‌نمایش این فایل ممکن نیست.',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('دریافت فایل ناموفق بود.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          a.isPdf
              ? 'پیش‌نمایش PDF در برنامهٔ جداگانه انجام می‌شود.'
              : 'پیش‌نمایش این نوع فایل در وب انجام می‌شود.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_file_rounded, size: 13, color: ShopColors.inkSoft),
            const SizedBox(width: 4),
            Text(
              'پیوست‌ها (${Fa.digits(_items.length)})',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: ShopColors.inkSoft,
              ),
            ),
            const Spacer(),
            if (widget.canUpload)
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 26),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                onPressed: _uploading ? null : _upload,
                icon: const Icon(Icons.add_rounded, size: 14),
                label: Text(
                  _uploading ? 'در حال آپلود…' : 'افزودن',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
          ],
        ),
        if (_uploading && _total > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: LinearProgressIndicator(
              value: _total == 0 ? null : _sent / _total,
              minHeight: 4,
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            ),
          )
        else if (_items.isEmpty)
          const Text(
            'پیوستی ثبت نشده است.',
            style: TextStyle(fontSize: 9, color: ShopColors.inkFaint),
          )
        else
          for (final a in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    a.isImage
                        ? Icons.image_rounded
                        : a.isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.insert_drive_file_rounded,
                    size: 14,
                    color: ShopColors.seed,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: InkWell(
                      onTap: () => _preview(a),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9.5),
                          ),
                          Text(
                            '${a.sizeFa} · ${a.uploaderName} · ${a.uploadedAtFa}',
                            style: const TextStyle(
                              fontSize: 8,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (a.canDelete || widget.canDeleteAny)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 14,
                        color: ShopColors.danger,
                      ),
                      onPressed: () => _delete(a),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

/// خواندن بایت‌های فایل انتخاب‌شده از گوشی
Future<List<int>?> _readPicked(PlatformFile f) async {
  final path = f.path;
  if (path == null) return null;
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    if (await file.length() > kAttachmentMaxBytes) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
