// ============================================================
//  تنظیمات حساب‌های ایمیل (سازمانی و شخصی + تست SMTP/IMAP)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/email_repository.dart';
import '../models/email_models.dart';
import 'office_style.dart';

class EmailSettingsPage extends StatefulWidget {
  const EmailSettingsPage({super.key});

  @override
  State<EmailSettingsPage> createState() => _EmailSettingsPageState();
}

class _EmailSettingsPageState extends State<EmailSettingsPage> {
  EmailRepository get _repo => context.read<EmailRepository>();

  final _accounts = <EmailAccount>[];
  bool _loading = true;
  String? _error;
  bool _changed = false;
  final _syncingIds = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.accounts();
      if (!mounted) return;
      setState(() {
        _accounts
          ..clear()
          ..addAll(list);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'خطا در دریافت حساب‌ها: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({EmailAccount? account, bool corporate = false}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AccountSheet(account: account, defaultCorporate: corporate),
    );
    if (saved == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _syncOne(EmailAccount a) async {
    if (_syncingIds.contains(a.id)) return;
    setState(() => _syncingIds.add(a.id));
    try {
      final res = await _repo.syncAccount(a.id);
      if (!mounted) return;
      _changed = true;
      showMessage(
        context,
        res.message.isNotEmpty
            ? res.message
            : 'همگام‌سازی انجام شد (${Fa.digits(res.newCount)} ایمیل جدید).',
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _syncingIds.remove(a.id));
    }
  }

  Future<void> _deleteOne(EmailAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف حساب ایمیل'),
        content: Text('حساب «${a.address}» حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: OfficeColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteAccount(a.id);
      if (!mounted) return;
      _changed = true;
      showMessage(context, 'حساب ایمیل حذف شد.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final corporate = _accounts.where((a) => a.isDabirkhane).toList();
    final personal = _accounts.where((a) => !a.isDabirkhane).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: OfficeColors.bg,
        appBar: AppBar(
          backgroundColor: OfficeColors.deep,
          foregroundColor: Colors.white,
          title: const Text(
            'حساب‌های ایمیل',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'بروزرسانی',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: OfficeColors.email,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('افزودن حساب'),
        ),
        body: _loading
            ? const LoadingView(label: 'در حال دریافت حساب‌ها...')
            : _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 88),
                children: [
                  OfficeCard(
                    title: 'حساب‌های سازمانی (دبیرخانه)',
                    icon: Icons.account_balance_outlined,
                    color: OfficeColors.email,
                    trailing: TextButton.icon(
                      onPressed: () => _openEditor(corporate: true),
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('افزودن'),
                    ),
                    children: [
                      if (corporate.isEmpty)
                        Text(
                          'حساب سازمانی ثبت نشده است.',
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
                        )
                      else
                        for (final a in corporate) _buildTile(a, OfficeColors.email),
                    ],
                  ),
                  OfficeCard(
                    title: 'حساب‌های شخصی من',
                    icon: Icons.person_outline,
                    color: OfficeColors.emailPersonal,
                    trailing: TextButton.icon(
                      onPressed: () => _openEditor(corporate: false),
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('افزودن'),
                    ),
                    children: [
                      if (personal.isEmpty)
                        Text(
                          'حساب شخصی ثبت نشده است.',
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400),
                        )
                      else
                        for (final a in personal)
                          _buildTile(a, OfficeColors.emailPersonal),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTile(EmailAccount a, Color accent) {
    final syncing = _syncingIds.contains(a.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OfficeColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OfficeColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.alternate_email, size: 19, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                Text(
                  a.address,
                  style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade600),
                ),
                Text(
                  '${Fa.digits(a.messageCount)} پیام · IMAP ${a.imap}:${Fa.digits(a.imapPort)}',
                  style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade400),
                ),
              ],
            ),
          ),
          if (syncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              tooltip: 'همگام‌سازی',
              icon: Icon(Icons.sync, size: 19, color: accent),
              onPressed: () => _syncOne(a),
            ),
          IconButton(
            tooltip: 'ویرایش',
            icon: const Icon(Icons.edit_outlined, size: 19),
            onPressed: () => _openEditor(account: a, corporate: a.isDabirkhane),
          ),
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline, size: 19, color: OfficeColors.danger),
            onPressed: () => _deleteOne(a),
          ),
        ],
      ),
    );
  }
}

class _Preset {
  const _Preset(
    this.label,
    this.smtp,
    this.smtpPort,
    this.imap,
    this.imapPort, {
    this.hint,
  });
  final String label;
  final String smtp;
  final int smtpPort;
  final String imap;
  final int imapPort;
  final String? hint;
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({this.account, required this.defaultCorporate});
  final EmailAccount? account;
  final bool defaultCorporate;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  static const _presets = [
    _Preset(
      'Gmail',
      'smtp.gmail.com',
      587,
      'imap.gmail.com',
      993,
      hint: 'برای جیمیل از رمز عبور برنامه (App Password شانزده‌حرفی) استفاده کنید.',
    ),
    _Preset('Yahoo', 'smtp.mail.yahoo.com', 465, 'imap.mail.yahoo.com', 993),
    _Preset('Outlook', 'smtp.office365.com', 587, 'outlook.office365.com', 993),
    _Preset('Webmail سازمانی', 'mail.yourdomain.com', 587, 'mail.yourdomain.com', 993),
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addrCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _smtpCtrl;
  late final TextEditingController _smtpPortCtrl;
  late final TextEditingController _imapCtrl;
  late final TextEditingController _imapPortCtrl;

  late bool _isDabirkhane;
  bool _smtpSsl = true;
  bool _imapSsl = true;
  bool _busy = false;
  String? _presetHint;

  EmailRepository get _repo => context.read<EmailRepository>();

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _addrCtrl = TextEditingController(text: a?.address ?? '');
    _nameCtrl = TextEditingController(text: a?.displayName ?? '');
    _userCtrl = TextEditingController(text: a?.username ?? '');
    _passCtrl = TextEditingController();
    _smtpCtrl = TextEditingController(text: a?.smtp ?? 'smtp.gmail.com');
    _smtpPortCtrl = TextEditingController(text: '${a?.smtpPort ?? 587}');
    _imapCtrl = TextEditingController(text: a?.imap ?? 'imap.gmail.com');
    _imapPortCtrl = TextEditingController(text: '${a?.imapPort ?? 993}');
    _isDabirkhane = a?.isDabirkhane ?? widget.defaultCorporate;
    _smtpSsl = a?.smtpSsl ?? true;
    _imapSsl = a?.imapSsl ?? true;
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _smtpCtrl.dispose();
    _smtpPortCtrl.dispose();
    _imapCtrl.dispose();
    _imapPortCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(_Preset p) {
    setState(() {
      _smtpCtrl.text = p.smtp;
      _smtpPortCtrl.text = '${p.smtpPort}';
      _imapCtrl.text = p.imap;
      _imapPortCtrl.text = '${p.imapPort}';
      _smtpSsl = true;
      _imapSsl = true;
      _presetHint = p.hint;
    });
  }

  EmailAccount _buildModel() => EmailAccount(
    id: widget.account?.id ?? 0,
    address: _addrCtrl.text.trim(),
    displayName: _nameCtrl.text.trim(),
    isDabirkhane: _isDabirkhane,
    smtp: _smtpCtrl.text.trim(),
    smtpPort: int.tryParse(_smtpPortCtrl.text.trim()) ?? 587,
    smtpSsl: _smtpSsl,
    imap: _imapCtrl.text.trim(),
    imapPort: int.tryParse(_imapPortCtrl.text.trim()) ?? 993,
    imapSsl: _imapSsl,
    username: _userCtrl.text.trim().isEmpty
        ? _addrCtrl.text.trim()
        : _userCtrl.text.trim(),
  );

  Future<void> _testConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final res = await _repo.testAccount(_buildModel(), password: _passCtrl.text);
      if (!mounted) return;
      final msg = res.message.isNotEmpty
          ? res.message
          : (res.allOk
                ? 'اتصال SMTP و IMAP برقرار است.'
                : 'SMTP: ${res.smtpOk ? "✓" : "✗"} | IMAP: ${res.imapOk ? "✓" : "✗"}');
      showMessage(context, msg, error: !res.allOk);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await _repo.saveAccount(_buildModel(), password: _passCtrl.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final editing = widget.account != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? 'ویرایش حساب ایمیل' : 'افزودن حساب ایمیل',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in _presets)
                    ActionChip(
                      label: Text(p.label, style: const TextStyle(fontSize: 11.5)),
                      onPressed: () => _applyPreset(p),
                    ),
                ],
              ),
              if (_presetHint != null) ...[
                const SizedBox(height: 6),
                Text(
                  _presetHint!,
                  style: const TextStyle(fontSize: 11.5, color: OfficeColors.signing),
                ),
              ],
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'حساب سازمانی (دبیرخانه)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'در صورت خاموش بودن، حساب در بخش «شخصی» فقط برای شما نمایش داده می‌شود.',
                  style: TextStyle(fontSize: 11),
                ),
                value: _isDabirkhane,
                onChanged: (v) => setState(() => _isDabirkhane = v),
              ),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'نام نمایشی (مثلاً دبیرخانه)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addrCtrl,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'آدرس ایمیل'),
                validator: (v) =>
                    (v ?? '').contains('@') ? null : 'آدرس ایمیل معتبر وارد کنید.',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _userCtrl,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'نام کاربری (خالی = همان آدرس ایمیل)',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passCtrl,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: editing
                      ? 'رمز عبور / App Password (خالی = بدون تغییر)'
                      : 'رمز عبور / App Password',
                ),
                validator: (v) {
                  if (!editing && (v ?? '').isEmpty) {
                    return 'رمز عبور را وارد کنید.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _smtpCtrl,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'سرور SMTP'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _smtpPortCtrl,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'پورت'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _imapCtrl,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'سرور IMAP'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _imapPortCtrl,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'پورت'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('SSL ارسال (SMTP)'),
                    selected: _smtpSsl,
                    onSelected: (v) => setState(() => _smtpSsl = v),
                  ),
                  FilterChip(
                    label: const Text('SSL دریافت (IMAP)'),
                    selected: _imapSsl,
                    onSelected: (v) => setState(() => _imapSsl = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _testConnection,
                    icon: const Icon(Icons.wifi_tethering, size: 17),
                    label: const Text('تست اتصال'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context, false),
                    child: const Text('انصراف'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.check, size: 17),
                    label: const Text('ذخیره'),
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
