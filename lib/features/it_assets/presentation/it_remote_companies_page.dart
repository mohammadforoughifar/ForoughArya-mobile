// ============================================================
//  «شرکت‌های راه‌دور» — فاز ۹-ب
//  آینهٔ صفحهٔ وب `/settings/it-client-companies`
//  (در منوی گروه «مدیریت سیستم» فقط با `ItRequests` + `Auth.IsAdmin` دیده می‌شود)
//
//  فهرست شرکت‌هایی که نرم‌افزارشان به این سرور مرکزی وصل است:
//  کد، نام، تلفن، وضعیت، محدودیت ساعتی، تعداد کل درخواست و درخواست باز،
//  کلید API (فقط اشاره/hint) و زمان تعویض کلید.
//  عملیات: ثبت/ویرایش شرکت، «تعویض کلید»، حذف.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/it_request_repository.dart';
import '../models/it_request_models.dart';

class ItRemoteCompaniesPage extends StatefulWidget {
  const ItRemoteCompaniesPage({super.key});

  @override
  State<ItRemoteCompaniesPage> createState() => _ItRemoteCompaniesPageState();
}

class _ItRemoteCompaniesPageState extends State<ItRemoteCompaniesPage> {
  late final ApiClient _api;
  late final ItRequestRepository _repo;

  List<ItClientCompany> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _repo = ItRequestRepository(_api);
    _load();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.clientCompanies();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  void _toast(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? ShopColors.danger : null,
      ),
    );
  }

  Future<void> _openForm([ItClientCompany? c]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyFormSheet(api: _api, company: c),
    );
    if (saved == true) await _load();
  }

  Future<void> _rotateKey(ItClientCompany c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعویض کلید API', style: TextStyle(fontSize: 14)),
        content: Text(
          'کلید فعلی شرکت «${c.name}» باطل و کلید تازه صادر می‌شود. '
          'کلید تازه فقط همین یک‌بار نمایش داده می‌شود.',
          style: const TextStyle(fontSize: 11.5, height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف', style: TextStyle(fontSize: 12)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تعویض کلید', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await _api.post<dynamic>(
        '/api/itrequests/client-companies/${c.id}/rotate-key',
      );
      final d = r.data;
      final key = d is Map ? (d['apiKey'] ?? d['key'])?.toString() : null;
      _toast(key == null ? 'کلید تعویض شد.' : 'کلید تازه: $key');
      await _load();
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  Future<void> _delete(ItClientCompany c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف شرکت', style: TextStyle(fontSize: 14)),
        content: Text(
          'شرکت «${c.name}» حذف شود؟ درخواست‌های ثبت‌شدهٔ آن باقی می‌مانند.',
          style: const TextStyle(fontSize: 11.5, height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف', style: TextStyle(fontSize: 12)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete<dynamic>(
        '/api/itrequests/client-companies/${c.id}',
      );
      _toast('شرکت حذف شد.');
      await _load();
    } catch (e) {
      _toast(_clean(e), error: true);
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
        title: const Text(
          'شرکت‌های راه‌دور',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ShopColors.seed,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text(
          'شرکت جدید',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
          children: [
            const ShopHeader(
              title: 'شرکت‌های راه‌دور',
              subtitle:
                  'شرکت‌هایی که نرم‌افزارشان با کلید API به این سرور مرکزی وصل است',
              icon: Icons.hub_rounded,
              badge: 'IT',
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ShopEmpty(
                title: 'فهرست بارگذاری نشد',
                subtitle: _error,
                icon: Icons.error_outline_rounded,
              )
            else if (_items.isEmpty)
              const ShopEmpty(
                title: 'شرکتی ثبت نشده است',
                subtitle:
                    'برای دریافت درخواست از شعبه‌ها، شرکت و کلید API آن را ثبت کنید.',
                icon: Icons.apartment_rounded,
              )
            else
              for (final c in _items) _card(c),
          ],
        ),
      ),
    );
  }

  Widget _card(ItClientCompany c) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                c.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ShopTag(
              text: c.isActive ? 'فعال' : 'غیرفعال',
              color: c.isActive ? ShopColors.ok : ShopColors.inkFaint,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ShopTag(text: 'کد: ${c.code}', color: ShopColors.seed),
            ShopTag(
              text: '${Fa.number(c.requestCount)} درخواست',
              color: ShopColors.inkFaint,
            ),
            ShopTag(
              text: '${Fa.number(c.openCount)} باز',
              color: c.openCount > 0 ? ShopColors.warn : ShopColors.inkFaint,
            ),
            ShopTag(
              text: 'سقف ساعتی: ${Fa.number(c.hourlyLimit)}',
              color: ShopColors.inkFaint,
            ),
          ],
        ),
        if ((c.phone ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              'تلفن: ${Fa.digits(c.phone!)}',
              style: const TextStyle(fontSize: 10, color: ShopColors.inkSoft),
            ),
          ),
        if ((c.apiKeyHint ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              'کلید API: ${c.apiKeyHint}'
              '${c.keyRotatedAt == null ? '' : ' — آخرین تعویض: ${Fa.date(c.keyRotatedAt!.toIso8601String(), time: false)}'}',
              style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
            ),
          ),
        if ((c.note ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              c.note!,
              style: const TextStyle(
                fontSize: 9.5,
                color: ShopColors.inkFaint,
                height: 1.7,
              ),
            ),
          ),
        const SizedBox(height: 7),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _openForm(c),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 9),
              ),
              icon: const Icon(Icons.edit_rounded, size: 13),
              label: const Text('ویرایش', style: TextStyle(fontSize: 10)),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: () => _rotateKey(c),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 9),
              ),
              icon: const Icon(Icons.vpn_key_rounded, size: 13),
              label: const Text('تعویض کلید', style: TextStyle(fontSize: 10)),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _delete(c),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 17,
                color: ShopColors.danger,
              ),
              tooltip: 'حذف',
            ),
          ],
        ),
      ],
    ),
  );
}

/// فرم ثبت/ویرایش شرکت — فیلدهای `ClientCompanyDto` وب
class _CompanyFormSheet extends StatefulWidget {
  const _CompanyFormSheet({required this.api, this.company});
  final ApiClient api;
  final ItClientCompany? company;

  @override
  State<_CompanyFormSheet> createState() => _CompanyFormSheetState();
}

class _CompanyFormSheetState extends State<_CompanyFormSheet> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _hourly = TextEditingController(text: '60');
  bool _active = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.company;
    if (c != null) {
      _code.text = c.code;
      _name.text = c.name;
      _phone.text = c.phone ?? '';
      _note.text = c.note ?? '';
      _hourly.text = c.hourlyLimit.toString();
      _active = c.isActive;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    _hourly.dispose();
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty) {
      setState(() => _error = 'کد و نام شرکت را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.api.post<dynamic>(
        '/api/itrequests/client-companies',
        {
          'id': widget.company?.id ?? 0,
          'code': _code.text.trim(),
          'name': _name.text.trim(),
          'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          'isActive': _active,
          'hourlyLimit': int.tryParse(_hourly.text.trim()) ?? 60,
          'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        },
      );
      final d = r.data;
      final key = d is Map ? (d['apiKey'] ?? d['key'])?.toString() : null;
      if (!mounted) return;
      Navigator.of(context).pop(true);
      if (key != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('کلید API شرکت: $key'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 12),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          decoration: BoxDecoration(
            color: ShopColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.company == null ? 'ثبت شرکت راه‌دور' : 'ویرایش شرکت',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ShopColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: ShopColors.danger,
                      ),
                    ),
                  ),
                _field('کد شرکت *', _code),
                _field('نام شرکت *', _name),
                _field('تلفن', _phone, keyboard: TextInputType.phone),
                _field('سقف درخواست در ساعت', _hourly,
                    keyboard: TextInputType.number),
                _field('یادداشت', _note, maxLines: 2),
                SwitchListTile(
                  value: _active,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: ShopColors.seed,
                  title: const Text(
                    'فعال',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onChanged: (v) => setState(() => _active = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.seed,
                      minimumSize: const Size(0, 42),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 16),
                    label: const Text(
                      'ذخیره',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 11.5),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: const TextStyle(fontSize: 10.5),
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
