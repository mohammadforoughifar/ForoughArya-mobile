// ============================================================
//  صفحهٔ نگارش و ارسال ایمیل (multipart + پیوست تا ۲۰MB + پیش‌نویس)
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/email_repository.dart';
import '../models/email_models.dart';
import 'email_page.dart';
import 'office_style.dart';

class EmailComposePage extends StatefulWidget {
  const EmailComposePage({
    super.key,
    required this.scope,
    required this.accounts,
    this.replyTo,
    this.replyAll = false,
    this.forwardOf,
    this.draft,
  });

  final EmailScope scope;
  final List<EmailAccount> accounts;
  final EmailMessageDetail? replyTo;
  final bool replyAll;
  final EmailMessageDetail? forwardOf;
  final EmailDraft? draft;

  @override
  State<EmailComposePage> createState() => _EmailComposePageState();
}

class _EmailComposePageState extends State<EmailComposePage> {
  static const _maxAttachmentBytes = 20 * 1024 * 1024; // 20 MB

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _toCtrl;
  late final TextEditingController _ccCtrl;
  late final TextEditingController _subCtrl;
  late final TextEditingController _bodyCtrl;

  List<EmailAccount> _accounts = const [];
  int? _accountId;
  bool _sending = false;
  final _files = <({String name, Uint8List bytes, String? mimeType})>[];

  EmailRepository get _repo => context.read<EmailRepository>();

  @override
  void initState() {
    super.initState();
    _accounts = List<EmailAccount>.from(widget.accounts);
    final d = widget.draft;
    final rep = widget.replyTo;
    final fwd = widget.forwardOf;

    String initTo = '';
    String initCc = '';
    String initSub = '';
    String initBody = '';
    int? preferredAccount;

    if (d != null) {
      initTo = d.to;
      initCc = d.cc;
      initSub = d.subject;
      initBody = d.body;
      preferredAccount = d.accountId > 0 ? d.accountId : null;
    } else if (rep != null) {
      initTo = rep.replyAddress;
      if (widget.replyAll && rep.cc.trim().isNotEmpty) {
        initCc = rep.cc.trim();
      }
      initSub = replySubject(rep.subject);
      initBody = quotedBody(rep);
      preferredAccount = rep.accountId > 0 ? rep.accountId : null;
    } else if (fwd != null) {
      initSub = forwardSubject(fwd.subject);
      initBody = quotedBody(fwd);
      preferredAccount = fwd.accountId > 0 ? fwd.accountId : null;
    }

    _toCtrl = TextEditingController(text: initTo);
    _ccCtrl = TextEditingController(text: initCc);
    _subCtrl = TextEditingController(text: initSub);
    _bodyCtrl = TextEditingController(text: initBody);

    if (preferredAccount != null && _accounts.any((a) => a.id == preferredAccount)) {
      _accountId = preferredAccount;
    } else if (_accounts.isNotEmpty) {
      _accountId = _accounts.first.id;
    } else {
      _loadAccountsIfEmpty(preferredAccount);
    }
  }

  Future<void> _loadAccountsIfEmpty(int? preferred) async {
    try {
      final all = await _repo.accounts();
      if (!mounted) return;
      final scoped = all
          .where((a) => widget.scope.isPersonal ? !a.isDabirkhane : a.isDabirkhane)
          .toList();
      final list = scoped.isNotEmpty ? scoped : all;
      setState(() {
        _accounts = list;
        if (preferred != null && list.any((a) => a.id == preferred)) {
          _accountId = preferred;
        } else if (list.isNotEmpty) {
          _accountId = list.first.id;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _ccCtrl.dispose();
    _subCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _toCtrl.text.trim().isNotEmpty ||
      _subCtrl.text.trim().isNotEmpty ||
      _bodyCtrl.text.trim().isNotEmpty;

  int get _totalBytes => _files.fold<int>(0, (s, f) => s + f.bytes.length);

  String? _guessMime(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'txt' => 'text/plain',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'zip' => 'application/zip',
      _ => null,
    };
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty || !mounted) return;
    var runningTotal = _totalBytes;
    final added = <({String name, Uint8List bytes, String? mimeType})>[];
    for (final f in files) {
      if (f.path == null) continue;
      final bytes = await File(f.path!).readAsBytes();
      if (runningTotal + bytes.length > _maxAttachmentBytes) {
        if (mounted) {
          showMessage(context, 'مجموع حجم پیوست‌ها نباید بیش از ۲۰ مگابایت باشد.', error: true);
        }
        break;
      }
      runningTotal += bytes.length;
      added.add((name: f.name, bytes: bytes, mimeType: _guessMime(f.name)));
    }
    if (added.isNotEmpty && mounted) {
      setState(() => _files.addAll(added));
    }
  }

  String _toHtml(String plain) {
    final escaped = const HtmlEscape().convert(plain).replaceAll('\n', '<br>');
    return '<div dir="rtl" style="font-family:tahoma,sans-serif;line-height:1.8">$escaped</div>';
  }

  EmailDraft _buildDraft() => EmailDraft(
    localId: widget.draft?.localId ?? const Uuid().v4(),
    accountId: _accountId ?? 0,
    to: _toCtrl.text.trim(),
    cc: _ccCtrl.text.trim(),
    subject: _subCtrl.text.trim(),
    body: _bodyCtrl.text,
    createdAt: DateTime.now(),
  );

  void _saveDraft() {
    Navigator.pop(context, _buildDraft());
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_accountId == null) {
      showMessage(context, 'ابتدا یک حساب ایمیل انتخاب یا تعریف کنید.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.send(
        emailAccountId: _accountId!,
        to: _toCtrl.text.trim(),
        cc: _ccCtrl.text.trim(),
        subject: _subCtrl.text.trim(),
        body: _toHtml(_bodyCtrl.text),
        attachments: _files,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'خطا در ارسال ایمیل: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmClose() async {
    if (!_hasContent || _sending) {
      Navigator.pop(context);
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ذخیرهٔ پیش‌نویس؟'),
        content: const Text('تغییرات ایمیل به‌صورت پیش‌نویس ذخیره شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            child: const Text('دور ریختن'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'cancel'),
            child: const Text('ادامهٔ ویرایش'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'save'),
            child: const Text('ذخیرهٔ پیش‌نویس'),
          ),
        ],
      ),
    );
    if (!mounted || action == null || action == 'cancel') return;
    if (action == 'save') {
      _saveDraft();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.scope.color;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmClose();
      },
      child: Scaffold(
        backgroundColor: OfficeColors.bg,
        appBar: AppBar(
          backgroundColor: OfficeColors.deep,
          foregroundColor: Colors.white,
          title: Text(
            'ایمیل جدید (${widget.scope.label})',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          actions: [
            TextButton.icon(
              onPressed: _sending ? null : _saveDraft,
              icon: const Icon(Icons.drafts_outlined, size: 17, color: Colors.white70),
              label: const Text(
                'پیش‌نویس',
                style: TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: const Text('ارسال'),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              OfficeCard(
                title: 'حساب فرستنده',
                icon: Icons.alternate_email,
                color: accent,
                children: [
                  if (_accounts.isEmpty)
                    const Text(
                      'هیچ حساب فعالی یافت نشد. از بخش تنظیمات حساب ایمیل اضافه کنید.',
                      style: TextStyle(fontSize: 12.5, color: OfficeColors.danger),
                    )
                  else
                    Column(
                      children: [
                        for (final a in _accounts)
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _accountId = a.id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _accountId == a.id
                                    ? accent.withValues(alpha: .09)
                                    : OfficeColors.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _accountId == a.id ? accent : OfficeColors.line,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _accountId == a.id
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 19,
                                    color: _accountId == a.id
                                        ? accent
                                        : Colors.blueGrey.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      a.displayName.isNotEmpty
                                          ? '${a.displayName} (${a.address})'
                                          : a.address,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              OfficeCard(
                title: 'گیرندگان و موضوع',
                icon: Icons.mail_outline,
                color: accent,
                children: [
                  TextFormField(
                    controller: _toCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'گیرنده (To)',
                      hintText: 'recipient@example.com',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'وارد کردن آدرس گیرنده الزامی است.';
                      if (!s.contains('@')) return 'آدرس ایمیل گیرنده معتبر نیست.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _ccCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رونوشت (CC — اختیاری)',
                      hintText: 'cc1@example.com, cc2@example.com',
                      prefixIcon: Icon(Icons.group_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _subCtrl,
                    decoration: const InputDecoration(
                      labelText: 'موضوع ایمیل',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'موضوع ایمیل را وارد کنید.' : null,
                  ),
                ],
              ),
              OfficeCard(
                title: 'متن پیام',
                icon: Icons.edit_note_rounded,
                color: accent,
                children: [
                  TextFormField(
                    controller: _bodyCtrl,
                    minLines: 7,
                    maxLines: 16,
                    decoration: const InputDecoration(
                      hintText: 'متن ایمیل را بنویسید...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              OfficeCard(
                title: 'پیوست‌ها (حداکثر ۲۰ مگابایت)',
                icon: Icons.attach_file_rounded,
                color: OfficeColors.seed,
                trailing: TextButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('افزودن فایل'),
                ),
                children: [
                  if (_files.isEmpty)
                    Text(
                      'فایلی پیوست نشده است.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < _files.length; i++)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.insert_drive_file_outlined,
                              color: OfficeColors.seed,
                            ),
                            title: Text(
                              _files[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${Fa.digits((_files[i].bytes.length / 1024).round())} کیلوبایت',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: OfficeColors.danger,
                              ),
                              onPressed: () => setState(() => _files.removeAt(i)),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
