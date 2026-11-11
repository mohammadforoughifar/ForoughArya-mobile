// ============================================================
//  «مدیریت آی‌پی» (IPAM) — فاز ۹-د
//  آینهٔ `Pages/ItAssets/IpManagement.razor` (مسیر وب: /ip-management)
//
//  • سرصفحه «مدیریت آی‌پی» + انتخاب شرکت
//  • کارت رنج‌ها با نوار ثبت‌شده / اشغال بدون شناسنامه؛ «رنج جدید»
//  • پنل رنج انتخاب‌شده: ماسک، گیت‌وی، VLAN، DNS، DHCP، محل،
//    آخرین اسکن («هنوز اسکن نشده — …»)، «اسکن رنج» / بازخوانی / ویرایش / حذف
//  • نوار پیشرفت اسکن با فاز و شمارنده
//  • راهنمای کلیک‌پذیر: همه / خالی / ثبت در شناسنامه / اشغال بدون شناسنامه / تداخل
//  • جست‌وجو: آی‌پی، نام دستگاه، MAC، صاحب… / نمای شبکه‌ای و فهرست
//  • سلول‌های /24 با تگ GW، سایهٔ DHCP، غیرفعال برای network/broadcast
//  • «اولین آی‌پی خالی» با کپی و رزرو
//  • کشوی جزئیات با بررسی همین الان، شناسنامه‌ها و رزرو/آزاد کردن
//  • مودال رنج با همان اعتبارسنجی‌ها و بنر «اسکن از روی سرور برنامه انجام می‌شود…»
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/ipam_repository.dart';
import '../data/it_perms.dart';
import '../models/ipam_models.dart';
import '../models/server_models.dart' show agoFa;
import 'system_style.dart';

enum _IpFilter { all, free, registered, unregistered, problem }

class IpamPage extends StatefulWidget {
  const IpamPage({super.key});

  @override
  State<IpamPage> createState() => _IpamPageState();
}

class _IpamPageState extends State<IpamPage> {
  late final IpamRepository _repo;
  late final ItPerms _perms;

  List<IpamCompanyRow> _companies = const [];
  List<IpSubnetRow> _subnets = const [];
  IpamMap? _map;
  int _companyId = 0;
  int _subnetId = 0;

  bool _loading = true;
  bool _mapLoading = false;
  String? _error;

  _IpFilter _filter = _IpFilter.all;
  bool _gridView = true;
  final _search = TextEditingController();
  Timer? _poll;

  bool _scanBusy = false;

  @override
  void initState() {
    super.initState();
    _repo = IpamRepository(context.read<ApiClient>());
    _perms = ItPerms(context.read<AuthController>().session);
    _loadCompanies();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _search.dispose();
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  bool get _canView => _perms.has('Ipam.View');
  bool get _canCreate => _perms.has('Ipam.Create');
  bool get _canUpdate => _perms.has('Ipam.Update');
  bool get _canDelete => _perms.has('Ipam.Delete');
  bool get _canScan => _perms.has('Ipam.Scan');

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
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.companies();
      if (!mounted) return;
      setState(() {
        _companies = list;
        _companyId = list.isEmpty ? 0 : list.first.id;
        _loading = false;
      });
      if (_companyId > 0) await _loadSubnets();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(e);
      });
    }
  }

  Future<void> _loadSubnets({int? selectId}) async {
    if (_companyId <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.subnets(_companyId);
      if (!mounted) return;
      final want = selectId ?? (_subnetId > 0 ? _subnetId : 0);
      final exists = list.any((s) => s.id == want);
      final target = exists
          ? want
          : (list.isEmpty ? 0 : list.first.id);
      setState(() {
        _subnets = list;
        _subnetId = target;
        _loading = false;
      });
      if (target > 0) await _loadMap();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(e);
      });
    }
  }

  Future<void> _loadMap() async {
    if (_subnetId <= 0) return;
    setState(() => _mapLoading = true);
    try {
      final m = await _repo.map(_subnetId);
      if (!mounted) return;
      setState(() {
        _map = m;
        _mapLoading = false;
      });
      _syncPolling(m.scan);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mapLoading = false);
      _toast(_clean(e), error: true);
    }
  }

  void _syncPolling(IpamScanStatus? scan) {
    final running = scan?.running == true;
    if (running) {
      _poll ??= Timer.periodic(const Duration(seconds: 3), (_) async {
        if (!mounted) return;
        final st = await _repo.scanStatus(_subnetId);
        if (!mounted) return;
        if (st != null && st.running) {
          setState(() {
            _map = _map == null ? null : _withScan(_map!, st);
          });
        } else {
          _poll?.cancel();
          _poll = null;
          await _loadMap();
          await _refreshSubnetRow();
        }
      });
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  IpamMap _withScan(IpamMap m, IpamScanStatus st) => IpamMap(
    subnet: m.subnet,
    stats: m.stats,
    hosts: m.hosts,
    scan: st,
  );

  Future<void> _refreshSubnetRow() async {
    try {
      final list = await _repo.subnets(_companyId);
      if (!mounted) return;
      setState(() => _subnets = list);
    } catch (_) {}
  }

  // ---------------- اقدامات ----------------

  Future<void> _startScan() async {
    if (_subnetId <= 0) return;
    setState(() => _scanBusy = true);
    try {
      await _repo.startScan(_subnetId);
      _toast('اسکن رنج آغاز شد.');
      await _loadMap();
    } catch (e) {
      _toast(_clean(e), error: true);
    } finally {
      if (mounted) setState(() => _scanBusy = false);
    }
  }

  Future<void> _openSubnetForm({IpSubnetRow? subnet}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubnetFormSheet(
        repo: _repo,
        companyId: _companyId,
        subnet: subnet,
        current: subnet == null ? null : _map?.subnet,
      ),
    );
    if (saved == true) {
      _toast(subnet == null ? 'رنج ثبت شد.' : 'رنج ذخیره شد.');
      await _loadSubnets(selectId: subnet?.id);
    }
  }

  Future<void> _deleteSubnet() async {
    final s = _currentRow;
    if (s == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حذف رنج',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'رنج «${s.name}» (${s.cidr}) و رزروهای آن حذف شود؟ این کار قابل بازگشت نیست.',
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
      await _repo.deleteSubnet(s.id);
      _toast('رنج حذف شد.');
      setState(() {
        _subnetId = 0;
        _map = null;
      });
      await _loadSubnets();
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  Future<void> _openCell(IpHost h) async {
    if (_map == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IpCellSheet(
        repo: _repo,
        subnet: _map!.subnet,
        host: h,
        canUpdate: _canUpdate,
      ),
    );
    if (changed == true) {
      await _loadMap();
      await _refreshSubnetRow();
    }
  }

  Future<void> _reserveFirstFree() async {
    final free = (_map?.hosts ?? []).where((h) => h.isFree).toList();
    if (free.isEmpty) {
      _toast('آی‌پی خالی در این رنج وجود ندارد.', error: true);
      return;
    }
    final target = free.first;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IpReserveSheet(
        repo: _repo,
        subnetId: _map!.subnet.id,
        ip: target.ip,
        host: target,
      ),
    );
    if (ok == true) {
      _toast('آی‌پی ${target.ip} رزرو شد.');
      await _loadMap();
      await _refreshSubnetRow();
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _toast('آی‌پی $text کپی شد.');
  }

  // ---------------- فیلتر ----------------

  bool _matches(IpHost h, String q) {
    if (q.isEmpty) return true;
    final t = q.toLowerCase();
    if (h.ip.contains(t)) return true;
    if ((h.hostname ?? '').toLowerCase().contains(t)) return true;
    if ((h.mac ?? '').toLowerCase().contains(t)) return true;
    if ((h.method ?? '').toLowerCase().contains(t)) return true;
    for (final o in h.owners) {
      if (o.title.toLowerCase().contains(t)) return true;
      if ((o.detail ?? '').toLowerCase().contains(t)) return true;
    }
    final r = h.reserved;
    if (r != null) {
      if ((r.title ?? '').toLowerCase().contains(t)) return true;
      if ((r.owner ?? '').toLowerCase().contains(t)) return true;
    }
    return false;
  }

  bool _passFilter(IpHost h) {
    final problem = h.conflict || (h.macMismatch ?? '').isNotEmpty;
    return switch (_filter) {
      _IpFilter.all => true,
      _IpFilter.free => h.isFree,
      _IpFilter.registered => h.isRegistered,
      _IpFilter.unregistered => h.isUnregistered,
      _IpFilter.problem => problem,
    };
  }

  IpSubnetRow? get _currentRow {
    for (final s in _subnets) {
      if (s.id == _subnetId) return s;
    }
    return null;
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
          'مدیریت آی‌پی',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadSubnets(),
            tooltip: 'بازخوانی',
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      body: !_canView
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SystemNote(
                text: 'شما مجوز مشاهدهٔ مدیریت آی‌پی را ندارید.',
                color: ShopColors.warn,
                icon: Icons.lock_outline_rounded,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
              children: [
                const ShopHeader(
                  title: 'مدیریت آی‌پی',
                  subtitle:
                      'نقشهٔ رنج‌های شبکه، شناسنامهٔ هر آی‌پی و کشف خودکار دستگاه‌های متصل',
                  icon: Icons.hub_rounded,
                  badge: 'IPAM',
                ),
                const SizedBox(height: 12),
                if (_loading && _subnets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 50),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  SystemNote(
                    text: 'بارگذاری رنج‌ها ناموفق بود — $_error',
                    color: ShopColors.danger,
                    icon: Icons.cloud_off_rounded,
                  )
                else ...[
                  if (_companies.length > 1) _companyPicker(),
                  _subnetListCard(),
                  const SizedBox(height: 10),
                  if (_map == null)
                    const SystemNote(
                      text:
                          'برای شروع، یک رنج شبکه با CIDR (مثل 192.168.30.0/24) ثبت کنید. پس از ثبت می‌توانید نقشهٔ خانه‌به‌خانه و شناسنامهٔ هر آی‌پی را ببینید.',
                      color: ShopColors.seed,
                      icon: Icons.info_outline_rounded,
                    )
                  else ...[
                    _subnetPanel(),
                    const SizedBox(height: 10),
                    _scanProgress(),
                    const SizedBox(height: 10),
                    _legend(),
                    const SizedBox(height: 10),
                    _toolbar(),
                    const SizedBox(height: 8),
                    if (_mapLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_gridView)
                      _grid()
                    else
                      _list(),
                    const SizedBox(height: 12),
                    const SystemNote(
                      text:
                          'اسکن از روی سرور برنامه انجام می‌شود و به شبکهٔ مبدأ همان سرور محدود است؛ حداکثر اندازهٔ هر رنج /۲۲ است. آی‌پی‌های خالی فقط با اسکن شناسایی می‌شوند و رزرو دستی مانع از آن نمی‌شود.',
                      color: ShopColors.seed,
                      icon: Icons.radar_rounded,
                    ),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _companyPicker() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShopColors.line),
      ),
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
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _companyId = v;
            _subnetId = 0;
            _map = null;
          });
          _loadSubnets();
        },
      ),
    ),
  );

  Widget _subnetListCard() {
    return Container(
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            decoration: const BoxDecoration(
              color: Color(0xfff7f9fd),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: ShopColors.line)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lan_rounded,
                  size: 14,
                  color: ShopColors.inkSoft,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'رنج‌های شبکه',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (_canCreate)
                  TextButton.icon(
                    onPressed: () => _openSubnetForm(),
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text(
                      'رنج جدید',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_subnets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'هنوز رنجی ثبت نشده است.',
                style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
              ),
            )
          else
            for (final s in _subnets) _subnetTile(s),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _subnetTile(IpSubnetRow s) {
    final selected = s.id == _subnetId;
    return Material(
      color: selected ? ShopColors.seed.withValues(alpha: 0.06) : Colors.transparent,
      child: InkWell(
        onTap: () async {
          setState(() => _subnetId = s.id);
          await _loadMap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 14,
                    color: selected ? ShopColors.seed : ShopColors.inkFaint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? ShopColors.seed : ShopColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    s.cidr,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 10,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                  if (s.scanning) ...[
                    const SizedBox(width: 5),
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 5,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (s.registered * 100).clamp(1, 100000).toInt(),
                        child: Container(color: ShopColors.ok),
                      ),
                      Expanded(
                        flex: (s.unregistered * 100).clamp(1, 100000).toInt(),
                        child: Container(color: ShopColors.warn),
                      ),
                      Expanded(
                        flex: (s.free * 100).clamp(1, 100000).toInt(),
                        child: Container(color: const Color(0xffe8edf6)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ثبت‌شده ${Fa.digits(s.registered)} · بدون شناسنامه ${Fa.digits(s.unregistered)} · خالی ${Fa.digits(s.free)} — '
                'آخرین اسکن: ${s.lastScanAt == null ? 'هنوز اسکن نشده' : Fa.date(s.lastScanAt!.toIso8601String())}',
                style: const TextStyle(fontSize: 9, color: ShopColors.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subnetPanel() {
    final sub = _map!.subnet;
    final row = _currentRow;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.router_outlined,
                size: 16,
                color: ShopColors.teal,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.name.isEmpty ? (row?.name ?? '') : sub.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      sub.cidr,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 10,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (_canUpdate)
                IconButton(
                  onPressed: () => _openSubnetForm(subnet: _currentRow),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'ویرایش رنج',
                  icon: const Icon(Icons.edit_rounded, size: 16),
                ),
              if (_canDelete)
                IconButton(
                  onPressed: _deleteSubnet,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'حذف رنج',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: ShopColors.danger,
                  ),
                ),
            ],
          ),
          const Divider(height: 16),
          InfoRow(label: 'ماسک', value: sub.mask, ltr: true),
          InfoRow(label: 'گیت‌وی', value: sub.gateway ?? '—', ltr: true),
          InfoRow(label: 'broadcast', value: sub.broadcast, ltr: true),
          InfoRow(label: 'VLAN', value: (sub.vlan ?? 0) > 0 ? '${sub.vlan}' : '—', ltr: true),
          InfoRow(label: 'DNS', value: sub.dnsServers ?? '—'),
          InfoRow(label: 'DHCP', value: sub.dhcpRange ?? '—', ltr: true),
          InfoRow(label: 'محل', value: sub.location ?? '—'),
          if ((sub.description ?? '').isNotEmpty)
            InfoRow(label: 'توضیحات', value: sub.description!),
          InfoRow(
            label: 'آخرین اسکن',
            value: sub.lastScanAt == null
                ? 'هنوز اسکن نشده'
                : '${Fa.date(sub.lastScanAt!.toIso8601String())} · '
                      '${Fa.digits(sub.lastScanAliveCount)} دستگاه روشن · '
                      '${sub.durationFa} ثانیه',
          ),
          InfoRow(
            label: 'اسکن خودکار',
            value: sub.autoScanMinutes <= 0
                ? 'خاموش (فقط دستی)'
                : 'هر ${Fa.digits(sub.autoScanMinutes)} دقیقه',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_canScan)
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.teal,
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                    onPressed: _scanBusy ? null : _startScan,
                    icon: const Icon(Icons.radar_rounded, size: 15),
                    label: Text(
                      _scanBusy ? 'در حال آغاز…' : 'اسکن رنج',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (_canScan) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    foregroundColor: ShopColors.inkSoft,
                    side: const BorderSide(color: ShopColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  onPressed: _loadMap,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text(
                    'بازخوانی',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
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

  Widget _scanProgress() {
    final scan = _map?.scan;
    if (scan == null) return const SizedBox.shrink();
    if (!scan.running && (scan.error ?? '').isEmpty) return const SizedBox.shrink();
    final total = scan.total > 0 ? scan.total : 1;
    final value = (scan.scanned / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scan.error != null
            ? ShopColors.danger.withValues(alpha: 0.07)
            : ShopColors.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (scan.error != null ? ShopColors.danger : ShopColors.teal)
              .withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                scan.error != null ? Icons.error_outline_rounded : Icons.radar_rounded,
                size: 14,
                color: scan.error != null ? ShopColors.danger : ShopColors.teal,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  scan.error != null
                      ? 'اسکن ناموفق: ${scan.error}'
                      : 'در حال اسکن — ${scan.phase ?? ''}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: scan.error != null
                        ? ShopColors.danger
                        : ShopColors.teal,
                  ),
                ),
              ),
              Text(
                '${Fa.digits(scan.scanned)} / ${Fa.digits(scan.total)}',
                style: const TextStyle(
                  fontSize: 9,
                  color: ShopColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: scan.error != null ? 1 : value,
              minHeight: 6,
              backgroundColor: Colors.white,
              color: scan.error != null ? ShopColors.danger : ShopColors.teal,
            ),
          ),
          if (scan.error == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'پیداشده: ${Fa.digits(scan.found)}'
                '${(scan.startedBy ?? '').isEmpty ? '' : ' · شروع‌کننده: ${scan.startedBy}'}',
                style: const TextStyle(
                  fontSize: 8.8,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend() {
    final st = _map!.stats;
    final items = [
      (_IpFilter.all, 'همه', st.total, ShopColors.seed),
      (_IpFilter.free, 'خالی', st.free, const Color(0xffe8edf6)),
      (_IpFilter.registered, 'ثبت در شناسنامه', st.registered, ShopColors.ok),
      (_IpFilter.unregistered, 'اشغال بدون شناسنامه', st.unregistered, ShopColors.warn),
      (_IpFilter.problem, 'تداخل / هشدار', _map!.problemCount, ShopColors.danger),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final it in items)
          GestureDetector(
            onTap: () => setState(() => _filter = it.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: _filter == it.$1
                    ? it.$4.withValues(alpha: 0.16)
                    : ShopColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _filter == it.$1
                      ? it.$4.withValues(alpha: 0.5)
                      : ShopColors.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: it.$4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${it.$2} (${Fa.digits(it.$3)})',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _filter == it.$1 ? it.$4 : ShopColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _toolbar() {
    final firstFree = (_map!.hosts).where((h) => h.isFree).toList();
    final target = firstFree.isEmpty ? null : firstFree.first;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'جست‌وجو: آی‌پی، نام دستگاه، MAC، صاحب…',
                  hintStyle: const TextStyle(
                    fontSize: 10,
                    color: ShopColors.inkFaint,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: ShopColors.inkFaint,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: ShopColors.surface,
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
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: ShopColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ShopColors.line),
              ),
              child: Row(
                children: [
                  _viewBtn(Icons.grid_view_rounded, true, 'نمای شبکه‌ای'),
                  _viewBtn(Icons.list_rounded, false, 'نمای فهرست'),
                ],
              ),
            ),
          ],
        ),
        if (target != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: ShopColors.line),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: ShopColors.ok,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'اولین آی‌پی خالی: ${target.ip}',
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.ok,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copy(target.ip),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'کپی',
                  icon: const Icon(Icons.copy_rounded, size: 15),
                ),
                if (_canUpdate)
                  TextButton(
                    onPressed: _reserveFirstFree,
                    child: const Text(
                      'رزرو',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _viewBtn(IconData icon, bool grid, String tooltip) {
    final active = _gridView == grid;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _gridView = grid),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: active ? ShopColors.seed : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 15,
            color: active ? Colors.white : ShopColors.inkFaint,
          ),
        ),
      ),
    );
  }

  List<IpHost> get _visibleHosts {
    final q = _search.text.trim().toLowerCase();
    return _map!.hosts
        .where((h) => _passFilter(h) && _matches(h, q))
        .toList();
  }

  Widget _grid() {
    final hosts = _visibleHosts;
    if (hosts.isEmpty) {
      return const ShopEmpty(
        title: 'آی‌پی‌ای با این فیلتر پیدا نشد',
        subtitle: 'فیلتر یا عبارت جست‌وجو را تغییر دهید.',
        icon: Icons.search_off_rounded,
      );
    }
    // بلوک‌بندی /24 — همان `n>>8` وب
    final blocks = <int, List<IpHost>>{};
    for (final h in hosts) {
      blocks.putIfAbsent(h.num >> 8, () => []).add(h);
    }
    final keys = blocks.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final k in keys)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_map!.subnet.cidr} → ${ipFromNum(k << 8)}x',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final h in blocks[k]!) _cell(h),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(IpHost h) {
    final sub = _map!.subnet;
    final isNetwork = h.num == sub.networkNum;
    final isBroadcast = h.ip == sub.broadcast;
    final isGateway = (sub.gateway ?? '') == h.ip;
    final (d0, d1) = parseDhcpRange(sub.dhcpRange);
    final inDhcp = d0 != 0 && h.num >= d0 && h.num <= d1;
    final problem = h.conflict || (h.macMismatch ?? '').isNotEmpty;

    Color bg;
    Color fg;
    Color border;
    if (isNetwork || isBroadcast) {
      bg = const Color(0xfff1f4f9);
      fg = ShopColors.inkFaint;
      border = ShopColors.line;
    } else if (problem) {
      bg = ShopColors.danger.withValues(alpha: 0.14);
      fg = ShopColors.danger;
      border = ShopColors.danger.withValues(alpha: 0.4);
    } else if (h.isRegistered) {
      bg = h.alive
          ? ShopColors.ok.withValues(alpha: 0.16)
          : ShopColors.ok.withValues(alpha: 0.07);
      fg = h.alive ? ShopColors.ok : ShopColors.inkSoft;
      border = ShopColors.ok.withValues(alpha: 0.35);
    } else if (h.isUnregistered) {
      bg = ShopColors.warn.withValues(alpha: 0.15);
      fg = ShopColors.warn;
      border = ShopColors.warn.withValues(alpha: 0.4);
    } else if (h.reserved != null) {
      bg = ShopColors.accent.withValues(alpha: 0.11);
      fg = ShopColors.accent;
      border = ShopColors.accent.withValues(alpha: 0.35);
    } else {
      bg = Colors.white;
      fg = ShopColors.inkFaint;
      border = ShopColors.line;
    }
    final lastOctet = h.ip.split('.').last;
    return InkWell(
      onTap: (isNetwork || isBroadcast) ? null : () => _openCell(h),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 34,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: inDhcp ? Color.alphaBlend(Colors.black.withValues(alpha: 0.03), bg) : bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isGateway ? ShopColors.seed : border,
            width: isGateway ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Fa.digits(lastOctet),
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            if (isGateway || (h.reserved != null && !isGateway))
              Text(
                isGateway ? 'GW' : 'R',
                style: TextStyle(
                  fontSize: 6.5,
                  fontWeight: FontWeight.w900,
                  color: isGateway ? ShopColors.seed : ShopColors.accent,
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    final hosts = _visibleHosts;
    if (hosts.isEmpty) {
      return const ShopEmpty(
        title: 'آی‌پی‌ای با این فیلتر پیدا نشد',
        subtitle: 'فیلتر یا عبارت جست‌وجو را تغییر دهید.',
        icon: Icons.search_off_rounded,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        children: [
          for (final h in hosts.take(300)) _listRow(h),
          if (hosts.length > 300)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'نمایش ۳۰۰ آی‌پی اول از ${Fa.digits(hosts.length)} مورد — برای دیدن بقیه فیلتر کنید.',
                style: const TextStyle(
                  fontSize: 9,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _listRow(IpHost h) {
    final problem = h.conflict || (h.macMismatch ?? '').isNotEmpty;
    final color = problem
        ? ShopColors.danger
        : h.isRegistered
        ? ShopColors.ok
        : h.isUnregistered
        ? ShopColors.warn
        : ShopColors.inkFaint;
    final title = h.reserved?.title ??
        h.registryOwners.map((o) => o.title).where((t) => t.isNotEmpty).join(' · ');
    return InkWell(
      onTap: () => _openCell(h),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: ShopColors.line)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                h.ip,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty
                        ? (h.hostname ?? '—')
                        : (h.hostname == null ? title : '$title · ${h.hostname}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ShopColors.ink,
                    ),
                  ),
                  Text(
                    '${h.stateLabel}${(h.mac ?? '').isEmpty ? '' : ' · ${h.mac}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8.8,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            if (problem)
              const ShopTag(text: 'تداخل', color: ShopColors.danger),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  کشوی جزئیات یک آی‌پی
// ============================================================

class IpCellSheet extends StatefulWidget {
  const IpCellSheet({
    super.key,
    required this.repo,
    required this.subnet,
    required this.host,
    this.canUpdate = false,
  });

  final IpamRepository repo;
  final IpSubnetInfo subnet;
  final IpHost host;
  final bool canUpdate;

  @override
  State<IpCellSheet> createState() => _IpCellSheetState();
}

class _IpCellSheetState extends State<IpCellSheet> {
  bool _busy = false;
  bool _changed = false;
  IpProbeResult? _probe;

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  Future<void> _probeNow() async {
    setState(() => _busy = true);
    try {
      final r = await widget.repo.probe(widget.subnet.id, widget.host.ip);
      if (!mounted) return;
      setState(() {
        _probe = r;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_clean(e), style: const TextStyle(fontSize: 11.5)),
          backgroundColor: ShopColors.danger,
        ),
      );
    }
  }

  Future<void> _openReserve() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IpReserveSheet(
        repo: widget.repo,
        subnetId: widget.subnet.id,
        ip: widget.host.ip,
        host: widget.host,
      ),
    );
    if (ok == true && mounted) {
      setState(() => _changed = true);
      Navigator.pop(context, true);
    }
  }

  Future<void> _unreserve() async {
    setState(() => _busy = true);
    try {
      await widget.repo.unreserve(widget.subnet.id, widget.host.ip);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_clean(e), style: const TextStyle(fontSize: 11.5)),
          backgroundColor: ShopColors.danger,
        ),
      );
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$text کپی شد.', style: const TextStyle(fontSize: 11.5)),
        backgroundColor: ShopColors.ok,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.host;
    final r = h.reserved;
    final problem = h.conflict || (h.macMismatch ?? '').isNotEmpty;
    final color = problem
        ? ShopColors.danger
        : h.isRegistered
        ? ShopColors.ok
        : h.isUnregistered
        ? ShopColors.warn
        : ShopColors.inkFaint;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                Icon(Icons.lan_rounded, size: 17, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    h.ip,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copy(h.ip),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'کپی آی‌پی',
                  icon: const Icon(Icons.copy_rounded, size: 16),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, _changed),
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
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
                          ShopTag(text: h.stateLabel, color: color),
                          const SizedBox(width: 5),
                          if (h.alive)
                            const ShopTag(
                              text: 'روشن',
                              color: ShopColors.ok,
                              icon: Icons.bolt_rounded,
                            ),
                          if (h.method != null && h.alive) ...[
                            const SizedBox(width: 5),
                            ShopTag(
                              text: h.methodFa,
                              color: ShopColors.inkFaint,
                            ),
                          ],
                          if (problem) ...[
                            const SizedBox(width: 5),
                            const ShopTag(
                              text: 'تداخل',
                              color: ShopColors.danger,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if ((h.hostname ?? '').isNotEmpty)
                        InfoRow(label: 'نام دستگاه', value: h.hostname!),
                      InfoRow(
                        label: 'MAC',
                        value: (h.mac ?? '').isEmpty ? '—' : h.mac!,
                        ltr: true,
                      ),
                      if ((h.macHint ?? '').isNotEmpty)
                        InfoRow(label: 'MAC انتظاری', value: h.macHint!, ltr: true),
                      if ((h.macMismatch ?? '').isNotEmpty)
                        InfoRow(
                          label: 'ناسازگاری MAC',
                          value: h.macMismatch!,
                          valueColor: ShopColors.danger,
                        ),
                      InfoRow(
                        label: 'آخرین مشاهده',
                        value: Fa.date(h.lastSeenAt?.toIso8601String()),
                      ),
                      InfoRow(
                        label: 'اولین مشاهده',
                        value: Fa.date(h.firstSeenAt?.toIso8601String()),
                      ),
                      InfoRow(
                        label: 'آخرین بررسی',
                        value: agoFa(h.lastCheckedAt),
                      ),
                      if (_probe != null) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            Icon(
                              _probe!.alive
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              size: 14,
                              color: _probe!.alive
                                  ? ShopColors.ok
                                  : ShopColors.inkFaint,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _probe!.alive
                                    ? 'همین حالا پاسخ داد (${_probe!.methodFa})'
                                    : 'همین حالا پاسخی نداد',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _probe!.alive
                                      ? ShopColors.ok
                                      : ShopColors.inkFaint,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((_probe!.mac ?? '').isNotEmpty)
                          InfoRow(label: 'MAC فعلی', value: _probe!.mac!, ltr: true),
                        if ((_probe!.hostname ?? '').isNotEmpty)
                          InfoRow(label: 'نام فعلی', value: _probe!.hostname!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // شناسنامه‌ها
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: ShopColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'شناسنامه‌های ثبت‌شده روی این آی‌پی',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (h.registryOwners.isEmpty)
                        const Text(
                          'هیچ شناسنامه‌ای این آی‌پی را ثبت نکرده است.',
                          style: TextStyle(
                            fontSize: 10,
                            color: ShopColors.inkFaint,
                          ),
                        )
                      else
                        for (final o in h.registryOwners)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(9),
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
                                    ShopTag(
                                      text: o.sourceTitle.isEmpty
                                          ? ipSourceFa(o.source)
                                          : o.sourceTitle,
                                      color: ShopColors.seed,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        o.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if ((o.detail ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      o.detail!,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: ShopColors.inkSoft,
                                      ),
                                    ),
                                  ),
                                if ((o.mac ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      'MAC: ${o.mac}',
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 9,
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
                const SizedBox(height: 10),
                // رزرو
                Container(
                  padding: const EdgeInsets.all(11),
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
                          const Icon(
                            Icons.bookmark_rounded,
                            size: 14,
                            color: ShopColors.accent,
                          ),
                          const SizedBox(width: 5),
                          const Expanded(
                            child: Text(
                              'رزرو دستی',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (r != null)
                            const ShopTag(
                              text: 'رزرو شده',
                              color: ShopColors.accent,
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (r == null)
                        const Text(
                          'برای این آی‌پی رزرو دستی ثبت نشده است.',
                          style: TextStyle(
                            fontSize: 10,
                            color: ShopColors.inkFaint,
                          ),
                        )
                      else ...[
                        InfoRow(label: 'عنوان', value: r.title ?? '—'),
                        InfoRow(label: 'نوع', value: r.typeFa.isEmpty ? '—' : r.typeFa),
                        InfoRow(label: 'صاحب', value: r.owner ?? '—'),
                        if ((r.note ?? '').isNotEmpty)
                          InfoRow(label: 'یادداشت', value: r.note!),
                        InfoRow(
                          label: 'ثبت در',
                          value: Fa.date(r.updatedAt?.toIso8601String()),
                        ),
                        if ((r.updatedByName ?? '').isNotEmpty)
                          InfoRow(label: 'ثبت‌کننده', value: r.updatedByName!),
                      ],
                      const SizedBox(height: 8),
                      if (widget.canUpdate)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  foregroundColor: ShopColors.accent,
                                  side: BorderSide(
                                    color: ShopColors.accent.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: _busy ? null : _openReserve,
                                icon: const Icon(
                                  Icons.bookmark_add_rounded,
                                  size: 15,
                                ),
                                label: Text(
                                  r == null ? 'رزرو' : 'ویرایش رزرو',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            if (r != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                    foregroundColor: ShopColors.danger,
                                    side: BorderSide(
                                      color: ShopColors.danger.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  onPressed: _busy ? null : _unreserve,
                                  icon: const Icon(
                                    Icons.bookmark_remove_rounded,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'آزاد کردن',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ShopColors.teal,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _busy ? null : _probeNow,
                  icon: _busy
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.wifi_tethering_rounded, size: 16),
                  label: const Text(
                    'بررسی همین الان',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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
}

// ============================================================
//  فرم رزرو آی‌پی
// ============================================================

class IpReserveSheet extends StatefulWidget {
  const IpReserveSheet({
    super.key,
    required this.repo,
    required this.subnetId,
    required this.ip,
    this.host,
  });
  final IpamRepository repo;
  final int subnetId;
  final String ip;
  final IpHost? host;

  @override
  State<IpReserveSheet> createState() => _IpReserveSheetState();
}

class _IpReserveSheetState extends State<IpReserveSheet> {
  final _title = TextEditingController();
  final _owner = TextEditingController();
  final _note = TextEditingController();
  String _type = 'Server';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.host?.reserved;
    if (r != null) {
      _title.text = r.title ?? '';
      _owner.text = r.owner ?? '';
      _note.text = r.note ?? '';
      _type = (r.type ?? '').isEmpty ? 'Other' : r.type!;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _owner.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'عنوان رزرو را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.reserve(
        widget.subnetId,
        IpReserveRequest(
          ip: widget.ip,
          title: _title.text.trim(),
          type: _type,
          owner: _owner.text.trim().isEmpty ? null : _owner.text.trim(),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '')
            .trim();
      });
    }
  }

  InputDecoration get _dec => InputDecoration(
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
                Icons.bookmark_add_rounded,
                size: 17,
                color: ShopColors.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'رزرو ${widget.ip}',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
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
          if (_error != null) ...[
            const SizedBox(height: 6),
            SystemNote(
              text: _error!,
              color: ShopColors.danger,
              icon: Icons.error_outline_rounded,
            ),
          ],
          const SizedBox(height: 8),
          ShopField(
            label: 'عنوان',
            required: true,
            hint: 'مثال: دوربین ورودی انبار',
            child: TextField(
              controller: _title,
              style: const TextStyle(fontSize: 11.5),
              decoration: _dec,
            ),
          ),
          ShopField(
            label: 'نوع',
            child: DropdownButtonFormField<String>(
              initialValue: _type,
              isDense: true,
              style: const TextStyle(fontSize: 11.5, color: ShopColors.ink),
              decoration: _dec,
              items: [
                for (final t in kReservedTypes)
                  DropdownMenuItem(
                    value: t.key,
                    child: Text(
                      t.value,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'Other'),
            ),
          ),
          ShopField(
            label: 'صاحب / مسئول',
            child: TextField(
              controller: _owner,
              style: const TextStyle(fontSize: 11.5),
              decoration: _dec.copyWith(
                hintText: 'نام شخص یا واحد',
                hintStyle: const TextStyle(
                  fontSize: 10.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
          ),
          ShopField(
            label: 'یادداشت',
            child: TextField(
              controller: _note,
              maxLines: 2,
              style: const TextStyle(fontSize: 11.5),
              decoration: _dec,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ShopColors.accent,
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
                      : const Text(
                          'ذخیره رزرو',
                          style: TextStyle(
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
//  مودال رنج (ثبت / ویرایش)
// ============================================================

class SubnetFormSheet extends StatefulWidget {
  const SubnetFormSheet({
    super.key,
    required this.repo,
    required this.companyId,
    this.subnet,
    this.current,
  });
  final IpamRepository repo;
  final int companyId;
  final IpSubnetRow? subnet;
  final IpSubnetInfo? current;

  @override
  State<SubnetFormSheet> createState() => _SubnetFormSheetState();
}

class _SubnetFormSheetState extends State<SubnetFormSheet> {
  final _name = TextEditingController();
  final _cidr = TextEditingController();
  final _gateway = TextEditingController();
  final _vlan = TextEditingController();
  final _dns = TextEditingController();
  final _dhcp = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  int _autoScan = 0;
  bool _busy = false;
  String? _error;

  bool get _isEdit => (widget.subnet?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final s = widget.subnet;
    final info = widget.current;
    if (s != null) {
      _name.text = s.name;
      _cidr.text = s.cidr;
      _gateway.text = s.gateway ?? '';
      _vlan.text = (s.vlan ?? 0) > 0 ? '${s.vlan}' : '';
      _dns.text = info?.dnsServers ?? '';
      _dhcp.text = s.dhcpRange ?? '';
      _location.text = s.location ?? '';
      _description.text = info?.description ?? '';
      _autoScan = s.autoScanMinutes;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _cidr,
      _gateway,
      _vlan,
      _dns,
      _dhcp,
      _location,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  IpSubnetSaveRequest _build() => IpSubnetSaveRequest(
    companyId: widget.companyId,
    name: _name.text.trim(),
    cidr: _cidr.text.trim(),
    gateway: _gateway.text.trim().isEmpty ? null : _gateway.text.trim(),
    vlan: int.tryParse(_vlan.text.trim()),
    dnsServers: _dns.text.trim().isEmpty ? null : _dns.text.trim(),
    dhcpRange: _dhcp.text.trim().isEmpty ? null : _dhcp.text.trim(),
    location: _location.text.trim().isEmpty ? null : _location.text.trim(),
    description: _description.text.trim().isEmpty
        ? null
        : _description.text.trim(),
    autoScanMinutes: _autoScan,
  );

  Future<void> _save() async {
    final d = _build();
    final err = validateSubnetForm(d);
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
        await widget.repo.updateSubnet(widget.subnet!.id, d);
      } else {
        await widget.repo.createSubnet(d);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '')
            .trim();
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
                  Icons.lan_rounded,
                  size: 17,
                  color: ShopColors.teal,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isEdit ? 'ویرایش رنج' : 'رنج جدید',
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
                ShopField(
                  label: 'نام رنج',
                  required: true,
                  child: TextField(
                    controller: _name,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('مثال: شبکهٔ اداری طبقهٔ ۲'),
                  ),
                ),
                ShopField(
                  label: 'CIDR',
                  required: true,
                  hint: cidrHint(_cidr.text),
                  child: TextField(
                    controller: _cidr,
                    textDirection: TextDirection.ltr,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('192.168.30.0/24'),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ShopField(
                        label: 'گیت‌وی',
                        child: TextField(
                          controller: _gateway,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 11.5),
                          decoration: _dec('192.168.30.1'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShopField(
                        label: 'VLAN',
                        hint: '۱ تا ۴۰۹۴',
                        child: TextField(
                          controller: _vlan,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 11.5),
                          decoration: _dec('30'),
                        ),
                      ),
                    ),
                  ],
                ),
                ShopField(
                  label: 'اسکن خودکار',
                  child: DropdownButtonFormField<int>(
                    initialValue: kAutoScanOptions.any((o) => o.key == _autoScan)
                        ? _autoScan
                        : 0,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.ink,
                    ),
                    decoration: _dec(),
                    items: [
                      for (final o in kAutoScanOptions)
                        DropdownMenuItem(
                          value: o.key,
                          child: Text(
                            o.value,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _autoScan = v ?? 0),
                  ),
                ),
                ShopField(
                  label: 'سرورهای DNS',
                  child: TextField(
                    controller: _dns,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('8.8.8.8, 1.1.1.1'),
                  ),
                ),
                ShopField(
                  label: 'بازهٔ DHCP',
                  hint: 'مثال: 192.168.30.100-192.168.30.200',
                  child: TextField(
                    controller: _dhcp,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('192.168.30.100-200'),
                  ),
                ),
                ShopField(
                  label: 'محل',
                  child: TextField(
                    controller: _location,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('ساختمان مرکزی — طبقهٔ ۲'),
                  ),
                ),
                ShopField(
                  label: 'توضیحات',
                  child: TextField(
                    controller: _description,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec(),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ShopColors.teal,
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
                                _isEdit ? 'ذخیره تغییرات' : 'ثبت رنج',
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
                const SizedBox(height: 10),
                const SystemNote(
                  text:
                      'اسکن از روی سرور برنامه انجام می‌شود و به شبکهٔ قابل دسترس همان سرور محدود است. بزرگ‌ترین رنج مجاز /۲۲ (۱۰۲۲ میزبان) است و طول پیشوند باید بین /۲۲ تا /۳۰ باشد.',
                  color: ShopColors.warn,
                  icon: Icons.radar_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
