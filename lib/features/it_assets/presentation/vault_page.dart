// ============================================================
//  «گاوصندوق رمزهای تجهیزات» — فاز ۹-ه
//  آینهٔ `Pages/ItAssets/ItVault.razor` (مسیر وب: /it-vault)
//
//  • سرصفحهٔ تیره «گاوصندوق رمزهای تجهیزات» + شمارندهٔ موارد فیلترشده
//  • دکمه‌های سرصفحه: «باز کردن گاوصندوق» / نشان «باز تا HH:mm» + «قفل»
//    (گیت ItVault.Reveal)، «لاگ دسترسی‌ها» (ItVault.ViewLog)، «افزودن» (ItVault.Create)
//  • انتخاب شرکت `Name (count)` + جستجو «عنوان / آی‌پی / نام کاربری / محل...»
//  • سوئیچ «نمایش غیرفعال‌ها» + تب‌های نوع تجهیز با شمارنده
//  • کارت هر مورد: نوع، عنوان، آدرس، روش اتصال، نام کاربری، رمز (•••••••• / نمایش
//    ۳۰ ثانیه‌ای / کپی)، محل، تاریخ تغییر رمز + ویرایش/لاگ/حذف
//  • مودال باز کردن گاوصندوق، مودال لاگ دسترسی، فرم افزودن/ویرایش
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/it_perms.dart';
import '../data/vault_repository.dart';
import '../models/vault_models.dart';
import 'system_style.dart';

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  late final VaultRepository _repo;
  late final ItPerms _perms;

  List<VaultCompanyRow> _companies = const [];
  List<VaultRow> _rows = const [];
  int _companyId = 0;
  String _category = 'All';
  final _search = TextEditingController();
  bool _showInactive = true;
  bool _loading = true;
  bool _companiesLoading = true;
  String? _error;

  /// توکن باز بودن گاوصندوق — فقط در حافظه، حداکثر ۱۰ دقیقه
  String? _unlockToken;
  DateTime? _unlockExpires;

  /// رمزهای نمایش‌داده‌شده و تایمر پنهان‌سازی ۳۰ ثانیه‌ای
  final Map<int, VaultSecret> _revealed = {};
  final Map<int, Timer> _hideTimers = {};

  bool get _isUnlocked =>
      _unlockToken != null &&
      _unlockExpires != null &&
      _unlockExpires!.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    _repo = VaultRepository(context.read<ApiClient>());
    _perms = ItPerms(context.read<AuthController>().session);
    _loadCompanies();
  }

  @override
  void dispose() {
    for (final t in _hideTimers.values) {
      t.cancel();
    }
    _hideTimers.clear();
    _revealed.clear();
    _search.dispose();
    super.dispose();
  }

  bool get _canView => _perms.has('ItVault.View');
  bool get _canCreate => _perms.has('ItVault.Create');
  bool get _canUpdate => _perms.has('ItVault.Update');
  bool get _canDelete => _perms.has('ItVault.Delete');
  bool get _canReveal => _perms.has('ItVault.Reveal');
  bool get _canViewLog => _perms.has('ItVault.ViewLog');

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 11.5)),
        backgroundColor: error ? ShopColors.danger : ShopColors.ok,
      ),
    );
  }

  // ---------------- بارگذاری ----------------

  Future<void> _loadCompanies() async {
    if (!_canView) {
      setState(() {
        _loading = false;
        _companiesLoading = false;
      });
      return;
    }
    setState(() {
      _companiesLoading = true;
      _error = null;
    });
    try {
      final list = await _repo.companies();
      if (!mounted) return;
      setState(() {
        _companies = list;
        _companyId = list.isEmpty ? 0 : list.first.id;
        _companiesLoading = false;
      });
      if (_companyId > 0) await _loadRows();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _companiesLoading = false;
        _loading = false;
        _error = vaultErrorText(e);
      });
    }
  }

  Future<void> _loadRows() async {
    if (_companyId <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _clearRevealed();
    try {
      final rows = await _repo.list(companyId: _companyId);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        // شمارندهٔ شرکت مثل وب با تعداد واقعی همگام می‌شود
        _companies = _companies
            .map((c) => c.id == _companyId ? c.copyWith(count: rows.length) : c)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _loading = false;
        _error = vaultErrorText(e);
      });
    }
  }

  // ---------------- رمزها ----------------

  Future<void> _reveal(VaultRow r) async {
    if (!_isUnlocked) {
      await _openUnlock(then: () => _reveal(r));
      return;
    }
    try {
      final res = await _repo.reveal(
        r.id,
        token: _unlockToken!,
        purpose: 'reveal',
      );
      if (!mounted) return;
      setState(() => _revealed[r.id] = res);
      _scheduleHide(r.id);
    } catch (e) {
      if (isVaultLockedError(e)) {
        _lock();
        if (!mounted) return;
        await _openUnlock(then: () => _reveal(r));
        return;
      }
      _toast(vaultErrorText(e), error: true);
    }
  }

  Future<void> _copyPassword(VaultRow r) async {
    if (!_isUnlocked) {
      await _openUnlock(then: () => _copyPassword(r));
      return;
    }
    try {
      final res = await _repo.reveal(
        r.id,
        token: _unlockToken!,
        purpose: 'copy',
      );
      if (!mounted) return;
      if ((res.password ?? '').isEmpty) {
        _toast('رمزی برای این مورد ذخیره نشده است.');
        return;
      }
      await Clipboard.setData(ClipboardData(text: res.password!));
      _toast('رمز کپی شد (ثبت در لاگ).');
    } catch (e) {
      if (isVaultLockedError(e)) {
        _lock();
        if (!mounted) return;
        await _openUnlock(then: () => _copyPassword(r));
        return;
      }
      _toast(vaultErrorText(e), error: true);
    }
  }

  void _scheduleHide(int id) {
    _hideTimers.remove(id)?.cancel();
    _hideTimers[id] = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      setState(() => _hide(id));
    });
  }

  void _hide(int id) {
    _revealed.remove(id);
    _hideTimers.remove(id)?.cancel();
  }

  void _clearRevealed() {
    for (final id in _revealed.keys.toList()) {
      _hide(id);
    }
  }

  void _lock() {
    _unlockToken = null;
    _unlockExpires = null;
    _clearRevealed();
    if (mounted) setState(() {});
    _toast('گاوصندوق قفل شد.');
  }

  Future<void> _openUnlock({Future<void> Function()? then}) async {
    final res = await showModalBottomSheet<VaultUnlockResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VaultUnlockSheet(repo: _repo),
    );
    if (res == null) return;
    setState(() {
      _unlockToken = res.token;
      _unlockExpires = res.expiresAt;
    });
    _toast('گاوصندوق برای ۱۰ دقیقه باز شد.');
    if (then != null) await then();
  }

  // ---------------- فرم / حذف / لاگ ----------------

  Future<void> _openForm({VaultRow? row}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VaultFormSheet(
        repo: _repo,
        companies: _companies,
        companyId: _companyId,
        row: row,
        defaultCategory: _category == 'All' ? 'Server' : _category,
      ),
    );
    if (saved == true) {
      _toast('ذخیره شد — رمز روی سرور رمزنگاری شد.');
      await _loadRows();
    }
  }

  Future<void> _delete(VaultRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حذف از گاوصندوق',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '«${r.title}» از گاوصندوق حذف شود؟ این کار قابل بازگشت نیست.',
          style: const TextStyle(fontSize: 12, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(r.id);
      _toast('حذف شد.');
      await _loadRows();
    } catch (e) {
      _toast(vaultErrorText(e), error: true);
    }
  }

  Future<void> _openLogs({VaultRow? row}) async {
    if (_companyId <= 0) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VaultLogsSheet(
        repo: _repo,
        companyId: _companyId,
        title: row?.title,
        credentialId: row?.id,
      ),
    );
  }

  // ---------------- فیلتر ----------------

  List<VaultRow> get _filtered {
    final q = _search.text.trim();
    return _rows
        .where((r) => _showInactive || r.isActive)
        .where((r) => _category == 'All' || r.category == _category)
        .where((r) => q.isEmpty || r.matches(q))
        .toList();
  }

  int _countOf(String key) => _rows
      .where((r) => (_showInactive || r.isActive) && (key == 'All' || r.category == key))
      .length;

  // ---------------- ساخت ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'گاوصندوق رمزهای تجهیزات',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadRows,
            tooltip: 'بازخوانی',
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      body: !_canView
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SystemNote(
                text: 'شما مجوز مشاهدهٔ گاوصندوق رمزها را ندارید.',
                color: ShopColors.warn,
                icon: Icons.lock_outline_rounded,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
              children: [
                _headerCard(),
                const SizedBox(height: 10),
                if (_companiesLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 50),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_companies.isEmpty)
                  const SystemNote(
                    text:
                        'هیچ شرکتی برای شما تعریف نشده است. از «سازمان و کیف پول ← شرکت‌ها و شعب» شرکت تعریف کنید و در «کاربران» دسترسی شرکت را به کاربر بدهید.',
                    color: ShopColors.seed,
                    icon: Icons.domain_disabled_rounded,
                  )
                else ...[
                  _companyPicker(),
                  const SizedBox(height: 8),
                  _searchBox(),
                  const SizedBox(height: 6),
                  _inactiveSwitch(),
                  const SizedBox(height: 8),
                  _categoryTabs(),
                  const SizedBox(height: 10),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    SystemNote(
                      text: _error!,
                      color: ShopColors.danger,
                      icon: Icons.cloud_off_rounded,
                    )
                  else if (_filtered.isEmpty)
                    SystemNote(
                      text: _canCreate
                          ? 'موردی ثبت نشده است — «افزودن» را بزنید.'
                          : 'موردی ثبت نشده است.',
                      color: ShopColors.seed,
                      icon: Icons.inbox_rounded,
                    )
                  else
                    for (final r in _filtered) _vaultCard(r),
                  const SizedBox(height: 10),
                  const SystemNote(
                    text:
                        'رمزها روی سرور با AES-256-GCM رمزنگاری می‌شوند و در فهرست هرگز ارسال نمی‌شوند. نمایش یا کپی رمز نیازمند مجوز «نمایش رمز» و تأیید دوبارهٔ رمز ورود شماست؛ گاوصندوق تا ۱۰ دقیقه باز می‌ماند و هر نمایش/کپی در لاگ ثبت می‌شود.',
                    color: ShopColors.ok,
                    icon: Icons.shield_rounded,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xff0f172a), Color(0xff334155)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'گاوصندوق رمزهای تجهیزات',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  Fa.digits(_filtered.length),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'سرور، سوییچ منیجبل، میکروتیک، فایروال و سامانه‌ها به تفکیک شرکت',
            style: TextStyle(fontSize: 9.5, color: Color(0xffcbd5e1)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_canReveal)
                _isUnlocked
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: ShopColors.ok.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: ShopColors.ok.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lock_open_rounded,
                                  size: 13,
                                  color: Color(0xff86efac),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'باز تا ${_hhmm(_unlockExpires)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xff86efac),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.14,
                              ),
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _lock,
                            icon: const Icon(Icons.lock_rounded, size: 13),
                            label: const Text(
                              'قفل',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      )
                    : TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xff1f2937),
                          backgroundColor: const Color(0xfffbbf24),
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _openUnlock(),
                        icon: const Icon(Icons.key_rounded, size: 14),
                        label: const Text(
                          'باز کردن گاوصندوق',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
              if (_canViewLog && _companyId > 0)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _openLogs(),
                  icon: const Icon(Icons.receipt_long_rounded, size: 14),
                  label: const Text(
                    'لاگ دسترسی‌ها',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (_canCreate && _companyId > 0)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text(
                    'افزودن',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _hhmm(DateTime? d) {
    if (d == null) return '—';
    final l = d.toLocal();
    return Fa.digits(
      '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}',
    );
  }

  Widget _companyPicker() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ShopColors.line),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.apartment_rounded,
          size: 15,
          color: ShopColors.inkFaint,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: DropdownButton<int>(
            value: _companyId > 0 ? _companyId : null,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 11.5, color: ShopColors.ink),
            items: [
              for (final c in _companies)
                DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.name} (${Fa.digits(c.count)})'),
                ),
            ],
            onChanged: (v) async {
              if (v == null || v == _companyId) return;
              setState(() {
                _companyId = v;
                _category = 'All';
              });
              await _loadRows();
            },
          ),
        ),
      ],
    ),
  );

  Widget _searchBox() => TextField(
    controller: _search,
    onChanged: (_) => setState(() {}),
    style: const TextStyle(fontSize: 11.5),
    decoration: InputDecoration(
      hintText: 'جستجو: عنوان / آی‌پی / نام کاربری / محل...',
      hintStyle: const TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
      prefixIcon: const Icon(
        Icons.search_rounded,
        size: 17,
        color: ShopColors.inkFaint,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      filled: true,
      fillColor: ShopColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ShopColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ShopColors.line),
      ),
    ),
  );

  Widget _inactiveSwitch() => Row(
    children: [
      SizedBox(
        height: 28,
        child: Switch(
          value: _showInactive,
          activeThumbColor: ShopColors.seed,
          onChanged: (v) => setState(() => _showInactive = v),
        ),
      ),
      const SizedBox(width: 6),
      const Text(
        'نمایش غیرفعال‌ها',
        style: TextStyle(fontSize: 10.5, color: ShopColors.inkSoft),
      ),
    ],
  );

  Widget _categoryTabs() {
    final tabs = <(String, String)>[
      ('All', 'همه'),
      for (final c in kVaultCategories) (c.key, c.title),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (key, title) = tabs[i];
          final active = _category == key;
          final meta = key == 'All' ? null : vaultCat(key);
          final color = meta == null
              ? const Color(0xff0f172a)
              : Color(meta.colorValue);
          return GestureDetector(
            onTap: () => setState(() => _category = key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? color : ShopColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? color : ShopColors.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : ShopColors.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: 0.22)
                          : const Color(0xfff1f5f9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      Fa.digits(_countOf(key)),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : ShopColors.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _vaultCard(VaultRow r) {
    final meta = r.meta;
    final color = Color(meta.colorValue);
    final secret = _revealed[r.id];
    return Opacity(
      opacity: r.isActive ? 1 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
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
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(_iconOf(r.category), size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              r.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: ShopColors.ink,
                              ),
                            ),
                          ),
                          if (!r.isActive) ...[
                            const SizedBox(width: 4),
                            const ShopTag(
                              text: 'غیرفعال',
                              color: ShopColors.inkFaint,
                            ),
                          ],
                          if ((r.notes ?? '').isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 12,
                              color: ShopColors.inkFaint,
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          ShopTag(text: meta.title, color: color),
                          if ((r.accessMethod ?? '').isNotEmpty) ...[
                            const SizedBox(width: 4),
                            ShopTag(
                              text: r.accessMethod!,
                              color: ShopColors.inkSoft,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.addressCell,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: ShopColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if ((r.host ?? '').isNotEmpty)
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: r.hostText));
                      _toast('آدرس کپی شد.');
                    },
                    visualDensity: VisualDensity.compact,
                    tooltip: 'کپی آدرس',
                    icon: const Icon(Icons.copy_rounded, size: 14),
                  ),
              ],
            ),
            if ((r.url ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 12,
                      color: vaultSafeUrl(r.url!).isEmpty
                          ? ShopColors.inkFaint
                          : ShopColors.seed,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        r.url!,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: vaultSafeUrl(r.url!).isEmpty
                              ? ShopColors.inkFaint
                              : ShopColors.seed,
                        ),
                      ),
                    ),
                    if (vaultSafeUrl(r.url!).isNotEmpty)
                      IconButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: vaultSafeUrl(r.url!)),
                          );
                          _toast('آدرس ورود کپی شد.');
                        },
                        visualDensity: VisualDensity.compact,
                        tooltip: 'کپی آدرس ورود',
                        icon: const Icon(Icons.copy_rounded, size: 13),
                      ),
                  ],
                ),
              ),
            const Divider(height: 12),
            _kv(
              'نام کاربری',
              (r.username ?? '').isEmpty ? '—' : r.username!,
              ltr: true,
              trailing: (r.username ?? '').isEmpty
                  ? null
                  : IconButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: r.username!),
                        );
                        _toast('نام کاربری کپی شد.');
                      },
                      visualDensity: VisualDensity.compact,
                      tooltip: 'کپی نام کاربری',
                      icon: const Icon(Icons.copy_rounded, size: 13),
                    ),
            ),
            _passwordRow(r, secret),
            _kv('محل', (r.location ?? '').isEmpty ? '—' : r.location!),
            if ((r.notes ?? '').isNotEmpty)
              _kv('توضیحات', r.notes!, multiline: true),
            _kv(
              'تغییر رمز',
              Fa.date(r.passwordChangedAt?.toIso8601String()),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_canUpdate)
                  _action(
                    'ویرایش',
                    Icons.edit_rounded,
                    ShopColors.seed,
                    () => _openForm(row: r),
                  ),
                if (_canViewLog)
                  _action(
                    'لاگ',
                    Icons.history_rounded,
                    ShopColors.inkSoft,
                    () => _openLogs(row: r),
                  ),
                if (_canDelete)
                  _action(
                    'حذف',
                    Icons.delete_rounded,
                    ShopColors.danger,
                    () => _delete(r),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(
    String label,
    String value, {
    bool ltr = false,
    bool multiline = false,
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLines: multiline ? 4 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: ShopColors.ink,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );

  Widget _passwordRow(VaultRow r, VaultSecret? secret) {
    const mono = TextStyle(
      fontSize: 11,
      fontFamily: 'monospace',
      letterSpacing: 1,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 78,
            child: Text(
              'رمز عبور',
              style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!r.hasPassword && !r.hasExtraSecret)
                  const Text(
                    '—',
                    style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
                  )
                else if (secret != null)
                  SelectableText(
                    secret.password ?? '',
                    textDirection: TextDirection.ltr,
                    style: mono.copyWith(
                      color: ShopColors.danger,
                      fontSize: 12,
                    ),
                  )
                else
                  Row(
                    children: [
                      Text(
                        r.hasPassword ? '••••••••' : '',
                        textDirection: TextDirection.ltr,
                        style: mono.copyWith(color: ShopColors.inkFaint),
                      ),
                      if (r.hasExtraSecret) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: ShopColors.warn,
                        ),
                      ],
                    ],
                  ),
                if (secret != null && (secret.extraSecret ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 11,
                          color: ShopColors.warn,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            secret.extraSecret!,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 9.5,
                              height: 1.7,
                              color: Color(0xffb45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (secret != null)
            IconButton(
              onPressed: () => setState(() => _hide(r.id)),
              visualDensity: VisualDensity.compact,
              tooltip: 'پنهان کردن',
              icon: const Icon(Icons.visibility_off_rounded, size: 15),
            )
          else if (_canReveal)
            IconButton(
              onPressed: () => _reveal(r),
              visualDensity: VisualDensity.compact,
              tooltip: 'نمایش (۳۰ ثانیه)',
              icon: const Icon(Icons.visibility_rounded, size: 15),
            ),
          if (_canReveal && r.hasPassword)
            IconButton(
              onPressed: () => _copyPassword(r),
              visualDensity: VisualDensity.compact,
              tooltip: 'کپی رمز',
              icon: const Icon(Icons.copy_all_rounded, size: 15),
            ),
        ],
      ),
    );
  }

  Widget _action(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 31),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    onPressed: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  static IconData _iconOf(String key) => switch (key) {
    'Server' => Icons.dns_rounded,
    'Switch' => Icons.account_tree_rounded,
    'Mikrotik' => Icons.router_rounded,
    'Firewall' => Icons.shield_rounded,
    'System' => Icons.web_asset_rounded,
    _ => Icons.inventory_2_rounded,
  };
}

// ============================================================
//  مودال باز کردن گاوصندوق
// ============================================================

class VaultUnlockSheet extends StatefulWidget {
  const VaultUnlockSheet({super.key, required this.repo});
  final VaultRepository repo;

  @override
  State<VaultUnlockSheet> createState() => _VaultUnlockSheetState();
}

class _VaultUnlockSheetState extends State<VaultUnlockSheet> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await widget.repo.unlock(_password.text);
      if (!mounted) return;
      Navigator.pop(context, res);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = vaultErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(14, 12, 14, 18 + insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.key_rounded,
                size: 17,
                color: ShopColors.warn,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'باز کردن گاوصندوق',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
            ],
          ),
          const Text(
            'برای نمایش یا کپی رمزها، رمز ورود خودتان به نرم‌افزار را وارد کنید. گاوصندوق تا ۱۰ دقیقه باز می‌ماند و هر نمایش/کپی در لاگ ثبت می‌شود.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.8,
              color: ShopColors.inkSoft,
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            SystemNote(
              text: _error!,
              color: ShopColors.danger,
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _password,
            obscureText: true,
            textDirection: TextDirection.ltr,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'رمز ورود شما',
              hintStyle: const TextStyle(
                fontSize: 10.5,
                color: ShopColors.inkFaint,
              ),
              isDense: true,
              filled: true,
              fillColor: ShopColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: ShopColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: ShopColors.line),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ShopColors.warn,
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                  onPressed: _busy || _password.text.isEmpty ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'باز کردن',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(21),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  مودال لاگ دسترسی
// ============================================================

class VaultLogsSheet extends StatefulWidget {
  const VaultLogsSheet({
    super.key,
    required this.repo,
    required this.companyId,
    this.title,
    this.credentialId,
  });
  final VaultRepository repo;
  final int companyId;
  final String? title;
  final int? credentialId;

  @override
  State<VaultLogsSheet> createState() => _VaultLogsSheetState();
}

class _VaultLogsSheetState extends State<VaultLogsSheet> {
  List<VaultLogRow> _logs = const [];
  bool _loading = true;
  String? _error;

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
      final logs = await widget.repo.logs(
        companyId: widget.companyId,
        credentialId: widget.credentialId,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = vaultErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: const BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: ShopColors.line)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 17,
                  color: ShopColors.inkSoft,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'لاگ دسترسی — ${widget.title ?? 'همهٔ موارد شرکت'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _load,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                    children: [
                      if (_error != null)
                        SystemNote(
                          text: _error!,
                          color: ShopColors.danger,
                          icon: Icons.cloud_off_rounded,
                        )
                      else if (_logs.isEmpty)
                        const SystemNote(
                          text: 'لاگی ثبت نشده است.',
                          color: ShopColors.seed,
                          icon: Icons.info_outline_rounded,
                        )
                      else
                        for (final l in _logs) _logRow(l),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _logRow(VaultLogRow l) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShopTag(
              text: l.actionLabel,
              color: Color(l.actionColor),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                l.userName ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              Fa.date(l.at?.toIso8601String()),
              style: const TextStyle(
                fontSize: 8.8,
                color: ShopColors.inkFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          l.title ?? '—',
          style: const TextStyle(fontSize: 10, color: ShopColors.inkSoft),
        ),
        if ((l.details ?? '').isNotEmpty)
          Text(
            l.details!,
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
        if ((l.clientIp ?? '').isNotEmpty)
          Text(
            l.clientIp!,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 8.8, color: ShopColors.inkFaint),
          ),
      ],
    ),
  );
}

// ============================================================
//  فرم افزودن / ویرایش
// ============================================================

class VaultFormSheet extends StatefulWidget {
  const VaultFormSheet({
    super.key,
    required this.repo,
    required this.companies,
    required this.companyId,
    this.row,
    this.defaultCategory = 'Server',
  });

  final VaultRepository repo;
  final List<VaultCompanyRow> companies;
  final int companyId;
  final VaultRow? row;
  final String defaultCategory;

  @override
  State<VaultFormSheet> createState() => _VaultFormSheetState();
}

class _VaultFormSheetState extends State<VaultFormSheet> {
  final _title = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _accessMethod = TextEditingController();
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _extraSecret = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();

  int _companyId = 0;
  String _category = 'Server';
  bool _isActive = true;
  bool _clearPassword = false;
  bool _clearExtraSecret = false;
  bool _showPassword = false;
  bool _busy = false;
  bool _hasPassword = false;
  bool _hasExtra = false;
  String? _error;

  bool get _isEdit => (widget.row?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    _companyId = r?.companyId ?? widget.companyId;
    _category = r?.category ?? widget.defaultCategory;
    if (r != null) {
      _title.text = r.title;
      _host.text = r.host ?? '';
      _port.text = (r.port ?? 0) > 0 ? '${r.port}' : '';
      _accessMethod.text = r.accessMethod ?? '';
      _url.text = r.url ?? '';
      _username.text = r.username ?? '';
      _location.text = r.location ?? '';
      _notes.text = r.notes ?? '';
      _isActive = r.isActive;
      _hasPassword = r.hasPassword;
      _hasExtra = r.hasExtraSecret;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _host,
      _port,
      _accessMethod,
      _url,
      _username,
      _password,
      _extraSecret,
      _location,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  VaultSaveRequest _build() => VaultSaveRequest(
    companyId: _companyId,
    category: _category,
    title: _title.text.trim(),
    host: _host.text.trim().isEmpty ? null : _host.text.trim(),
    port: int.tryParse(_port.text.trim()),
    accessMethod: _accessMethod.text.trim().isEmpty
        ? null
        : _accessMethod.text.trim(),
    url: _url.text.trim().isEmpty ? null : _url.text.trim(),
    username: _username.text.trim().isEmpty ? null : _username.text.trim(),
    password: _password.text.isEmpty ? null : _password.text,
    clearPassword: _clearPassword,
    extraSecret: _extraSecret.text.isEmpty ? null : _extraSecret.text,
    clearExtraSecret: _clearExtraSecret,
    location: _location.text.trim().isEmpty ? null : _location.text.trim(),
    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    isActive: _isActive,
  );

  Future<void> _save() async {
    final d = _build();
    final err = validateVaultForm(d);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.repo.update(widget.row!.id, d);
      } else {
        await widget.repo.create(d);
      }
      if (!mounted) return;
      // رمز از حافظهٔ فرم پاک می‌شود
      _password.clear();
      _extraSecret.clear();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = vaultErrorText(e);
      });
    }
  }

  void _generatePassword() {
    setState(() {
      _password.text = generateStrongPassword();
      _clearPassword = false;
      _showPassword = true;
    });
  }

  InputDecoration _dec([String? hint]) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
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

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            color: ShopColors.seed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: ShopColors.ink,
          ),
        ),
      ],
    ),
  );

  Widget _row2(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 8),
      Expanded(child: b),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final meta = vaultCat(_category);
    final strength = _password.text.isEmpty
        ? null
        : passwordStrength(_password.text);
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: const BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: ShopColors.line)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  size: 17,
                  color: ShopColors.seed,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isEdit ? 'ویرایش' : 'افزودن به گاوصندوق',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 20 + insets),
              children: [
                if (_error != null) ...[
                  SystemNote(
                    text: _error!,
                    color: ShopColors.danger,
                    icon: Icons.error_outline_rounded,
                  ),
                  const SizedBox(height: 10),
                ],
                _section('مشخصات تجهیز'),
                ShopField(
                  label: 'شرکت',
                  required: true,
                  child: DropdownButtonFormField<int>(
                    initialValue: _companyId > 0 ? _companyId : null,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.ink,
                    ),
                    decoration: _dec(),
                    items: [
                      for (final c in widget.companies)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.name,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _companyId = v ?? 0),
                  ),
                ),
                ShopField(
                  label: 'نوع تجهیز',
                  required: true,
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.ink,
                    ),
                    decoration: _dec(),
                    items: [
                      for (final c in kVaultCategories)
                        DropdownMenuItem(
                          value: c.key,
                          child: Text(
                            c.title,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _category = v ?? 'Server'),
                  ),
                ),
                ShopField(
                  label: 'عنوان',
                  required: true,
                  child: TextField(
                    controller: _title,
                    maxLength: 200,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec(meta.titleHint),
                  ),
                ),
                _row2(
                  ShopField(
                    label: 'آی‌پی / نام میزبان',
                    child: TextField(
                      controller: _host,
                      maxLength: 200,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: _dec('192.168.30.1'),
                    ),
                  ),
                  ShopField(
                    label: 'پورت',
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: _dec(
                        meta.portHint.isEmpty ? '—' : meta.portHint,
                      ),
                    ),
                  ),
                ),
                ShopField(
                  label: 'روش اتصال',
                  hint: 'یکی از موارد پیشنهادی یا متن آزاد',
                  child: DropdownButtonFormField<String>(
                    initialValue: kVaultAccessMethods.contains(_accessMethod.text)
                        ? _accessMethod.text
                        : null,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.ink,
                    ),
                    decoration: _dec('SSH / Web / Winbox ...'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('—', style: TextStyle(fontSize: 11)),
                      ),
                      for (final m in kVaultAccessMethods)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _accessMethod.text = v ?? '';
                    }),
                  ),
                ),
                ShopField(
                  label: 'آدرس ورود (سامانه / پنل وب)',
                  child: TextField(
                    controller: _url,
                    maxLength: 500,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('https://192.168.30.1:8443'),
                  ),
                ),
                _section('رمز و اطلاعات محرمانه'),
                ShopField(
                  label: 'نام کاربری',
                  child: TextField(
                    controller: _username,
                    maxLength: 200,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('admin'),
                  ),
                ),
                ShopField(
                  label: 'رمز عبور',
                  hint: _isEdit && _hasPassword
                      ? 'برای حفظ رمز فعلی خالی بگذارید'
                      : 'روی سرور رمزنگاری می‌شود',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _password,
                              obscureText: !_showPassword,
                              enabled: !_clearPassword,
                              maxLength: 1000,
                              textDirection: TextDirection.ltr,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(fontSize: 11.5),
                              decoration: _dec(),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(
                              () => _showPassword = !_showPassword,
                            ),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'نمایش/پنهان',
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 16,
                            ),
                          ),
                          IconButton(
                            onPressed: _clearPassword
                                ? null
                                : _generatePassword,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'ساخت رمز قوی تصادفی',
                            icon: const Icon(
                              Icons.auto_fix_high_rounded,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      if (strength != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 12,
                                color: Color(strength.$2),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'قدرت رمز: ${strength.$1}',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Color(strength.$2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_isEdit && _hasPassword)
                        Row(
                          children: [
                            SizedBox(
                              height: 28,
                              child: Switch(
                                value: _clearPassword,
                                activeThumbColor: ShopColors.danger,
                                onChanged: (v) => setState(() {
                                  _clearPassword = v;
                                  if (v) _password.clear();
                                }),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'حذف رمز ذخیره‌شده',
                              style: TextStyle(
                                fontSize: 10,
                                color: ShopColors.danger,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                ShopField(
                  label: 'اطلاعات محرمانهٔ تکمیلی',
                  hint:
                      'رمزنگاری می‌شود — مثل enable secret، SNMP community، کلید Wi-Fi، کد بازیابی',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _extraSecret,
                        maxLines: 2,
                        maxLength: 4000,
                        enabled: !_clearExtraSecret,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 11.5),
                        decoration: _dec(
                          _isEdit && _hasExtra
                              ? 'مقدار فعلی ذخیره شده است — برای حفظ، خالی بگذارید'
                              : '',
                        ),
                      ),
                      if (_isEdit && _hasExtra)
                        Row(
                          children: [
                            SizedBox(
                              height: 28,
                              child: Switch(
                                value: _clearExtraSecret,
                                activeThumbColor: ShopColors.danger,
                                onChanged: (v) => setState(() {
                                  _clearExtraSecret = v;
                                  if (v) _extraSecret.clear();
                                }),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'حذف اطلاعات محرمانهٔ ذخیره‌شده',
                              style: TextStyle(
                                fontSize: 10,
                                color: ShopColors.danger,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                _section('محل و وضعیت'),
                ShopField(
                  label: 'محل استقرار',
                  child: TextField(
                    controller: _location,
                    maxLength: 250,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('مثلاً: رک اتاق سرور'),
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      height: 30,
                      child: Switch(
                        value: _isActive,
                        activeThumbColor: ShopColors.seed,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'فعال',
                      style: TextStyle(fontSize: 11, color: ShopColors.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ShopField(
                  label: 'توضیحات',
                  hint: 'رمزنگاری نمی‌شود — رمز را اینجا ننویسید',
                  child: TextField(
                    controller: _notes,
                    maxLines: 2,
                    maxLength: 2000,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec(),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ShopColors.seed,
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(21),
                          ),
                        ),
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEdit ? 'ذخیره تغییرات' : 'افزودن',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(21),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'انصراف',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SystemNote(
                  text:
                      'رمز و اطلاعات محرمانه با AES-256-GCM روی سرور رمزنگاری می‌شوند و کلید اصلی خارج از دیتابیس نگهداری می‌شود. در فهرست‌ها هیچ‌گاه رمز ارسال نمی‌شود.',
                  color: ShopColors.ok,
                  icon: Icons.lock_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
