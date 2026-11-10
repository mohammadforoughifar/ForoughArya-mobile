import 'dart:typed_data';

// ============================================================
//  فرم ثبت نامه — داخلی / صادره / وارده
//  فیلدها عیناً مطابق DTOهای بک‌اند:
//    AddInnerLetterDto      (نامه داخلی)
//    AddOutgoingLetterDto   (نامه صادره)
//    AddIncomingLetterDto   (نامه وارده)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../../core/widgets/common.dart';
import '../data/office_repository.dart';
import '../models/letter_models.dart';
import '../models/office_common.dart';
import 'office_style.dart';
import 'office_widgets.dart';

class LetterEditorPage extends StatefulWidget {
  const LetterEditorPage({
    super.key,
    required this.kind,
    this.editingId,
    this.prefillTitle,
    this.prefillText,
    this.prefillOrganization,
    this.prefillReceiverName,
    this.attachPdf,
    this.attachPdfName = 'minutess.pdf',
    this.attachRecipients,
    this.sourceMinutesId,
  });

  final LetterKind kind;
  final int? editingId;

  /// پیش‌پر کردن فرم از مبدأ (مثلاً بند صورتجلسه یا کل صورتجلسه)
  final String? prefillTitle;
  final String? prefillText;
  final String? prefillOrganization;
  final String? prefillReceiverName;

  /// PDF کامل صورتجلسه که پس از ثبت نامه به آن پیوست می‌شود
  final Uint8List? attachPdf;
  final String attachPdfName;

  /// کاربرانی که به‌عنوان گیرنده پیش‌انتخاب می‌شوند (UserId)
  final List<int>? attachRecipients;
  final int? sourceMinutesId;

  @override
  State<LetterEditorPage> createState() => _LetterEditorPageState();
}

class _LetterEditorPageState extends State<LetterEditorPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _text = TextEditingController();

  // داخلی / صادره
  String _mahramanegi = 'عادی';
  String _foriat = 'عادی';
  final List<LetterRecipient> _girande = [];
  final List<LetterRecipient> _erjaRecivers = [];
  final List<LetterRecipient> _hamesh = [];
  final List<RelatedLetter> _related = [];

  // صادره
  final _org = TextEditingController();
  final _receiverName = TextEditingController();
  final _receiverTitle = TextEditingController();
  final _receiverAddress = TextEditingController();
  final _externalRef = TextEditingController();
  final _copyTo = TextEditingController();
  final List<LetterRecipient> _signers = [];
  int? _companyId;
  List<Map<String, dynamic>> _companies = const [];
  int _savedId = 0;

  // وارده
  final _ferestande = TextEditingController();
  final _numberLetterVarede = TextEditingController();
  final _deliveryName = TextEditingController();
  final _description = TextEditingController();
  String _typeErsal = 'پست';
  DateTime _dateLetter = DateTime.now();
  DateTime _dateErsal = DateTime.now();
  int _foriatNum = 0;
  int _mahramanegiNum = 0;
  String? _reservedNumber;

  bool _busy = false;
  bool _loadingDetail = false;

  OfficeAutomationRepository get _repo => context.read<OfficeAutomationRepository>();

  @override
  void initState() {
    super.initState();
    if (widget.kind == LetterKind.outgoing) _loadCompanies();
    if (widget.editingId != null) _loadForEdit();
    _applyPrefill();
    if (widget.kind == LetterKind.incoming) _reserve();
  }

  @override
  void dispose() {
    for (final c in [
      _title, _text, _org, _receiverName, _receiverTitle, _receiverAddress,
      _externalRef, _copyTo, _ferestande, _numberLetterVarede, _deliveryName, _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// پرکردن فیلدها از دادهٔ مبدأ و انتخاب گیرندگان پیش‌فرض
  Future<void> _applyPrefill() async {
    final title = widget.prefillTitle?.trim() ?? '';
    final text = widget.prefillText?.trim() ?? '';
    if (title.isNotEmpty) _title.text = title;
    if (text.isNotEmpty) _text.text = text;
    if ((widget.prefillOrganization ?? '').trim().isNotEmpty) {
      _org.text = widget.prefillOrganization!.trim();
    }
    if ((widget.prefillReceiverName ?? '').trim().isNotEmpty) {
      _receiverName.text = widget.prefillReceiverName!.trim();
    }
    final ids = widget.attachRecipients ?? const <int>[];
    if (ids.isEmpty) return;
    // نام کاربران برای نمایش در لیست گیرندگان
    try {
      final all = await _repo.recipients(widget.kind);
      final picked = all.where((u) => ids.contains(u.userId)).toList();
      if (picked.isEmpty) return;
      if (!mounted) return;
      setState(() {
        if (widget.kind == LetterKind.outgoing) {
          _signers.addAll(picked);
        } else {
          _girande.addAll(picked);
        }
      });
    } catch (_) {}
  }

  Future<void> _reserve() async {
    try {
      final n = await _repo.reserveNumber(OfficeConst.sourceIncoming);
      if (mounted) setState(() => _reservedNumber = n);
    } catch (_) {}
  }

  Future<void> _loadCompanies() async {
    try {
      _companies = await _repo.companies();
    } catch (_) {
      _companies = const [];
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadForEdit() async {
    setState(() => _loadingDetail = true);
    try {
      if (widget.kind == LetterKind.inner) {
        final d = await _repo.innerDetail(widget.editingId!);
        _title.text = d.title;
        _text.text = d.text ?? '';
        _mahramanegi = d.mahramanegi;
        _foriat = d.foriat;
        _girande.addAll(d.girande);
        _erjaRecivers.addAll(d.erja);
        _hamesh.addAll(d.hamesh);
        _related.addAll(d.relatedLetters);
      } else if (widget.kind == LetterKind.outgoing) {
        final d = await _repo.outgoingDetail(widget.editingId!);
        _title.text = d.title;
        _text.text = d.text ?? '';
        _mahramanegi = d.mahramanegi;
        _foriat = d.foriat;
        _org.text = d.receiverOrganization;
        _receiverName.text = d.receiverName ?? '';
        _receiverTitle.text = d.receiverTitle ?? '';
        _receiverAddress.text = d.receiverAddress ?? '';
        _externalRef.text = d.externalRefNumber ?? '';
        _copyTo.text = d.copyTo ?? '';
        _companyId = d.companyId;
        _girande.addAll(d.girande);
        _erjaRecivers.addAll(d.erja);
        _hamesh.addAll(d.hamesh);
        _related.addAll(d.relatedLetters);
      } else {
        final j = await _repo.incomingDetailRaw(widget.editingId!);
        _title.text = pickStr(j, ['title', 'Title']);
        _description.text = pickStr(j, ['description', 'Description']);
        _ferestande.text = pickStr(j, ['ferestande', 'Ferestande']);
        _numberLetterVarede.text = pickStr(j, ['numberLetterVarede', 'NumberLetterVarede']);
        _deliveryName.text = pickStr(j, ['deliveryName', 'DeliveryName']);
        _typeErsal = pickStr(j, ['typeErsal', 'TypeErsal'], 'پست');
        _dateLetter = pickDate(j, ['date', 'Date']) ?? DateTime.now();
        _dateErsal = pickDate(j, ['dateErsal', 'DateErsal']) ?? DateTime.now();
        _foriatNum = pickInt(j, ['foriat', 'Foriat']);
        _mahramanegiNum = pickInt(j, ['mahramanegi', 'Mahramanegi']);
      }
    } catch (e) {
      if (mounted) showMessage(context, 'دریافت اطلاعات نامه انجام نشد: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  // ------------------------------------------------------------
  //  ذخیره
  // ------------------------------------------------------------

  Map<String, dynamic> _innerBody() => {
    'letterId': widget.editingId ?? 0,
    'title': _title.text.trim(),
    'text': _text.text.trim(),
    'mahramanegi': _mahramanegi,
    'foriat': _foriat,
    'reciversGirande': _girande.map((e) => e.userId).toList(),
    'reciversErja': _erjaRecivers.map((e) => e.userId).toList(),
    'reciversHamesh': _hamesh.map((e) => e.userId).toList(),
    'relatedLetters': _related.map((e) => e.toJson()).toList(),
    'groupsGirande': <int>[],
    'groupsErja': <int>[],
    'groupsHamesh': <int>[],
  };

  Map<String, dynamic> _outgoingBody() => {
    'letterId': widget.editingId ?? 0,
    'title': _title.text.trim(),
    'text': _text.text.trim(),
    'mahramanegi': _mahramanegi,
    'foriat': _foriat,
    'receiverOrganization': _org.text.trim(),
    'receiverName': _receiverName.text.trim(),
    'receiverTitle': _receiverTitle.text.trim(),
    'receiverAddress': _receiverAddress.text.trim(),
    'copyTo': _copyTo.text.trim(),
    'externalRefNumber': _externalRef.text.trim(),
    'companyId': _companyId,
    'reciversGirande': _girande.map((e) => e.userId).toList(),
    'reciversErja': _erjaRecivers.map((e) => e.userId).toList(),
    'reciversHamesh': _hamesh.map((e) => e.userId).toList(),
    'groupsGirande': <int>[],
    'groupsErja': <int>[],
    'groupsHamesh': <int>[],
    'relatedLetters': _related.map((e) => e.toJson()).toList(),
    'signerUserIds': _signers.map((e) => e.userId).toList(),
    'signerGroupIds': <int>[],
    'copyTos': <Map<String, dynamic>>[],
  };

  Map<String, dynamic> _incomingBody() => {
    'title': _title.text.trim(),
    'ferestande': _ferestande.text.trim(),
    'numberLetterVarede': _numberLetterVarede.text.trim(),
    'deliveryName': _deliveryName.text.trim(),
    'description': _description.text.trim(),
    'typeErsal': _typeErsal,
    'date': _dateLetter.toIso8601String(),
    'dateErsal': _dateErsal.toIso8601String(),
    'foriat': _foriatNum,
    'mahramanegi': _mahramanegiNum,
  };

  Future<void> _save({bool asDraft = false}) async {
    if (!asDraft && !(_form.currentState?.validate() ?? false)) return;
    if (!asDraft) {
      if (widget.kind == LetterKind.inner && _girande.isEmpty && _erjaRecivers.isEmpty && _hamesh.isEmpty) {
        showMessage(context, 'حداقل یک گیرنده انتخاب کنید.', error: true);
        return;
      }
      if (widget.kind == LetterKind.outgoing && _org.text.trim().isEmpty) {
        showMessage(context, 'نام سازمان مقصد الزامی است.', error: true);
        return;
      }
      if (widget.kind == LetterKind.incoming && _ferestande.text.trim().isEmpty) {
        showMessage(context, 'نام فرستنده الزامی است.', error: true);
        return;
      }
    }

    setState(() => _busy = true);
    try {
      if (asDraft) {
        await _repo.saveDraft(widget.kind, {
          'pishnevisId': widget.editingId ?? 0,
          'title': _title.text.trim(),
          'text': _text.text.trim(),
          if (widget.kind == LetterKind.outgoing) 'receiverOrganization': _org.text.trim(),
          if (widget.kind == LetterKind.outgoing) 'receiverName': _receiverName.text.trim(),
        });
        if (mounted) {
          showMessage(context, 'پیش‌نویس ذخیره شد.');
          Navigator.pop(context, true);
        }
        return;
      }

      switch (widget.kind) {
        case LetterKind.inner:
          if (widget.editingId != null) {
            await _repo.editInner(widget.editingId!, _innerBody());
            _savedId = widget.editingId!;
          } else {
            _savedId = await _repo.createInner(_innerBody());
          }
        case LetterKind.outgoing:
          if (widget.editingId != null) {
            await _repo.editOutgoing(widget.editingId!, _outgoingBody());
            _savedId = widget.editingId!;
          } else {
            _savedId = await _repo.createOutgoing(_outgoingBody());
          }
        case LetterKind.incoming:
          if (widget.editingId != null) {
            await _repo.editIncoming(widget.editingId!, _incomingBody());
            _savedId = widget.editingId!;
          } else {
            final id = await _repo.createIncoming(_incomingBody());
            _savedId = id;
            if (id > 0) {
              try {
                await _repo.finalizeIncoming(id);
              } catch (_) {}
            }
          }
      }
      // پیوست PDF کامل صورتجلسه به نامهٔ ثبت‌شده (فقط در حالت «کل صورتجلسه»)
      if (!asDraft && widget.attachPdf != null && _savedId > 0) {
        try {
          await _repo.uploadAttachment(
            widget.kind,
            _savedId,
            '',
            widget.attachPdfName,
            bytes: widget.attachPdf,
          );
        } catch (e) {
          if (mounted) {
            showMessage(
              context,
              'نامه ثبت شد ولی پیوست PDF صورتجلسه بارگذاری نشد: $e',
              error: true,
            );
          }
        }
      }
      if (mounted) {
        showMessage(context, widget.editingId != null ? 'نامه ویرایش شد.' : 'نامه ثبت شد.');
        Navigator.pop(context, _savedId > 0 ? _savedId : true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showMessage(context, e.message, error: true);
        setState(() => _busy = false);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'ثبت نامه انجام نشد: $e', error: true);
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickRecipients({
    required String title,
    required List<LetterRecipient> target,
    Future<List<LetterRecipient>> Function()? loader,
  }) async {
    final selected = await pickRecipients(
      context,
      title: title,
      loadUsers: loader ?? () => _repo.recipients(widget.kind),
      loadGroups: () => _repo.groups(widget.kind),
      initial: target,
    );
    if (selected == null || !mounted) return;
    setState(() {
      target
        ..clear()
        ..addAll(selected);
    });
  }

  /// انتخاب نامه برای عطف/پیرو — از مسیر GET /pick
  Future<void> _pickRelated() async {
    final kindName = await showDialog<RelatedPickResult>(
      context: context,
      builder: (_) => const _RelatedPickDialog(),
    );
    if (kindName == null || !mounted) return;

    final chosen = await showModalBottomSheet<LetterListItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LetterPickerSheet(
        title: 'انتخاب نامه برای ${kindName.kind == 2 ? 'عطف' : 'پیرو'}',
        loader: (q) => _repo.pickLetters(widget.kind, search: q),
      ),
    );
    if (chosen == null) return;
    setState(() {
      _related.add(RelatedLetter(
        kind: kindName.kind,
        letterId: chosen.letterId,
        number: chosen.letterNumber,
        title: chosen.title,
        isSent: kindName.isSent,
      ));
    });
  }

  // ------------------------------------------------------------
  //  ساخت رابط
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editingId != null;
    final accent = OfficeColors.forKind(widget.kind);
    return Scaffold(
      backgroundColor: OfficeColors.bg,
      appBar: AppBar(
        backgroundColor: OfficeColors.deep,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${isEdit ? 'ویرایش' : 'ثبت'} ${widget.kind.label}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [OfficeColors.deep, accent],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        actions: [
          if (!isEdit)
            TextButton.icon(
              onPressed: _busy ? null : () => _save(asDraft: true),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text(
                'پیش‌نویس',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _loadingDetail
          ? const LoadingView(label: 'در حال دریافت…')
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                children: [
                  _card(
                    title: 'مشخصات نامه',
                    icon: Icons.description_outlined,
                    children: [
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'عنوان نامه *'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'عنوان نامه الزامی است' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _text,
                        maxLines: widget.kind == LetterKind.incoming ? 3 : 7,
                        decoration: const InputDecoration(
                          labelText: 'متن نامه',
                          alignLabelWithHint: true,
                        ),
                      ),
                      if (widget.kind != LetterKind.incoming) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _mahramanegi,
                                decoration: const InputDecoration(labelText: 'محرمانگی'),
                                items: OfficeConst.mahramanegi
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (v) => setState(() => _mahramanegi = v ?? 'عادی'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _foriat,
                                decoration: const InputDecoration(labelText: 'فوریت'),
                                items: OfficeConst.foriat
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (v) => setState(() => _foriat = v ?? 'عادی'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  if (widget.kind == LetterKind.outgoing) _outgoingFields(),
                  if (widget.kind == LetterKind.incoming) _incomingFields(),
                  if (widget.kind != LetterKind.incoming) ...[
                    _recipientsCard(),
                    _relatedCard(),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: .32),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _save(),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, size: 19),
                      label: Text(
                        isEdit ? 'ذخیره تغییرات' : 'ثبت نامه',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? color,
  }) => OfficeCard(
    title: title,
    icon: icon,
    color: color ?? OfficeColors.forKind(widget.kind),
    children: children,
  );

  Widget _recipientsCard() => _card(
    title: 'گیرندگان',
    icon: Icons.people_outline,
    children: [
      _recipientBlock(
        label: 'گیرندهٔ اصلی',
        list: _girande,
        onPick: () => _pickRecipients(title: 'گیرندهٔ اصلی', target: _girande),
        color: const Color(0xff2a6bd4),
      ),
      _recipientBlock(
        label: 'ارجاع (جهت اقدام)',
        list: _erjaRecivers,
        onPick: () => _pickRecipients(title: 'گیرندگان ارجاع', target: _erjaRecivers),
        color: const Color(0xff1a7f37),
      ),
      _recipientBlock(
        label: 'هامش (رونوشت)',
        list: _hamesh,
        onPick: () => _pickRecipients(title: 'گیرندگان هامش', target: _hamesh),
        color: const Color(0xff6b4fd8),
      ),
      if (widget.kind == LetterKind.outgoing)
        _recipientBlock(
          label: 'امضاکنندگان (به ترتیب انتخاب)',
          list: _signers,
          onPick: () async {
            final selected = await pickRecipients(
              context,
              title: 'انتخاب امضاکنندگان',
              loadUsers: () => _repo.availableSigners(),
              initial: _signers,
            );
            if (selected != null) {
              setState(() => _signers
                ..clear()
                ..addAll(selected));
            }
          },
          color: const Color(0xffe07b00),
        ),
    ],
  );

  Widget _recipientBlock({
    required String label,
    required List<LetterRecipient> list,
    required VoidCallback onPick,
    required Color color,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label (${Fa.digits(list.length)})',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('انتخاب', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ],
        ),
        if (list.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: list
                .map((r) => Chip(
                      label: Text(r.label, style: const TextStyle(fontSize: 11.5)),
                      onDeleted: () => setState(() => list.remove(r)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          )
        else
          Text(
            'انتخاب نشده',
            style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade400),
          ),
      ],
    ),
  );

  Widget _relatedCard() => _card(
    title: 'نامه‌های مرتبط (عطف / پیرو)',
    icon: Icons.link,
    children: [
      if (_related.isEmpty)
        Text(
          'نامه‌ای مرتبط نشده است.',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
        )
      else
        ..._related.map(
          (r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                OfficeChip(
                  label: r.kindLabel,
                  color: r.kind == 2 ? const Color(0xff6b4fd8) : const Color(0xff2a6bd4),
                  dense: true,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(r.title, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  onPressed: () => setState(() => _related.remove(r)),
                  icon: const Icon(Icons.close, size: 17),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _pickRelated,
          icon: const Icon(Icons.add_link, size: 17),
          label: const Text('افزودن عطف/پیرو', style: TextStyle(fontSize: 12)),
        ),
      ),
    ],
  );

  // -------------------- فیلدهای صادره --------------------

  Widget _outgoingFields() => _card(
    title: 'گیرندهٔ بیرونی',
    icon: Icons.apartment,
    children: [
      TextFormField(
        controller: _org,
        decoration: const InputDecoration(labelText: 'سازمان / شرکت مقصد *'),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _receiverName,
              decoration: const InputDecoration(labelText: 'نام شخص گیرنده'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _receiverTitle,
              decoration: const InputDecoration(labelText: 'سمت گیرنده'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _receiverAddress,
        decoration: const InputDecoration(labelText: 'آدرس / توضیحات مقصد'),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _externalRef,
              decoration: const InputDecoration(labelText: 'شمارهٔ نامهٔ طرف مقابل'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _copyTo,
              decoration: const InputDecoration(labelText: 'رونوشت (متن آزاد)'),
            ),
          ),
        ],
      ),
      if (_companies.isNotEmpty) ...[
        const SizedBox(height: 10),
        DropdownButtonFormField<int?>(
          initialValue: _companyId,
          decoration: const InputDecoration(labelText: 'شرکت صادرکننده (سربرگ چاپ)'),
          items: _companies
              .map((c) => DropdownMenuItem<int?>(
                    value: pickIntN(c, ['id', 'Id', 'companyId']),
                    child: Text(
                      pickStr(c, ['name', 'Name', 'companyName', 'title'], 'شرکت'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _companyId = v),
        ),
      ],
    ],
  );

  // -------------------- فیلدهای وارده --------------------

  Widget _incomingFields() => _card(
    title: 'اطلاعات نامهٔ مبدأ (دبیرخانه)',
    icon: Icons.south_west,
    children: [
      if (_reservedNumber != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OfficeChip(
            label: 'شمارهٔ اندیکاتور رزروشده: ${Fa.digits(_reservedNumber)}',
            color: const Color(0xff1a7f37),
            icon: Icons.confirmation_number_outlined,
          ),
        ),
      TextFormField(
        controller: _ferestande,
        decoration: const InputDecoration(labelText: 'فرستنده (سازمان/شخص مبدأ) *'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _numberLetterVarede,
        decoration: const InputDecoration(labelText: 'شمارهٔ نامهٔ مبدأ'),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _mahramanegiNum,
              decoration: const InputDecoration(labelText: 'محرمانگی'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('عادی')),
                DropdownMenuItem(value: 1, child: Text('محرمانه')),
                DropdownMenuItem(value: 2, child: Text('خیلی محرمانه')),
                DropdownMenuItem(value: 3, child: Text('سری')),
              ],
              onChanged: (v) => setState(() => _mahramanegiNum = v ?? 0),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _foriatNum,
              decoration: const InputDecoration(labelText: 'فوریت'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('عادی')),
                DropdownMenuItem(value: 1, child: Text('فوری')),
                DropdownMenuItem(value: 2, child: Text('خیلی فوری')),
                DropdownMenuItem(value: 3, child: Text('آنی')),
              ],
              onChanged: (v) => setState(() => _foriatNum = v ?? 0),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _typeErsal,
        decoration: const InputDecoration(labelText: 'روش ارسال'),
        items: const ['پست', 'پیک/دستی', 'ایمیل', 'نمابر', 'ایتا', 'اتوماسیون']
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => setState(() => _typeErsal = v ?? 'پست'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _deliveryName,
        decoration: const InputDecoration(labelText: 'تحویل‌گیرنده / تحویل‌دهنده'),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final d = await _pickJalali(context, _dateLetter);
                if (d != null) setState(() => _dateLetter = d);
              },
              icon: const Icon(Icons.event, size: 17),
              label: Text('تاریخ نامه: ${_jalali(_dateLetter)}',
                  style: const TextStyle(fontSize: 11.5)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final d = await _pickJalali(context, _dateErsal);
                if (d != null) setState(() => _dateErsal = d);
              },
              icon: const Icon(Icons.login, size: 17),
              label: Text('تاریخ ثبت: ${_jalali(_dateErsal)}',
                  style: const TextStyle(fontSize: 11.5)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _description,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'توضیحات / خلاصه نامه',
          alignLabelWithHint: true,
        ),
      ),
    ],
  );

  String _jalali(DateTime d) {
    final j = Jalali.fromDateTime(d);
    return Fa.digits(
      '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}',
    );
  }

  Future<DateTime?> _pickJalali(BuildContext context, DateTime initial) =>
      showJalaliDatePicker(
        context,
        initial: initial,
        title: 'انتخاب تاریخ (شمسی)',
      );
}

// ============================================================
//  کمکی‌های انتخاب نامه و نوع عطف/پیرو
// ============================================================

class RelatedPickResult {
  const RelatedPickResult({required this.kind, required this.isSent});

  /// 1 = پیرو، 2 = عطف
  final int kind;
  final bool isSent;
}

class _RelatedPickDialog extends StatefulWidget {
  const _RelatedPickDialog();

  @override
  State<_RelatedPickDialog> createState() => _RelatedPickDialogState();
}

class _RelatedPickDialogState extends State<_RelatedPickDialog> {
  int _kind = 2;
  bool _isSent = true;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('افزودن نامهٔ مرتبط'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 2, label: Text('عطف')),
            ButtonSegment(value: 1, label: Text('پیرو')),
          ],
          selected: {_kind},
          onSelectionChanged: (v) => setState(() => _kind = v.first),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          value: _isSent,
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('از نامه‌های ارسالی من', style: TextStyle(fontSize: 12.5)),
          onChanged: (v) => setState(() => _isSent = v),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          RelatedPickResult(kind: _kind, isSent: _isSent),
        ),
        child: const Text('ادامه'),
      ),
    ],
  );
}

/// برگهٔ انتخاب یک نامه از کارتابل (GET /pick)
class _LetterPickerSheet extends StatefulWidget {
  const _LetterPickerSheet({required this.title, required this.loader});

  final String title;
  final Future<Paged<LetterListItem>> Function(String? search) loader;

  @override
  State<_LetterPickerSheet> createState() => _LetterPickerSheetState();
}

class _LetterPickerSheetState extends State<_LetterPickerSheet> {
  List<LetterListItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String? q]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.loader(q);
      if (mounted) {
        setState(() {
          _items = r.items;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .8,
    maxChildSize: .95,
    builder: (context, scroll) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'جست‌وجوی عنوان یا شماره…',
              prefixIcon: Icon(Icons.search, size: 19),
              isDense: true,
            ),
            onSubmitted: (v) => _load(v.trim()),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorView(message: _error!, onRetry: () => _load())
                  : _items.isEmpty
                      ? const EmptyView(message: 'نامه‌ای پیدا نشد.')
                      : ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final it = _items[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.mail_outline, size: 20),
                              title: Text(it.title, style: const TextStyle(fontSize: 13)),
                              subtitle: Text(
                                '${it.letterNumber.isNotEmpty ? 'شماره ${Fa.digits(it.letterNumber)} • ' : ''}${Fa.date(it.date?.toIso8601String(), time: false)}',
                                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500),
                              ),
                              onTap: () => Navigator.pop(context, it),
                            );
                          },
                        ),
        ),
      ],
    ),
  );
}
