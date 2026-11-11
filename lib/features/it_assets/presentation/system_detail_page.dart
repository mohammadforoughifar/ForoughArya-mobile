// ============================================================
//  «شناسنامهٔ سیستم» — فاز ۹-ج
//  آینهٔ `Pages/ItAssets/SystemId.razor` (مسیر وب: /system-id و /system-id/{id})
//
//  بخش‌ها به همان ترتیب وب:
//    ۱) کاربر اختصاص‌یافته (بنر سبز)
//    ۲) هشدار «اینجا ثبت نشده» / تأییدشده
//    ۳) امتیاز سلامت سیستم (گیج + دسته‌ها)
//    ۴) تغییرات جدید ایجنت — مقایسهٔ دو ستونه + تایید/رد
//    ۵) تایم‌لاین تغییرات سخت‌افزار
//    ۶) اطلاعات سخت‌افزاری (مادربرد، CPU، رم، هارد، شبکه، درایوها)
//    ۷) اختصاص کاربر به این سیستم
//    ۸) سابقهٔ کاربری سیستم
//    ۹) چک‌لیست تحویل دیجیتال با امضا
//    ۱۰) دستور از راه دور (ری‌استارت/خاموش/قفل)
//  + دکمهٔ «PDF شناسنامه»
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../misc/presentation/misc_style.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/system_repository.dart';
import '../models/system_models.dart';
import 'system_style.dart';

class SystemDetailPage extends StatefulWidget {
  const SystemDetailPage({super.key, required this.systemId});

  final int systemId;

  @override
  State<SystemDetailPage> createState() => _SystemDetailPageState();
}

class _SystemDetailPageState extends State<SystemDetailPage> {
  late final SystemRepository _repo;
  late final ApiClient _api;

  SystemInfoItem? _item;
  bool _itemMissing = false;
  SystemComponents? _hw;
  SystemHealth? _health;
  PendingChanges _pending = const PendingChanges();
  List<SystemHistoryEntry> _history = const [];
  List<SystemUserRow> _users = const [];
  List<SystemCompanyRow> _companies = const [];
  List<SystemUserHistoryRow> _userHistory = const [];
  List<SystemHandover> _handovers = const [];
  List<RemoteCommandRow> _commands = const [];

  bool _loading = true;
  bool _busy = false;
  bool _onlyChanged = false;

  // انتخاب‌های اختصاص کاربر
  int _selCompanyId = 0;
  int _selUserId = 0;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _repo = SystemRepository(_api);
    _loadAll();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  Future<void> _loadAll() async {
    try {
      final item = await _repo.system(widget.systemId);
      final results = await Future.wait<dynamic>([
        _repo.components(widget.systemId),
        _repo.health(widget.systemId),
        _repo.changes(widget.systemId),
        _repo.history(widget.systemId),
        _repo.users(),
        _repo.companies(),
        _repo.userHistory(widget.systemId),
        _repo.handovers(widget.systemId),
        _repo.commands(widget.systemId),
      ]);
      if (!mounted) return;
      setState(() {
        _item = item;
        _itemMissing = item == null;
        _hw = results[0] as SystemComponents?;
        _health = results[1] as SystemHealth?;
        _pending = results[2] as PendingChanges;
        _history = results[3] as List<SystemHistoryEntry>;
        _users = results[4] as List<SystemUserRow>;
        _companies = results[5] as List<SystemCompanyRow>;
        _userHistory = results[7] as List<SystemUserHistoryRow>;
        _handovers = results[8] as List<SystemHandover>;
        _commands = results[9] as List<RemoteCommandRow>;
        _selCompanyId = item?.companyId ?? 0;
        _selUserId = item?.userId ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('بارگذاری شناسنامه ناموفق بود — ${_clean(e)}', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 11.5)),
        backgroundColor: error ? ShopColors.danger : ShopColors.ok,
      ),
    );
  }

  // ---------------- کمکی‌ها ----------------

  String _userName(int? userId) {
    if (userId == null) return '—';
    for (final u in _users) {
      if (u.id == userId) {
        return u.staffNumber.trim().isEmpty
            ? u.fullName
            : '${u.fullName} (${u.staffNumber})';
      }
    }
    return '#$userId';
  }

  String _companyName(int? id) {
    if (id == null) return '—';
    for (final c in _companies) {
      if (c.id == id) return c.name;
    }
    return '#$id';
  }

  List<SystemUserRow> get _companyUsers => _users
      .where((u) => _selCompanyId > 0 && u.companyId == _selCompanyId && u.isActive)
      .toList();

  // ---------------- عملیات ----------------

  Future<void> _applyChanges() async {
    setState(() => _busy = true);
    try {
      await _repo.applyChanges(widget.systemId);
      await _loadAll();
      _toast('اطلاعات جدید جایگزین شد.');
    } catch (e) {
      _toast('تایید ناموفق بود — ${_clean(e)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discardChanges() async {
    setState(() => _busy = true);
    try {
      await _repo.discardChanges(widget.systemId);
      await _loadAll();
      _toast('تغییرات رد شد.');
    } catch (e) {
      _toast('رد کردن ناموفق بود — ${_clean(e)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await _repo.approve(widget.systemId);
      await _loadAll();
      _toast('سیستم تأیید شد.');
    } catch (e) {
      _toast('تأیید ناموفق بود — ${_clean(e)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    if (_selCompanyId <= 0 || _selUserId <= 0) return;
    setState(() => _busy = true);
    try {
      await _repo.assignUser(
        systemInfoId: widget.systemId,
        userId: _selUserId,
      );
      await _loadAll();
      _toast('کاربر به این سیستم اختصاص یافت.');
    } catch (e) {
      _toast('اختصاص ناموفق بود — ${_clean(e)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCommand(String action) async {
    final auth = context.read<AuthController>().session;
    final who = (auth?.displayName ?? '').trim().isEmpty
        ? 'مدیر'
        : auth!.displayName.trim();
    setState(() => _busy = true);
    try {
      await _repo.sendCommand(
        id: widget.systemId,
        action: action,
        byUserName: who,
      );
      final rows = await _repo.commands(widget.systemId);
      if (!mounted) return;
      setState(() => _commands = rows);
      _toast('دستور ارسال شد.');
    } catch (e) {
      _toast('ارسال دستور ناموفق بود — ${_clean(e)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _busy = true);
    try {
      final bytes = await _repo.pdf(widget.systemId);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/System-Identity-${widget.systemId}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
    } catch (e) {
      _toast('ساخت PDF ناموفق بود — ${_clean(e)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openHandoverSheet() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HandoverSheet(
        repo: _repo,
        system: _item,
        users: _users,
      ),
    );
    if (ok == true) {
      final rows = await _repo.handovers(widget.systemId);
      if (!mounted) return;
      setState(() => _handovers = rows);
      _toast('تحویل ثبت شد.');
    }
  }

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
          'شناسنامه سیستم',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_item != null)
            IconButton(
              onPressed: _busy ? null : _downloadPdf,
              tooltip: 'PDF شناسنامه',
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
            ),
          IconButton(
            onPressed: _loading ? null : _loadAll,
            tooltip: 'بارگذاری مجدد',
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 30),
                children: [
                  const ShopHeader(
                    title: 'شناسنامه سخت‌افزار سیستم',
                    subtitle:
                        'مشخصات فنی قطعات، تخصیص به کاربر و بررسی تغییرات',
                    icon: Icons.memory_rounded,
                    badge: 'IT',
                  ),
                  const SizedBox(height: 12),
                  if (_itemMissing) _notRegisteredNote(),
                  if (_item != null && !_itemMissing) ...[
                    if (_item!.userId != null) _assignedBanner(),
                    if (_item!.isApproved) _approvedNote(),
                    if (!_item!.isApproved) _approveCard(),
                    _healthCard(),
                    if (_pending.hasPending) _pendingCard(),
                    if (_history.isNotEmpty) _historyCard(),
                    _hardwareCard(),
                    _assignCard(),
                    _userHistoryCard(),
                    _handoverCard(),
                    _commandsCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _notRegisteredNote() {
    return Column(
      children: [
        SystemNote(
          text:
              'این شناسه هنوز توسط ایجنت در بانک ثبت نشده است — اطلاعات واقعی سخت‌افزار اینجا نمایش داده نمی‌شود. '
              'کافی است ایجنت را روی همان سیستم اجرا کنید؛ دادهٔ سخت‌افزاری خودکار به همین سرور ارسال می‌شود و این صفحه پر می‌شود.',
          color: ShopColors.warn,
          icon: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 10),
        SystemCard(
          title: 'دستور آمادهٔ ارسال به همین سرور',
          icon: Icons.terminal_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xff0f172a),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'InventoryAgent.exe run -s ${_api.baseUrl}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xffe2e8f0),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'نسخهٔ بدون فایل اجرایی (اگر روی کلاینت .NET 8 نصب است):',
                style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
              ),
              const SizedBox(height: 3),
              Text(
                'dotnet run --project src/Agent.Console -- run -s ${_api.baseUrl}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: ShopColors.inkSoft,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _assignedBanner() {
    final u = _item?.userId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xffeaf7ef),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xffb6e0c5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_pin_rounded,
            size: 18,
            color: ShopColors.ok,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 10.8,
                  height: 1.7,
                  color: Color(0xff14532d),
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  const TextSpan(text: 'کاربر اختصاص‌یافته: '),
                  TextSpan(
                    text: _userName(u),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(text: ' — ${_companyName(_item?.companyId)}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvedNote() => const Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: SystemNote(
      text: 'تأیید شده — این سیستم در بانک اطلاعاتی ذخیره شده است.',
      color: ShopColors.ok,
      icon: Icons.check_circle_rounded,
    ),
  );

  Widget _approveCard() => Column(
    children: [
      const SystemNote(
        text:
            'این سیستم هنوز تأیید نشده است. پس از بررسی اطلاعات، با دکمهٔ زیر آن را در بانک اطلاعاتی تأیید کنید.',
        color: ShopColors.warn,
        icon: Icons.pending_actions_rounded,
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ShopColors.ok,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: _busy ? null : _approve,
            icon: const Icon(Icons.verified_rounded, size: 16),
            label: const Text(
              'تأیید سیستم',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    ],
  );

  // ---------------- سلامت ----------------

  Widget _healthCard() {
    final h = _health;
    return SystemCard(
      title: 'امتیاز سلامت سیستم',
      icon: Icons.monitor_heart_rounded,
      trailing: h == null
          ? const ShopTag(text: 'در انتظار ایجنت', color: ShopColors.inkFaint)
          : ShopTag(
              text: h.gradeFa,
              color: hexColor(h.color, fallback: ShopColors.seed),
            ),
      child: h == null
          ? const Text(
              'هنوز اطلاعات سخت‌افزاری کافی برای محاسبه‌ی سلامت ثبت نشده — بعد از اجرای ایجنت و ثبت قطعات، امتیاز اینجا نمایش داده می‌شود.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.7,
                color: ShopColors.inkFaint,
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  children: [
                    HealthGauge(
                      score: h.score,
                      size: 112,
                      showLabel: true,
                      label: h.gradeFa,
                    ),
                    const Text(
                      'از ۱۰۰',
                      style: TextStyle(
                        fontSize: 9,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      for (final c in h.categories)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          c.fa,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: ShopColors.ink,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            c.note,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 8.5,
                                              color: ShopColors.inkFaint,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    MiniBar(
                                      pct: c.pct,
                                      color: c.pct >= 75
                                          ? ShopColors.ok
                                          : c.pct >= 50
                                          ? ShopColors.warn
                                          : ShopColors.danger,
                                      height: 5,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${Fa.digits(c.score)}/${Fa.digits(c.max)}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: ShopColors.inkSoft,
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
    );
  }

  // ---------------- تغییرات ----------------

  Widget _pendingCard() {
    final diffs = _pending.diffs
        .where((d) => !_onlyChanged || d.changed)
        .toList();
    return SystemCard(
      title:
          'تغییرات جدید ایجنت — ${Fa.digits(_pending.changeCount)} اختلاف، در انتظار تایید',
      icon: Icons.compare_arrows_rounded,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: _onlyChanged,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (v) => setState(() => _onlyChanged = v ?? false),
          ),
          const Text(
            'فقط تغییرکرده',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: ShopColors.inkSoft,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Th('قطعه'),
              const SizedBox(width: 6),
              Expanded(flex: 4, child: _ThText('مقدار فعلی (بانک اطلاعاتی)')),
              const SizedBox(width: 6),
              Expanded(flex: 4, child: _ThText('مقدار جدید (ایجنت) ⬅')),
            ],
          ),
          const Divider(height: 12),
          for (final d in diffs)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ShopColors.line.withValues(alpha: 0.7)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      '${d.changed ? '⚠️ ' : ''}${d.field}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: Text(
                      d.oldValue ?? '—',
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.6,
                        color: d.changed ? ShopColors.danger : ShopColors.inkFaint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: Text(
                      d.newValue ?? '—',
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.6,
                        fontWeight: d.changed ? FontWeight.w800 : FontWeight.w500,
                        color: d.changed ? ShopColors.ok : ShopColors.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ShopColors.ok,
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  onPressed: _busy ? null : _applyChanges,
                  icon: const Icon(Icons.check_circle_rounded, size: 15),
                  label: const Text(
                    'تایید — اطلاعات جدید جایگزین شود',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 38),
              foregroundColor: ShopColors.inkSoft,
              side: const BorderSide(color: ShopColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
              ),
            ),
            onPressed: _busy ? null : _discardChanges,
            icon: const Icon(Icons.cancel_rounded, size: 15),
            label: const Text(
              'رد کردن',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard() {
    return SystemCard(
      title: 'تایم‌لاین تغییرات سخت‌افزار',
      icon: Icons.history_rounded,
      trailing: ShopTag(
        text: '${Fa.digits(_history.length)} رکورد',
        color: ShopColors.inkFaint,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _history.length; i++) _historyRow(_history[i], i),
        ],
      ),
    );
  }

  Widget _historyRow(SystemHistoryEntry e, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: index == _history.length - 1
                ? Colors.transparent
                : ShopColors.line.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == 0 ? ShopColors.ok : ShopColors.inkFaint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  Fa.date(e.changedAt?.toUtc().toIso8601String()),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ),
              ShopTag(
                text: '${Fa.digits(e.changeCount)} تغییر',
                color: ShopColors.accent,
              ),
            ],
          ),
          for (final d in e.diffs)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 14),
              child: Text(
                '${d.changed ? '⚠️ ' : ''}${d.field}: ${d.oldValue ?? '—'} ← ${d.newValue ?? '—'}',
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.6,
                  color: d.changed ? ShopColors.ok : ShopColors.inkFaint,
                  fontWeight: d.changed ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- سخت‌افزار ----------------

  Widget _hardwareCard() {
    final hw = _hw;
    final it = _item!;
    final totalRam = hw?.totalRamGb ?? 0;

    return SystemCard(
      title: 'اطلاعات سیستم #${Fa.digits(it.id)}',
      icon: Icons.developer_board_rounded,
      trailing: ShopTag(text: it.agentId, color: ShopColors.seed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hw == null) ...[
            InfoRow(label: 'پردازنده', value: it.cpuCell),
            InfoRow(label: 'حافظه رم', value: it.ramCell),
            InfoRow(label: 'مادربرد', value: it.motherboardCell),
            InfoRow(label: 'هارد', value: (it.hardDisk ?? '—').trim()),
            InfoRow(label: 'کارت گرافیک', value: (it.graphics ?? '—').trim()),
            InfoRow(label: 'مانیتور', value: (it.monitor ?? '—').trim()),
            InfoRow(label: 'سیستم‌عامل', value: (it.osName ?? '—').trim()),
            InfoRow(
              label: 'IP',
              value: it.ip.trim().isEmpty ? '—' : it.ip,
              ltr: true,
            ),
            const SizedBox(height: 6),
            const Text(
              'جزئیات قطعات (شماره سریال، ماژول‌های رم، درایوها) توسط ایجنت ثبت نشده است.',
              style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
            ),
          ] else ...[
            if ((hw.board?.computerModel ?? '').isNotEmpty ||
                (hw.board?.board ?? '').isNotEmpty) ...[
              _hwBlock(
                icon: Icons.desktop_windows_rounded,
                title: 'سیستم / مادربرد',
                value: (hw.board?.computerModel ?? '').isEmpty
                    ? '—'
                    : hw.board!.computerModel,
                sub: (hw.board?.board ?? '').isEmpty
                    ? null
                    : 'مادربرد: ${hw.board!.board}'
                          '${(hw.board?.boardSerial ?? '').isEmpty ? '' : ' — سریال: ${hw.board!.boardSerial}'}',
              ),
            ],
            for (final c in hw.cpus)
              _hwBlock(
                icon: Icons.memory_rounded,
                title: 'پردازنده',
                value: c.name,
                chips: [
                  if (c.cores > 0)
                    '${Fa.digits(c.cores)} هسته / ${Fa.digits(c.threads)} رشته',
                  if (c.clockGhz > 0) '${Fa.digits(c.clockGhz.toStringAsFixed(2))} GHz',
                ],
              ),
            if (hw.rams.isNotEmpty) ...[
              _hwBlock(
                icon: Icons.straighten_rounded,
                title: 'حافظه رم',
                value: '${Fa.digits(totalRam)} GB',
                chips: ['${Fa.digits(hw.rams.length)} ماژول'],
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ماژول‌های رم',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          for (var i = 0; i < hw.rams.length; i++)
                            Expanded(
                              flex: _maxInt(1, hw.rams[i].capacityGb),
                              child: Container(
                                height: 20,
                                alignment: Alignment.center,
                                color: _ramColors[i % _ramColors.length],
                                child: Text(
                                  '${Fa.digits(hw.rams[i].capacityGb)} GB',
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    for (final r in hw.rams)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${r.capacityGb} GB ${r.type}'
                          '${r.speedMhz > 0 ? ' — ${r.speedMhz} MHz' : ''}'
                          '${r.slot.isEmpty ? '' : ' — ${r.slot}'}'
                          '${r.manufacturer.isEmpty ? '' : ' — ${r.manufacturer}'}'
                          '${r.partNumber.isEmpty ? '' : ' ${r.partNumber}'}'
                          '${r.serialNumber.isEmpty || r.serialNumber == 'None' ? '' : ' — سریال: ${r.serialNumber}'}',
                          style: const TextStyle(
                            fontSize: 9,
                            height: 1.6,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (hw.disks.isNotEmpty) ...[
              _sectionLabel(
                'هارد دیسک‌ها',
                badge: Fa.digits(hw.disks.length),
              ),
              for (var i = 0; i < hw.disks.length; i++)
                _diskRow(hw.disks[i], i + 1, hw.disks),
            ],
            if (hw.gpus.isNotEmpty) ...[
              _sectionLabel('کارت گرافیک', badge: Fa.digits(hw.gpus.length)),
              for (final g in hw.gpus)
                InfoRow(
                  label: g.name.isEmpty ? '—' : g.name,
                  value: g.resolution.isEmpty ? '—' : g.resolution,
                  ltr: true,
                ),
            ],
            if (hw.monitors.isNotEmpty) ...[
              _sectionLabel('مانیتورها', badge: Fa.digits(hw.monitors.length)),
              for (final m in hw.monitors)
                InfoRow(
                  label: '${m.name}${m.isPrimary ? ' (اصلی)' : ''}',
                  value: [
                    if (m.resolution.isNotEmpty) m.resolution,
                    if (m.serialNumber.isNotEmpty && m.serialNumber != 'None')
                      'سریال: ${m.serialNumber}',
                  ].join(' — ').isEmpty
                      ? '—'
                      : [
                          if (m.resolution.isNotEmpty) m.resolution,
                          if (m.serialNumber.isNotEmpty &&
                              m.serialNumber != 'None')
                            'سریال: ${m.serialNumber}',
                        ].join(' — '),
                ),
            ],
            if (hw.netAdapters.isNotEmpty) ...[
              _sectionLabel(
                'شبکه و آی‌پی',
                badge: '${Fa.digits(hw.netAdapters.length)} کارت',
              ),
              for (final n in hw.netAdapters)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xfff7f9fd),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.name,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: ShopColors.ink,
                              ),
                            ),
                          ),
                          ShopTag(text: n.typeFa, color: ShopColors.inkFaint),
                          if (n.ipv4.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            ShopTag(text: n.ipv4, color: ShopColors.ok),
                          ],
                        ],
                      ),
                      if (n.gateway.isNotEmpty)
                        Text(
                          'گیت‌وی: ${n.gateway}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 9,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      if (n.macAddress.isNotEmpty)
                        Text(
                          'MAC: ${n.macAddress}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 9,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      if (n.description.isNotEmpty && n.description != n.name)
                        Text(
                          n.description,
                          style: const TextStyle(
                            fontSize: 9,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            if (hw.volumes.isNotEmpty) ...[
              _sectionLabel('درایوها — حجم استفاده‌شده'),
              for (final v in hw.volumes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${v.letter}${v.label.isEmpty ? '' : ' — ${v.label}'}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: ShopColors.ink,
                              ),
                            ),
                          ),
                          ShopTag(
                            text:
                                '${Fa.digits(v.usedGb)} GB از ${Fa.digits(v.totalGb)} GB',
                            color: ShopColors.seed,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      MiniBar(
                        pct: v.usedPct,
                        color: v.usedPct >= 90
                            ? ShopColors.danger
                            : v.usedPct >= 75
                            ? ShopColors.warn
                            : ShopColors.teal,
                        height: 7,
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

  static const _ramColors = [
    Color(0xff4f8cff),
    Color(0xff8e5cff),
    Color(0xff0ea5a4),
    Color(0xfff4a23c),
    Color(0xff2ec47e),
  ];

  Widget _sectionLabel(String title, {String? badge}) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 5),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: ShopColors.inkSoft,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 5),
          ShopTag(text: badge, color: ShopColors.seed),
        ],
      ],
    ),
  );

  Widget _hwBlock({
    required IconData icon,
    required String title,
    required String value,
    String? sub,
    List<String> chips = const [],
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xfff7f9fd),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShopColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ShopColors.seed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: ShopColors.seed),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.ink,
                    height: 1.5,
                  ),
                ),
                if (chips.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final c in chips)
                          ShopTag(text: c, color: ShopColors.accent),
                      ],
                    ),
                  ),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 9,
                        color: ShopColors.inkFaint,
                        height: 1.6,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diskRow(SystemDiskRow d, int index, List<SystemDiskRow> all) {
    final maxGb = all.isEmpty
        ? 1
        : all.map((e) => e.sizeGb).reduce((a, b) => a > b ? a : b);
    final pct = maxGb > 0 ? ((d.sizeGb * 100) / maxGb).round() : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: d.smartBad ? const Color(0xfffdefee) : const Color(0xfff7f9fd),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: d.smartBad ? const Color(0xfff3b8b5) : ShopColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Fa.digits(index)}. ${d.model.isEmpty ? '—' : d.model}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              if (d.interface.isNotEmpty)
                ShopTag(text: d.interface, color: ShopColors.inkFaint),
              const SizedBox(width: 4),
              ShopTag(
                text: '${Fa.digits(d.sizeGb)} GB',
                color: ShopColors.seed,
              ),
              if (d.smartStatus != null) ...[
                const SizedBox(width: 4),
                ShopTag(
                  text: d.smartBad
                      ? 'SMART: ${d.smartStatus}'
                      : 'SMART: ${d.smartStatus}',
                  color: d.smartBad ? ShopColors.danger : ShopColors.ok,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          MiniBar(pct: pct, color: ShopColors.accent, height: 6),
          if (d.serialNumber.isNotEmpty && d.serialNumber != 'None')
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'سریال: ${d.serialNumber}',
                style: const TextStyle(
                  fontSize: 8.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- اختصاص کاربر ----------------

  Widget _assignCard() {
    return SystemCard(
      title: 'اختصاص کاربر به این سیستم',
      icon: Icons.person_add_alt_1_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('شرکت'),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: _selCompanyId > 0 ? _selCompanyId : null,
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ShopColors.ink,
                      ),
                      decoration: _ddDecoration('جستجو و انتخاب شرکت…'),
                      items: [
                        for (final c in _companies.where((c) => c.isActive))
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _selCompanyId = v ?? 0;
                        _selUserId = 0;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_companies.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'هنوز شرکتی ثبت نشده — از بخش شرکت‌ها بسازید',
                style: TextStyle(fontSize: 9.5, color: ShopColors.warn),
              ),
            ),
          const SizedBox(height: 10),
          const _Label('کاربر'),
          const SizedBox(height: 4),
          if (_selCompanyId == 0)
            const Text(
              'اول شرکت را انتخاب کنید…',
              style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _selUserId > 0 ? _selUserId : null,
              isDense: true,
              style: const TextStyle(fontSize: 11, color: ShopColors.ink),
              decoration: _ddDecoration('جستجوی نام / شماره پرسنلی…'),
              items: [
                for (final u in _companyUsers)
                  DropdownMenuItem(
                    value: u.id,
                    child: Text(
                      u.lookupLabel,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _selUserId = v ?? 0),
            ),
          if (_selCompanyId > 0 && _companyUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'کاربری برای این شرکت نیست — از «کاربران سیستم» کاربر اضافه کنید',
                style: TextStyle(fontSize: 9.5, color: ShopColors.warn),
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ShopColors.seed,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
              onPressed: (_busy || _selCompanyId == 0 || _selUserId <= 0)
                  ? null
                  : _assign,
              icon: const Icon(Icons.link_rounded, size: 15),
              label: const Text(
                'اختصاص کاربر',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _ddDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    filled: true,
    fillColor: const Color(0xfff7f9fd),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ShopColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ShopColors.line),
    ),
  );

  // ---------------- سابقهٔ کاربری ----------------

  Widget _userHistoryCard() {
    return SystemCard(
      title: 'سابقهٔ کاربری سیستم',
      icon: Icons.badge_rounded,
      trailing: ShopTag(
        text: '${Fa.digits(_userHistory.length)} رکورد',
        color: ShopColors.inkFaint,
      ),
      child: _userHistory.isEmpty
          ? const Text(
              'هنوز سابقه‌ی کاربری برای این سیستم ثبت نشده است. با هر «اختصاص کاربر» یک رکورد جدید ثبت می‌شود.',
              style: TextStyle(
                fontSize: 10,
                height: 1.7,
                color: ShopColors.inkFaint,
              ),
            )
          : Column(
              children: [
                for (final h in _userHistory)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xfff7f9fd),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ShopColors.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.userName.isEmpty ? '—' : h.userName,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: ShopColors.ink,
                                ),
                              ),
                              Text(
                                'از ${Fa.date(h.fromAt?.toUtc().toIso8601String())}'
                                '${h.toAt == null ? ' — تاکنون' : ' تا ${Fa.date(h.toAt!.toUtc().toIso8601String())}'}',
                                style: const TextStyle(
                                  fontSize: 8.8,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                              if ((h.companyName ?? '').isNotEmpty)
                                Text(
                                  h.companyName!,
                                  style: const TextStyle(
                                    fontSize: 8.8,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ShopTag(
                          text: h.isOpen ? 'جاری' : 'تحویل شده',
                          color: h.isOpen ? ShopColors.ok : ShopColors.inkFaint,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  // ---------------- تحویل دیجیتال ----------------

  Widget _handoverCard() {
    return SystemCard(
      title: 'چک‌لیست تحویل دیجیتال با امضا',
      icon: Icons.inventory_rounded,
      trailing: TextButton.icon(
        onPressed: _itemMissing ? null : _openHandoverSheet,
        icon: const Icon(Icons.add_rounded, size: 14),
        label: const Text(
          'ثبت تحویل جدید',
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
      ),
      child: _handovers.isEmpty
          ? const Text(
              'هنوز تحویلی ثبت نشده است. با «ثبت تحویل جدید»، چک‌لیست را تکمیل و با امضای دیجیتال تحویل را ثبت کنید.',
              style: TextStyle(
                fontSize: 10,
                height: 1.7,
                color: ShopColors.inkFaint,
              ),
            )
          : Column(
              children: [
                for (final h in _handovers)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xfff7f9fd),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ShopColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'تحویل #${Fa.digits(h.id)}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: ShopColors.ink,
                                ),
                              ),
                            ),
                            ShopTag(
                              text: h.isCompleted ? 'تکمیل شده' : 'در جریان',
                              color: h.isCompleted
                                  ? ShopColors.ok
                                  : ShopColors.warn,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'از ${h.fromUserName.isEmpty ? '—' : h.fromUserName} به ${h.toUserName.isEmpty ? '—' : h.toUserName}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: ShopColors.inkSoft,
                          ),
                        ),
                        Text(
                          Fa.date(h.createdAt?.toUtc().toIso8601String()),
                          style: const TextStyle(
                            fontSize: 8.8,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final c in h.checklist)
                              ShopTag(
                                text: '${c.checked ? '✓' : '✕'} ${c.fa}',
                                color: c.checked
                                    ? ShopColors.ok
                                    : ShopColors.inkFaint,
                              ),
                          ],
                        ),
                        if ((h.note ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              h.note!,
                              style: const TextStyle(
                                fontSize: 9,
                                color: ShopColors.inkSoft,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  // ---------------- دستور از راه دور ----------------

  Widget _commandsCard() {
    return SystemCard(
      title: 'دستور از راه دور (اجرا توسط ایجنت سیستم)',
      icon: Icons.rocket_launch_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _cmdButton(
                  'ری‌استارت',
                  Icons.restart_alt_rounded,
                  ShopColors.warn,
                  () => _sendCommand('Reboot'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _cmdButton(
                  'خاموش کردن',
                  Icons.power_settings_new_rounded,
                  ShopColors.danger,
                  () => _sendCommand('Shutdown'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _cmdButton(
                  'قفل صفحه',
                  Icons.lock_rounded,
                  ShopColors.inkSoft,
                  () => _sendCommand('Lock'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_commands.isEmpty)
            const Text(
              'هنوز دستوری ارسال نشده است. دستورهای ارسال‌شده توسط ایجنت سیستم اجرا و نتیجه‌شان اینجا ثبت می‌شود.',
              style: TextStyle(
                fontSize: 10,
                height: 1.7,
                color: ShopColors.inkFaint,
              ),
            )
          else
            for (final c in _commands)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xfff7f9fd),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShopColors.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.actionFa,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: ShopColors.ink,
                            ),
                          ),
                          Text(
                            '${Fa.date(c.createdAt?.toUtc().toIso8601String())} — توسط ${c.byUserFa}',
                            style: const TextStyle(
                              fontSize: 8.8,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                          if ((c.result ?? '').isNotEmpty)
                            Text(
                              c.result!,
                              style: const TextStyle(
                                fontSize: 9,
                                color: ShopColors.inkSoft,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ShopTag(
                      text: c.statusFa,
                      color: c.status == 'Completed'
                          ? ShopColors.ok
                          : c.status == 'Failed'
                          ? ShopColors.danger
                          : ShopColors.warn,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _cmdButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
      ),
      onPressed: _busy ? null : onTap,
      child: Column(
        children: [
          Icon(icon, size: 15),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      color: ShopColors.inkSoft,
    ),
  );
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w900,
      color: ShopColors.inkSoft,
    ),
  );
}

class _ThText extends StatelessWidget {
  const _ThText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      color: ShopColors.inkFaint,
    ),
  );
}

int _maxInt(int a, int b) => a > b ? a : b;

/// مودال «چک‌لیست تحویل دیجیتال — سیستم #id»
class _HandoverSheet extends StatefulWidget {
  const _HandoverSheet({
    required this.repo,
    required this.system,
    required this.users,
  });

  final SystemRepository repo;
  final SystemInfoItem? system;
  final List<SystemUserRow> users;

  @override
  State<_HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends State<_HandoverSheet> {
  late List<HandoverCheck> _items;
  int _toUserId = 0;
  late final TextEditingController _fromName;
  final _note = TextEditingController();
  String _signature = '';
  String _error = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _items = kHandoverChecklist.map((e) => e.copyWith(checked: false)).toList();
    final current = widget.system?.userId;
    _toUserId = current ?? 0;
    final from = widget.users.where((u) => u.id == current).toList();
    _fromName = TextEditingController(
      text: from.isEmpty ? '' : from.first.fullName,
    );
  }

  @override
  void dispose() {
    _fromName.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _sign() async {
    final result = await showSignaturePadSheet(
      context,
      signerName: _fromName.text.trim().isEmpty ? 'تحویل‌دهنده' : _fromName.text,
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _signature = result);
    }
  }

  Future<void> _submit() async {
    setState(() => _error = '');
    if (_toUserId <= 0) {
      setState(() => _error = 'گیرنده‌ی تحویل را انتخاب کنید.');
      return;
    }
    if (_signature.trim().isEmpty) {
      setState(() => _error = 'امضا الزامی است — در بوم امضا خط بکشید.');
      return;
    }
    if (_items.any((e) => !e.checked)) {
      setState(() => _error = 'همه‌ی آیتم‌های چک‌لیست را تیک بزنید.');
      return;
    }
    final to = widget.users.where((u) => u.id == _toUserId).toList();
    final toName = to.isEmpty ? '' : to.first.fullName;
    setState(() => _busy = true);
    try {
      await widget.repo.handover(
        id: widget.system?.id ?? 0,
        fromUserName: _fromName.text.trim(),
        toUserId: _toUserId,
        toUserName: toName,
        checklist: _items,
        signatureDataUrl: _signature,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'ثبت تحویل ناموفق بود. ${e.toString().replaceFirst('ApiException: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: ShopColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: ShopColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 8, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_rounded,
                    size: 17,
                    color: ShopColors.ok,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'چک‌لیست تحویل دیجیتال — سیستم #${Fa.digits(widget.system?.id ?? 0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SystemNote(
                        text: _error,
                        color: ShopColors.danger,
                        icon: Icons.error_outline_rounded,
                      ),
                    ),
                  SystemCard(
                    title: 'گیرنده و تحویل‌دهنده',
                    icon: Icons.people_alt_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('گیرنده‌ی سیستم *'),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          initialValue: _toUserId > 0 ? _toUserId : null,
                          isDense: true,
                          style: const TextStyle(
                            fontSize: 11,
                            color: ShopColors.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: 'جستجوی کاربر گیرنده…',
                            hintStyle: const TextStyle(
                              fontSize: 10,
                              color: ShopColors.inkFaint,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: const Color(0xfff7f9fd),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: ShopColors.line,
                              ),
                            ),
                          ),
                          items: [
                            for (final u in widget.users.where(
                              (u) => u.isActive,
                            ))
                              DropdownMenuItem(
                                value: u.id,
                                child: Text(
                                  u.lookupLabel,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _toUserId = v ?? 0),
                        ),
                        const SizedBox(height: 10),
                        const _Label('تحویل‌دهنده'),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _fromName,
                          style: const TextStyle(fontSize: 11.5),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: const Color(0xfff7f9fd),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: ShopColors.line,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SystemCard(
                    title: 'چک‌لیست تحویل * — همه‌ی موارد الزامی است',
                    icon: Icons.checklist_rounded,
                    child: Column(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          InkWell(
                            onTap: () => setState(() {
                              _items[i] = _items[i].copyWith(
                                checked: !_items[i].checked,
                              );
                            }),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _items[i].checked,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (v) => setState(() {
                                    _items[i] = _items[i].copyWith(
                                      checked: v ?? false,
                                    );
                                  }),
                                ),
                                Expanded(
                                  child: Text(
                                    _items[i].fa,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      height: 1.6,
                                      color: ShopColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  SystemCard(
                    title: 'امضای دیجیتال *',
                    icon: Icons.draw_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_signature.isEmpty)
                          const Text(
                            'با لمس «امضا» در بوم امضا خط بکشید.',
                            style: TextStyle(
                              fontSize: 10,
                              color: ShopColors.inkFaint,
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ShopColors.line),
                            ),
                            child: Image.memory(
                              Uint8List.fromList(_decodeDataUrl(_signature)),
                              height: 90,
                              fit: BoxFit.contain,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: ShopColors.seed,
                                minimumSize: const Size(0, 34),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                              onPressed: _sign,
                              icon: const Icon(Icons.gesture_rounded, size: 14),
                              label: const Text(
                                'امضا',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 34),
                                foregroundColor: ShopColors.inkSoft,
                                side: const BorderSide(color: ShopColors.line),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                              onPressed: () => setState(() => _signature = ''),
                              icon: const Icon(Icons.cleaning_services_rounded,
                                  size: 14),
                              label: const Text(
                                'پاک کردن',
                                style: TextStyle(fontSize: 10.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SystemCard(
                    title: 'توضیح (اختیاری)',
                    icon: Icons.notes_rounded,
                    child: TextField(
                      controller: _note,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: InputDecoration(
                        hintText: 'توضیح تحویل…',
                        hintStyle: const TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.inkFaint,
                        ),
                        filled: true,
                        fillColor: const Color(0xfff7f9fd),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: ShopColors.line),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ShopColors.ok,
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(21),
                        ),
                      ),
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.draw_rounded, size: 15),
                      label: Text(
                        _busy ? 'در حال ثبت…' : 'ثبت و امضای تحویل',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
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
}

/// تبدیل data-url «data:image/png;base64,...» به بایت
List<int> _decodeDataUrl(String dataUrl) {
  final idx = dataUrl.indexOf('base64,');
  final b64 = idx >= 0 ? dataUrl.substring(idx + 7) : dataUrl;
  try {
    return base64Decode(b64);
  } catch (_) {
    return const [];
  }
}
