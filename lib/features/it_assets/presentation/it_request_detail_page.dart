// ============================================================
//  جزئیات و گردش‌کار «درخواست خدمت IT» — فاز ۹-ب
//  آینهٔ مودال جزئیات `Pages/ItAssets/ItRequests.razor`
//
//  نمای درخواست‌دهنده (تب «درخواست‌های من»):
//    شرح، پیوست‌ها، «درخواست شما در واحد IT در حال بررسی و انجام است.»
//    و «پاسخ نهایی واحد IT» + «تایید و تکمیل درخواست» (وقتی ManagerApproved)
//  نمای واحد IT (کارتابل کارشناس/مدیر):
//    • اقدام مستقیم مدیر: «انجام شد — بستن توسط خودم» / «رد درخواست»
//    • ارجاع به کارشناس(ها) با توضیح کلی و شرح اختصاصی هر کارشناس
//    • کارشناسان و گزارش‌ها: «تایید گزارش» / «رد (برگشت به کارشناس)»
//    • کارشناس: انتخاب «انجام شد / انجام نشد» + «ثبت گزارش»
//    • پاسخ نهایی فقط وقتی همهٔ گزارش‌ها تایید شده‌اند
//    • آرشیو رفت‌وبرگشت‌ها
// ============================================================

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/it_request_repository.dart';
import '../models/it_request_models.dart';

class ItRequestDetailPage extends StatefulWidget {
  const ItRequestDetailPage({
    super.key,
    required this.requestId,
    required this.access,
    this.requesterView = false,
  });

  final int requestId;
  final ItAccess access;

  /// نمای درخواست‌دهنده — بخش‌های داخلی واحد IT پنهان می‌شوند
  final bool requesterView;

  @override
  State<ItRequestDetailPage> createState() => _ItRequestDetailPageState();
}

class _ItRequestDetailPageState extends State<ItRequestDetailPage> {
  late final ItRequestRepository _repo;

  ItRequestItem? _item;
  List<ItLogRow> _logs = const [];
  List<ItAttachment> _attachments = const [];
  List<ItExpert> _experts = const [];

  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _changed = false;

  // فرم‌ها
  final _managerActionText = TextEditingController();
  final _assignNote = TextEditingController();
  final _approveNote = TextEditingController();
  final Map<int, TextEditingController> _instructions = {};
  final Map<int, TextEditingController> _decideNotes = {};
  final Set<int> _assignSelected = {};
  final _myReport = TextEditingController();
  bool? _myDone = true;

  @override
  void initState() {
    super.initState();
    _repo = ItRequestRepository(context.read<ApiClient>());
    _load();
  }

  @override
  void dispose() {
    _managerActionText.dispose();
    _assignNote.dispose();
    _approveNote.dispose();
    _myReport.dispose();
    for (final c in _instructions.values) {
      c.dispose();
    }
    for (final c in _decideNotes.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? ShopColors.danger : null,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // جزئیات از همان لیست گرفته می‌شود؛ شمارهٔ صفحه ندارد چون id یکتاست
      final res = widget.requesterView
          ? await _repo.mine()
          : widget.access.isManager
          ? await _repo.managerInbox()
          : await _repo.expertInbox();
      var item = res.items.where((r) => r.id == widget.requestId).firstOrNull;
      // اگر در صفحهٔ اول نبود، از مسیر مدیر/کارشناس دوباره تلاش می‌کنیم
      if (item == null && !widget.access.isManager) {
        final m = await _repo.managerInbox();
        item = m.items.where((r) => r.id == widget.requestId).firstOrNull;
      }
      if (item == null) {
        final e = await _repo.expertInbox();
        item = e.items.where((r) => r.id == widget.requestId).firstOrNull;
      }
      final logs = await _repo.logs(widget.requestId);
      final atts = await _repo.attachments(widget.requestId);
      List<ItExpert> exps = const [];
      if (widget.access.isManager) {
        try {
          exps = await _repo.experts();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _item = item;
        _logs = logs;
        _attachments = atts;
        _experts = exps;
        _loading = false;
        if (item == null) _error = 'درخواست پیدا نشد.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action, {String? okText}) async {
    setState(() => _busy = true);
    try {
      await action();
      _changed = true;
      if (okText != null) _toast(okText);
      await _load();
    } catch (e) {
      _toast(_clean(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------ actions

  Future<void> _submitClose() async {
    final text = _managerActionText.text.trim();
    if (text.isEmpty) {
      _toast('پاسخ / دلیل را وارد کنید.', error: true);
      return;
    }
    final ok = await _confirm(
      'بستن درخواست',
      'درخواست به‌عنوان «انجام شد» بسته می‌شود و این متن پاسخ نهایی است.',
    );
    if (!ok) return;
    await _run(
      () => _repo.close(widget.requestId, finalResponse: text),
      okText: 'درخواست بسته شد.',
    );
  }

  Future<void> _submitReject() async {
    final text = _managerActionText.text.trim();
    if (text.isEmpty) {
      _toast('دلیل رد را وارد کنید.', error: true);
      return;
    }
    final ok = await _confirm('رد درخواست', 'درخواست رد و به درخواست‌کننده اعلام می‌شود.');
    if (!ok) return;
    await _run(
      () => _repo.reject(widget.requestId, reason: text),
      okText: 'درخواست رد شد.',
    );
  }

  Future<void> _submitAssign() async {
    if (_assignSelected.isEmpty) {
      _toast('حداقل یک کارشناس انتخاب کنید.', error: true);
      return;
    }
    await _run(
      () => _repo.assign(
        widget.requestId,
        managerNote: _assignNote.text.trim().isEmpty
            ? null
            : _assignNote.text.trim(),
        experts: [
          for (final id in _assignSelected)
            (
              userId: id,
              instruction: _instructions[id]?.text.trim().isEmpty ?? true
                  ? null
                  : _instructions[id]!.text.trim(),
            ),
        ],
      ),
      okText: 'ارجاع ثبت شد.',
    );
  }

  Future<void> _decide(ItAssignment a, bool approved) async {
    final note = _decideNotes[a.id]?.text.trim();
    await _run(
      () => _repo.decide(
        widget.requestId,
        a.id,
        approved: approved,
        note: note == null || note.isEmpty ? null : note,
      ),
      okText: approved ? 'گزارش تایید شد.' : 'گزارش رد شد و به کارشناس برگشت.',
    );
  }

  Future<void> _submitApprove() async {
    final text = _approveNote.text.trim();
    if (text.isEmpty) {
      _toast('پاسخ نهایی را وارد کنید.', error: true);
      return;
    }
    await _run(
      () => _repo.approve(widget.requestId, finalResponse: text),
      okText: 'پاسخ نهایی برای درخواست‌کننده ارسال شد.',
    );
  }

  Future<void> _submitReport() async {
    final text = _myReport.text.trim();
    if (text.isEmpty) {
      _toast('شرح اقدامات را وارد کنید.', error: true);
      return;
    }
    await _run(
      () => _repo.submitReport(
        widget.requestId,
        report: text,
        done: _myDone ?? true,
      ),
      okText: 'گزارش ثبت شد.',
    );
  }

  Future<void> _submitComplete() async {
    await _run(
      () => _repo.complete(widget.requestId),
      okText: 'درخواست تکمیل شد.',
    );
  }

  Future<void> _pickAndUpload() async {
    try {
      final res = await FilePicker.pickFiles();
      final f = res.isEmpty ? null : res.first;
      if (f == null) return;
      final Uint8List bytes = await f.xFile.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        _toast('حداکثر حجم فایل ۱۰ مگابایت است.', error: true);
        return;
      }
      final role = widget.access.isManager
          ? 'Manager'
          : widget.access.isExpert
          ? 'Expert'
          : 'Requester';
      await _run(
        () => _repo.uploadAttachment(
          widget.requestId,
          fileName: f.name,
          bytes: Uint8List.fromList(bytes),
          role: role,
        ),
        okText: 'پیوست اضافه شد.',
      );
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        content: Text(body, style: const TextStyle(fontSize: 12, height: 1.7)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف', style: TextStyle(fontSize: 12)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تایید', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
    return r == true;
  }

  // ------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: AppBar(
          backgroundColor: ShopColors.surface,
          foregroundColor: ShopColors.ink,
          elevation: 0.5,
          title: const Text(
            'جزئیات درخواست',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: ShopEmpty(
                  title: 'درخواست باز نشد',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                ),
              )
            : _body(_item!),
      ),
    );
  }

  Widget _body(ItRequestItem r) {
    final status = ItRequestStatus.label(
      r.status,
      requesterView: widget.requesterView,
    );
    final isOpen = r.open;
    final myAssignment = r.assignments
        .where((a) => a.expertUserId == widget.access.userId)
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
      children: [
        ShopHeader(
          title: r.title,
          subtitle: '${r.number} · ${ItRequestType.label(r.requestType)}',
          icon: Icons.headset_mic_rounded,
          badge: status,
        ),
        const SizedBox(height: 10),
        // ---------- اطلاعات پایه ----------
        _block(
          title: 'اطلاعات درخواست',
          icon: Icons.info_outline_rounded,
          child: Column(
            children: [
              _kv('درخواست‌کننده', r.requesterName),
              _kv(
                'تاریخ ثبت',
                Fa.date(r.createdAt?.toIso8601String(), time: false),
              ),
              if ((r.systemLabel ?? '').isNotEmpty)
                _kv('سیستم', r.systemLabel!),
              if (r.isExternal)
                _kv(
                  'شرکت راه‌دور',
                  '${r.companyName ?? '—'}${r.companyCode == null ? '' : ' (${r.companyCode})'}',
                ),
              if ((r.requesterPhone ?? '').isNotEmpty)
                _kv('شماره تماس', Fa.digits(r.requesterPhone!)),
            ],
          ),
        ),
        // ---------- شرح ----------
        if (r.description.trim().isNotEmpty)
          _block(
            title: 'شرح درخواست',
            icon: Icons.notes_rounded,
            child: Text(
              // وب HTML رندر می‌کند؛ در موبایل متن ساده نمایش داده می‌شود
              _plain(r.description),
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.9,
                color: ShopColors.ink,
              ),
            ),
          ),
        // ---------- پیوست‌ها ----------
        _block(
          title: 'پیوست‌ها (${Fa.number(_attachments.length)})',
          icon: Icons.attach_file_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_attachments.isEmpty)
                const Text(
                  'پیوستی ثبت نشده است.',
                  style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
                )
              else
                for (final a in _attachments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file_rounded,
                          size: 14,
                          color: ShopColors.seed,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            a.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '(${a.roleTitle} — ${a.uploaderName})',
                          style: const TextStyle(
                            fontSize: 9,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickAndUpload,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 15),
                label: const Text(
                  'افزودن پیوست',
                  style: TextStyle(fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),
        // ---------- بخش‌های داخلی واحد IT ----------
        if (!widget.requesterView) ...[
          // اقدام مستقیم مدیر
          if (widget.access.isManager && isOpen)
            _block(
              title: 'اقدام مستقیم مدیر',
              icon: Icons.manage_accounts_rounded,
              accent: const Color(0xff7c3aed),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _managerActionText,
                    minLines: 2,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'پاسخ / دلیل…',
                      hintStyle: TextStyle(fontSize: 10.5),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _submitClose,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          foregroundColor: ShopColors.ok,
                          side: const BorderSide(color: ShopColors.ok),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 15),
                        label: const Text(
                          'انجام شد — بستن توسط خودم',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _submitReject,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          foregroundColor: ShopColors.danger,
                          side: const BorderSide(color: ShopColors.danger),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 15),
                        label: const Text(
                          'رد درخواست',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // ارجاع مدیر
          if (widget.access.isManager && isOpen)
            _block(
              title: 'ارجاع به کارشناس(ها)',
              icon: Icons.manage_accounts_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'توضیح کلی ارجاع',
                    style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
                  ),
                  const SizedBox(height: 3),
                  TextField(
                    controller: _assignNote,
                    minLines: 2,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (_experts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ShopColors.warn.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'کارشناسی تعریف نشده — به کاربر موردنظر مجوز «کارشناس IT» بدهید.',
                        style: TextStyle(
                          fontSize: 10,
                          color: ShopColors.warn,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    for (final ex in _experts) ...[
                      CheckboxListTile(
                        value: _assignSelected.contains(ex.id),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: ShopColors.seed,
                        title: Text(
                          ex.username,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _assignSelected.add(ex.id);
                            _instructions.putIfAbsent(
                              ex.id,
                              () => TextEditingController(),
                            );
                          } else {
                            _assignSelected.remove(ex.id);
                          }
                        }),
                      ),
                      if (_assignSelected.contains(ex.id))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, right: 4),
                          child: TextField(
                            controller: _instructions[ex.id],
                            style: const TextStyle(fontSize: 11),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText:
                                  'شرح اختصاصی برای این کارشناس (اختیاری)',
                              hintStyle: TextStyle(fontSize: 10),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                    ],
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: _busy || _experts.isEmpty ? null : _submitAssign,
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.warn,
                      minimumSize: const Size(0, 38),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 15),
                    label: Text(
                      r.status == ItRequestStatus.assigned
                          ? 'ارجاع مجدد'
                          : 'ارجاع',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // کارشناسان و گزارش‌ها
          if (r.assignments.isNotEmpty)
            _block(
              title:
                  'کارشناسان و گزارش‌ها  (${Fa.number(r.reportsSubmitted)}/${Fa.number(r.assignments.length)} پاسخ)',
              icon: Icons.groups_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((r.managerNote ?? '').isNotEmpty) ...[
                    Text(
                      'توضیح مدیر: ${r.managerNote}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  for (final a in r.assignments) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: ShopColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.person_pin_circle_rounded,
                                size: 14,
                                color: ShopColors.seed,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  a.expertName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (a.reportSubmitted)
                                const ShopTag(
                                  text: 'گزارش رسیده',
                                  color: ShopColors.ok,
                                ),
                              if (a.done == true) ...[
                                const SizedBox(width: 4),
                                const ShopTag(
                                  text: '✅ انجام شد',
                                  color: ShopColors.ok,
                                ),
                              ] else if (a.done == false) ...[
                                const SizedBox(width: 4),
                                const ShopTag(
                                  text: '❌ انجام نشد',
                                  color: ShopColors.danger,
                                ),
                              ],
                              if (a.approved) ...[
                                const SizedBox(width: 4),
                                const ShopTag(
                                  text: 'تایید مدیر ✔',
                                  color: ShopColors.seed,
                                ),
                              ] else if (a.managerDecision == 'Rejected') ...[
                                const SizedBox(width: 4),
                                const ShopTag(
                                  text: 'رد شده',
                                  color: ShopColors.danger,
                                ),
                              ],
                            ],
                          ),
                          if ((a.managerInstruction ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                'شرح مدیر: ${a.managerInstruction}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                            ),
                          // کارشناس: ثبت گزارش
                          if (widget.access.isExpert &&
                              a.expertUserId == widget.access.userId &&
                              r.status == ItRequestStatus.assigned &&
                              a.managerDecision != 'Approved')
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _doneChip(
                                        '✅ انجام شد',
                                        true,
                                        ShopColors.ok,
                                      ),
                                      const SizedBox(width: 8),
                                      _doneChip(
                                        '❌ انجام نشد',
                                        false,
                                        ShopColors.danger,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _myReport,
                                    minLines: 3,
                                    maxLines: 5,
                                    style: const TextStyle(fontSize: 11.5),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'شرح اقدامات…',
                                      hintStyle: TextStyle(fontSize: 10.5),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  FilledButton.icon(
                                    onPressed: _busy ? null : _submitReport,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: ShopColors.ok,
                                      minimumSize: const Size(0, 34),
                                    ),
                                    icon: const Icon(Icons.check_rounded, size: 15),
                                    label: const Text(
                                      'ثبت گزارش',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if ((a.expertReport ?? '').isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ShopColors.surface,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: ShopColors.line),
                              ),
                              child: Text(
                                a.expertReport!,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  height: 1.8,
                                ),
                              ),
                            ),
                          // مدیر: تایید/رد گزارش
                          if (widget.access.isManager &&
                              a.reportSubmitted &&
                              a.managerDecision == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _decideNotes.putIfAbsent(
                                      a.id,
                                      () => TextEditingController(),
                                    ),
                                    style: const TextStyle(fontSize: 10.5),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'یادداشت مدیر (اختیاری)',
                                      hintStyle: TextStyle(fontSize: 10),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _decide(a, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: ShopColors.ok,
                                          minimumSize: const Size(0, 32),
                                        ),
                                        icon: const Icon(Icons.check_rounded,
                                            size: 14),
                                        label: const Text(
                                          'تایید گزارش',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _decide(a, false),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 32),
                                          foregroundColor: ShopColors.danger,
                                          side: const BorderSide(
                                            color: ShopColors.danger,
                                          ),
                                        ),
                                        icon: const Icon(Icons.close_rounded,
                                            size: 14),
                                        label: const Text(
                                          'رد (برگشت به کارشناس)',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          if ((a.managerDecisionNote ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'یادداشت مدیر: ${a.managerDecisionNote}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          // پاسخ نهایی مدیر
          if (widget.access.isManager &&
              r.status == ItRequestStatus.assigned &&
              r.assignments.isNotEmpty)
            _block(
              title: 'پاسخ نهایی به درخواست‌کننده',
              icon: Icons.verified_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!r.allApproved) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ShopColors.warn.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'تا زمانی که گزارش همهٔ کارشناسان را تایید نکنید، امکان ارسال پاسخ نهایی نیست. '
                        '(${Fa.number(r.assignments.where((a) => a.approved).length)}/'
                        '${Fa.number(r.assignments.length)} تایید شده)',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.7,
                          color: ShopColors.warn,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                  ],
                  TextField(
                    controller: _approveNote,
                    enabled: r.allApproved,
                    minLines: 3,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'پاسخ نهایی که درخواست‌کننده می‌بیند…',
                      hintStyle: TextStyle(fontSize: 10.5),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 7),
                  FilledButton.icon(
                    onPressed: _busy || !r.allApproved ? null : _submitApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.seed,
                      minimumSize: const Size(0, 38),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 15),
                    label: const Text(
                      'تایید و ارسال به درخواست‌کننده',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // آرشیو
          if (_logs.isNotEmpty)
            _block(
              title: 'آرشیو رفت‌وبرگشت‌ها',
              icon: Icons.history_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in _logs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: ShopColors.seed,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: l.actorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' (${l.roleTitle}) — ',
                                        style: const TextStyle(
                                          color: ShopColors.inkFaint,
                                        ),
                                      ),
                                      TextSpan(text: l.actionTitle),
                                    ],
                                  ),
                                  style: const TextStyle(fontSize: 10),
                                ),
                                if ((l.text ?? '').isNotEmpty)
                                  Text(
                                    l.text!,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: ShopColors.inkFaint,
                                      height: 1.7,
                                    ),
                                  ),
                                Text(
                                  Fa.date(l.createdAt?.toIso8601String()),
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
                ],
              ),
            ),
        ] else ...[
          // نمای درخواست‌دهنده
          if (r.status == ItRequestStatus.assigned)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xff0284c7).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                'درخواست شما در واحد IT در حال بررسی و انجام است.',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff0284c7),
                ),
              ),
            ),
        ],
        // پاسخ نهایی (برای همه)
        if ((r.finalResponse ?? '').isNotEmpty)
          _block(
            title: 'پاسخ نهایی واحد IT',
            icon: Icons.chat_rounded,
            accent: ShopColors.ok,
            child: Text(
              r.finalResponse!,
              style: const TextStyle(fontSize: 11.5, height: 1.9),
            ),
          ),
        // تایید و تکمیل توسط درخواست‌کننده
        if (r.status == ItRequestStatus.managerApproved &&
            r.requesterUserId == widget.access.userId)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton.icon(
              onPressed: _busy ? null : _submitComplete,
              style: FilledButton.styleFrom(
                backgroundColor: ShopColors.ok,
                minimumSize: const Size(0, 46),
              ),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text(
                'تایید و تکمیل درخواست',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        // کارشناس وقتی از کارتابل خودش باز کرده است
        if (!widget.requesterView &&
            myAssignment != null &&
            r.status == ItRequestStatus.assigned)
          const SizedBox(height: 4),
      ],
    );
  }

  Widget _doneChip(String label, bool value, Color color) => InkWell(
    onTap: () => setState(() => _myDone = value),
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _myDone == value ? color.withValues(alpha: 0.13) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _myDone == value ? color : ShopColors.line,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _myDone == value ? color : ShopColors.inkFaint,
        ),
      ),
    ),
  );

  Widget _block({
    required String title,
    required IconData icon,
    required Widget child,
    Color? accent,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: (accent ?? ShopColors.seed).withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: accent ?? ShopColors.seed),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
          child: child,
        ),
      ],
    ),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            k,
            style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  /// حذف تگ‌های HTML از شرح درخواست (وب ادیتور غنی دارد)
  static String _plain(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
