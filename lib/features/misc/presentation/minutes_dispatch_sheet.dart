// ============================================================
//  ارسال/ارجاع صورتجلسه و بندها
//  • شروع از «بالای صورتجلسه» (itemId = 0) → کل صورتجلسه، و PDF کامل
//    با سربرگ شرکت به‌صورت پیوست به ایمیل/نامه/دستور کار اضافه می‌شود.
//  • شروع از یک بند (itemId > 0) → فقط همان بند ارسال می‌شود و هیچ
//    پیوست PDF کل صورتجلسه اضافه نمی‌گردد.
// ============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../../office_automation/data/email_repository.dart';
import '../../office_automation/models/email_models.dart';
import '../../work_orders/data/work_order_repository.dart';
import '../data/minutes_repository.dart';
import '../models/minutes_models.dart';
import 'misc_style.dart';

enum DispatchChannel { email, innerLetter, outgoingLetter, workOrder }

class MinutesDispatchSheet extends StatefulWidget {
  const MinutesDispatchSheet({
    super.key,
    required this.minutesId,
    this.item,
    this.minutesTitle = '',
    this.users = const [],
  });

  final int minutesId;

  /// اگر مقدار داشته باشد، فقط همان بند ارسال می‌شود.
  final MinutesItem? item;
  final String minutesTitle;
  final List<MinutesUserOption> users;

  @override
  State<MinutesDispatchSheet> createState() => _MinutesDispatchSheetState();
}

class _MinutesDispatchSheetState extends State<MinutesDispatchSheet> {
  late final MinutesRepository _minutesRepo =
      Provider.of<MinutesRepository?>(context, listen: false) ??
      MinutesRepository(context.read<ApiClient>());
  late final EmailRepository _emailRepo =
      Provider.of<EmailRepository?>(context, listen: false) ??
      EmailRepository(context.read<ApiClient>());
  late final WorkOrderRepository _woRepo =
      Provider.of<WorkOrderRepository?>(context, listen: false) ??
      WorkOrderRepository(context.read<ApiClient>());

  DispatchChannel _channel = DispatchChannel.email;

  final _toCtrl = TextEditingController();
  final _ccCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _receiverNameCtrl = TextEditingController();
  final _woTitleCtrl = TextEditingController();
  final _woBodyCtrl = TextEditingController();

  List<EmailAccount> _accounts = const [];
  int _accountId = 0;
  int _woPriority = 2;
  DateTime _woDue = DateTime.now().add(const Duration(days: 3));
  final Set<int> _receiverUserIds = <int>{};
  bool _attachPdf = true; // فقط برای حالت «کل صورتجلسه»
  bool _loadingLookups = true;
  bool _sending = false;

  bool get _isWholeMinutes => widget.item == null;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _ccCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _orgCtrl.dispose();
    _receiverNameCtrl.dispose();
    _woTitleCtrl.dispose();
    _woBodyCtrl.dispose();
    super.dispose();
  }

  /// متن ارسالی — برای بند فقط خودِ بند، برای کل صورتجلسه خلاصهٔ جلسه.
  String get _payloadText {
    final it = widget.item;
    if (it != null) return it.description.trim();
    final parts = <String>[
      'صورتجلسه «${widget.minutesTitle}»',
      if (_subjectCtrl.text.trim().isNotEmpty) _subjectCtrl.text.trim(),
    ];
    return parts.join('\n');
  }

  Future<void> _prepare() async {
    // پیش‌فرض‌ها بر اساس نوع ارسال
    if (_isWholeMinutes) {
      _subjectCtrl.text = 'صورتجلسه «${widget.minutesTitle}»';
      _woTitleCtrl.text = 'اجرای مصوبات صورتجلسه «${widget.minutesTitle}»';
      _woBodyCtrl.text =
          'بر اساس صورتجلسه «${widget.minutesTitle}»، مصوبات جلسه جهت اجرا ابلاغ می‌گردد.';
    } else {
      final it = widget.item!;
      _subjectCtrl.text =
          'بند ${Fa.digits(it.rowNo)} صورتجلسه «${widget.minutesTitle}»';
      _woTitleCtrl.text =
          'اجرای بند ${Fa.digits(it.rowNo)} صورتجلسه «${widget.minutesTitle}»';
      _woBodyCtrl.text = it.description.trim();
      if ((it.responsibleUserId ?? 0) > 0) {
        _receiverUserIds.add(it.responsibleUserId!);
      }
    }
    // حساب‌های ایمیل سازمانی
    try {
      var accs = await _emailRepo.dabirkhaneAccounts();
      if (accs.isEmpty) accs = await _emailRepo.accounts();
      if (mounted) {
        setState(() {
          _accounts = accs;
          _accountId = accs.isEmpty ? 0 : accs.first.id;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingLookups = false);
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      switch (_channel) {
        case DispatchChannel.email:
          await _sendEmail();
        case DispatchChannel.innerLetter:
          await _sendInnerLetter();
        case DispatchChannel.outgoingLetter:
          await _sendOutgoingLetter();
        case DispatchChannel.workOrder:
          await _sendWorkOrder();
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showMessage(context, e.toString(), error: true);
    }
  }

  // ---------------- ایمیل ----------------
  Future<void> _sendEmail() async {
    if (_accountId <= 0) {
      throw ApiException('حساب ایمیل سازمانی فعالی انتخاب نشده است.');
    }
    if (_toCtrl.text.trim().isEmpty) {
      throw ApiException('ایمیل گیرنده را وارد کنید.');
    }
    final body = <String>[
      _payloadText,
      if (_bodyCtrl.text.trim().isNotEmpty) _bodyCtrl.text.trim(),
    ].join('\n\n');

    var attachments = <({String name, Uint8List bytes, String? mimeType})>[];
    if (_isWholeMinutes) {
      // کل صورتجلسه → PDF کامل با سربرگ شرکت پیوست می‌شود
      final pdf = await _minutesRepo.downloadPrintPdf(widget.minutesId);
      attachments = [
        (
          name: 'minutes-${widget.minutesId}.pdf',
          bytes: pdf,
          mimeType: 'application/pdf',
        ),
      ];
    }

    await _emailRepo.send(
      emailAccountId: _accountId,
      to: _toCtrl.text,
      cc: _ccCtrl.text,
      subject: _subjectCtrl.text,
      body: body,
      attachments: attachments,
    );
  }

  // ---------------- نامهٔ داخلی ----------------
  Future<void> _sendInnerLetter() async {
    if (_receiverUserIds.isEmpty) {
      throw ApiException('حداقل یک گیرنده برای نامهٔ داخلی انتخاب کنید.');
    }
    // itemId فقط برای بند مقدار دارد؛ برای کل صورتجلسه 0 → سرور کل را می‌گیرد
    await _minutesRepo.toInnerLetter(
      widget.minutesId,
      itemId: widget.item?.id ?? 0,
      title: _subjectCtrl.text,
      text: _payloadText,
      girande: _receiverUserIds.toList(),
    );
  }

  // ---------------- نامهٔ صادره ----------------
  Future<void> _sendOutgoingLetter() async {
    if (_orgCtrl.text.trim().isEmpty) {
      throw ApiException('نام سازمان گیرنده را وارد کنید.');
    }
    await _minutesRepo.toOutgoingLetter(
      widget.minutesId,
      receiverOrganization: _orgCtrl.text,
      title: _subjectCtrl.text,
      text: _payloadText,
      receiverName: _receiverNameCtrl.text,
    );
  }

  // ---------------- دستور کار ----------------
  Future<void> _sendWorkOrder() async {
    if (_receiverUserIds.isEmpty) {
      throw ApiException('حداقل یک مسئول برای دستور کار انتخاب کنید.');
    }
    final body = <String, dynamic>{
      'title': _woTitleCtrl.text.trim(),
      'description': _payloadText,
      'dueAt': _woDue.toIso8601String(),
      'assigneeUserIds': _receiverUserIds.toList(),
      'sendSms': false,
      'priority': _woPriority,
      'recurrence': 'None',
      'checklistItems': <String>[],
      'tags': <String>['صورتجلسه'],
      'weight': 1,
      'clientRequestId': 'minutes-${widget.minutesId}-${widget.item?.id ?? 0}',
    };
    final res = await _woRepo.save(body);
    final id = (res['id'] as num?)?.toInt();
    if (id != null && id > 0 && _isWholeMinutes) {
      // کل صورتجلسه → PDF کامل به‌عنوان پیوست دستور کار
      try {
        final pdf = await _minutesRepo.downloadPrintPdf(widget.minutesId);
        await _woRepo.upload(
          id,
          null,
          'صورتجلسه-${widget.minutesId}.pdf',
          bytes: pdf,
        );
      } catch (_) {
        // اگر پیوست نشد، خود دستور کار ثبت شده و مانع کار نیست
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = _isWholeMinutes
        ? 'کل صورتجلسه «${widget.minutesTitle}»'
        : 'فقط بند ${Fa.digits(widget.item!.rowNo)}';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: MiscColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MiscColors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ارسال / ارجاع',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _isWholeMinutes
                        ? MiscColors.teal.withValues(alpha: 0.10)
                        : MiscColors.warn.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isWholeMinutes
                            ? Icons.description_rounded
                            : Icons.format_list_numbered_rtl_rounded,
                        size: 15,
                        color: _isWholeMinutes ? MiscColors.teal : MiscColors.warn,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _isWholeMinutes
                              ? '$scope + پیوست PDF کامل'
                              : '$scope (بدون پیوست کل صورتجلسه)',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.7,
                            fontWeight: FontWeight.w700,
                            color: _isWholeMinutes
                                ? MiscColors.teal
                                : MiscColors.warn,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<DispatchChannel>(
                  segments: const [
                    ButtonSegment(
                      value: DispatchChannel.email,
                      icon: Icon(Icons.alternate_email_rounded, size: 16),
                      label: Text('ایمیل', style: TextStyle(fontSize: 11.5)),
                    ),
                    ButtonSegment(
                      value: DispatchChannel.innerLetter,
                      icon: Icon(Icons.mail_outline_rounded, size: 16),
                      label: Text('نامهٔ داخلی', style: TextStyle(fontSize: 11.5)),
                    ),
                    ButtonSegment(
                      value: DispatchChannel.outgoingLetter,
                      icon: Icon(Icons.outbox_outlined, size: 16),
                      label: Text('نامهٔ صادره', style: TextStyle(fontSize: 11.5)),
                    ),
                    ButtonSegment(
                      value: DispatchChannel.workOrder,
                      icon: Icon(Icons.assignment_outlined, size: 16),
                      label: Text('دستور کار', style: TextStyle(fontSize: 11.5)),
                    ),
                  ],
                  selected: {_channel},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _channel = s.first),
                ),
                const SizedBox(height: 14),
                if (_channel == DispatchChannel.email) ..._emailFields(),
                if (_channel == DispatchChannel.innerLetter) ..._innerFields(),
                if (_channel == DispatchChannel.outgoingLetter) ..._outgoingFields(),
                if (_channel == DispatchChannel.workOrder) ..._workOrderFields(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: _sending
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('انصراف'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: MiscColors.teal,
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 17),
                      label: Text(
                        _sending
                            ? 'در حال ارسال…'
                            : _isWholeMinutes
                            ? 'ارسال کل صورتجلسه'
                            : 'ارسال بند ${Fa.digits(widget.item!.rowNo)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _emailFields() {
    if (_loadingLookups) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ];
    }
    if (_accounts.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MiscColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'هیچ حساب ایمیل سازمانی فعالی تعریف نشده است. ابتدا در «پست الکترونیک ← تنظیمات» یک حساب بسازید.',
            style: TextStyle(fontSize: 11.5, color: MiscColors.danger),
          ),
        ),
      ];
    }
    return [
      DropdownButtonFormField<int>(
        initialValue: _accountId == 0 ? null : _accountId,
        decoration: const InputDecoration(
          labelText: 'حساب فرستنده',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final a in _accounts)
            DropdownMenuItem(value: a.id, child: Text(a.title)),
        ],
        onChanged: (v) => setState(() => _accountId = v ?? 0),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _toCtrl,
        keyboardType: TextInputType.emailAddress,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(
          labelText: 'ایمیل گیرنده *',
          hintText: 'info@company.com',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _ccCtrl,
        keyboardType: TextInputType.emailAddress,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(
          labelText: 'رونوشت (CC)',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _subjectCtrl,
        decoration: const InputDecoration(
          labelText: 'موضوع',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _bodyCtrl,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'توضیح تکمیلی (اختیاری)',
          border: const OutlineInputBorder(),
          isDense: true,
          helperText: _isWholeMinutes
              ? 'متن صورتجلسه به‌صورت PDF پیوست می‌شود.'
              : 'متن این بند در بدنهٔ ایمیل قرار می‌گیرد.',
        ),
      ),
      if (_isWholeMinutes) ...[
        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          value: _attachPdf,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text(
            'پیوست PDF کامل صورتجلسه (با سربرگ)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          onChanged: (v) => setState(() => _attachPdf = v),
        ),
      ],
    ];
  }

  List<Widget> _innerFields() {
    return [
      OutlinedButton.icon(
        onPressed: () async {
          final picked = await pickMultiUsersSheet(
            context,
            title: 'گیرندگان نامهٔ داخلی',
            users: widget.users,
            initialSelected: _receiverUserIds.toList(),
          );
          if (picked != null) {
            setState(() {
              _receiverUserIds
                ..clear()
                ..addAll(picked);
            });
          }
        },
        icon: const Icon(Icons.group_add_outlined, size: 18),
        label: Text(
          _receiverUserIds.isEmpty
              ? 'انتخاب گیرندگان *'
              : '${Fa.digits(_receiverUserIds.length)} گیرنده انتخاب شد',
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _subjectCtrl,
        decoration: const InputDecoration(
          labelText: 'عنوان نامه',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MiscColors.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'متن ارسالی:\n$_payloadText',
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, height: 1.7),
        ),
      ),
    ];
  }

  List<Widget> _outgoingFields() {
    return [
      TextField(
        controller: _orgCtrl,
        decoration: const InputDecoration(
          labelText: 'سازمان گیرنده *',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _receiverNameCtrl,
        decoration: const InputDecoration(
          labelText: 'نام گیرنده (اختیاری)',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _subjectCtrl,
        decoration: const InputDecoration(
          labelText: 'موضوع نامه',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MiscColors.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'متن ارسالی:\n$_payloadText',
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, height: 1.7),
        ),
      ),
    ];
  }

  List<Widget> _workOrderFields() {
    return [
      TextField(
        controller: _woTitleCtrl,
        decoration: const InputDecoration(
          labelText: 'عنوان دستور کار *',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _woBodyCtrl,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'شرح',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () async {
          final picked = await pickMultiUsersSheet(
            context,
            title: 'مسئولان اجرای دستور کار',
            users: widget.users,
            initialSelected: _receiverUserIds.toList(),
          );
          if (picked != null) {
            setState(() {
              _receiverUserIds
                ..clear()
                ..addAll(picked);
            });
          }
        },
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: Text(
          _receiverUserIds.isEmpty
              ? 'انتخاب مسئولان *'
              : '${Fa.digits(_receiverUserIds.length)} مسئول انتخاب شد',
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _woPriority,
              decoration: const InputDecoration(
                labelText: 'اولویت',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('کم')),
                DropdownMenuItem(value: 2, child: Text('عادی')),
                DropdownMenuItem(value: 3, child: Text('فوری')),
                DropdownMenuItem(value: 4, child: Text('بحرانی')),
              ],
              onChanged: (v) => setState(() => _woPriority = v ?? 2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showJalaliDatePicker(
                  context,
                  initial: _woDue,
                  title: 'مهلت انجام دستور کار',
                );
                if (picked != null) setState(() => _woDue = picked);
              },
              icon: const Icon(Icons.event_rounded, size: 17),
              label: Text(
                formatJalaliDate(_woDue),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      if (_isWholeMinutes)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'برای کل صورتجلسه، PDF کامل به‌عنوان پیوست دستور کار بارگذاری می‌شود.',
            style: TextStyle(fontSize: 11, color: MiscColors.inkFaint),
          ),
        ),
    ];
  }
}
