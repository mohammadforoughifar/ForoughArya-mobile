// ============================================================
//  «مدیریت سرورها» — فاز ۹-د
//  آینهٔ `Pages/ItAssets/ServerManagement.razor` (مسیر وب: /servers)
//
//  • سرصفحه: «مدیریت سرورها» / «شناسنامه، سلامت سخت‌افزار و دریافت Inventory
//    امن از HPE iLO / Redfish» + انتخاب شرکت (اگر چند شرکت) + «ثبت سرور»
//  • ۵ شاخص: کل سرورها · وضعیت سالم · نیازمند بررسی · بدون بررسی · هشدار باز
//  • فهرست سرورها با جستجوی «نام، مدل، سریال یا iLO…» و کارت هر سرور:
//    نام / سازنده · اهمیت · چرخهٔ عمر / پایش هر N دقیقه یا «پایش خودکار خاموش» /
//    تعداد هشدار / مسئول و اعلان / تعمیرات تا … / مدل و سریال / iLO / رک و نقش /
//    سلامت / آخرین بررسی و دکمه‌های جزئیات، گواهی، بررسی Redfish، ویرایش، حذف
//  • «هشدارهای باز سرورها» با دستور کار / تأیید / رفع
//  • فرم ثبت و ویرایش با همان ۲۰ فیلد و همان متن‌های اعتبارسنجی
//  • شیت گواهی iLO (اثر انگشت، تأیید/حذف تأیید) و شیت جزئیات سخت‌افزار
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/it_perms.dart';
import '../data/server_repository.dart';
import '../models/server_models.dart';
import 'ipam_page.dart';
import 'server_detail_parts.dart';
import 'system_style.dart';

class ServerManagementPage extends StatefulWidget {
  const ServerManagementPage({super.key});

  @override
  State<ServerManagementPage> createState() => _ServerManagementPageState();
}

class _ServerManagementPageState extends State<ServerManagementPage> {
  late final ServerRepository _repo;
  late final ItPerms _perms;

  List<ServerCompanyRow> _companies = const [];
  List<ServerRow> _rows = const [];
  List<ServerAlertRow> _alerts = const [];
  List<ServerCredentialRow> _credentials = const [];
  List<ServerResponsibleRow> _responsibles = const [];

  int _companyId = 0;
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();
  int _busyId = 0;

  @override
  void initState() {
    super.initState();
    _repo = ServerRepository(context.read<ApiClient>());
    _perms = ItPerms(context.read<AuthController>().session);
    _loadCompanies();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  bool get _canView => _perms.has('Servers.View');
  bool get _canCreate => _perms.has('Servers.Create');
  bool get _canUpdate => _perms.has('Servers.Update');
  bool get _canDelete => _perms.has('Servers.Delete');
  bool get _canCollect => _perms.has('Servers.Collect');
  bool get _canCreateWorkOrders => _perms.has('WorkOrders.Create');
  bool get _canUseCredentials =>
      _perms.has('ItVault.View') && (_canCreate || _canUpdate);

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
      });
      if (_companyId > 0) await _loadAll();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(e);
      });
    }
  }

  Future<void> _loadAll() async {
    if (_companyId <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repo.servers(companyId: _companyId, q: _search.text);
      final alerts = await _repo.alerts(companyId: _companyId);
      List<ServerCredentialRow> creds = const [];
      List<ServerResponsibleRow> resp = const [];
      if (_canUseCredentials) {
        try {
          creds = await _repo.credentials(_companyId);
        } catch (_) {}
      }
      if (_canCreate || _canUpdate) {
        try {
          resp = await _repo.responsibles(_companyId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _alerts = alerts;
        _credentials = creds;
        _responsibles = resp;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(e);
      });
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

  // ---------------- عملیات ----------------

  Future<void> _openForm({ServerRow? server}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServerFormSheet(
        repo: _repo,
        companyId: _companyId,
        server: server,
        credentials: _credentials,
        responsibles: _responsibles,
        canUseCredentials: _canUseCredentials,
      ),
    );
    if (saved == true) {
      _toast(server == null ? 'سرور ثبت شد.' : 'اطلاعات سرور ذخیره شد.');
      await _loadAll();
    }
  }

  Future<void> _test(ServerRow s) async {
    setState(() => _busyId = s.id);
    try {
      await _repo.testConnection(s.id);
      _toast('اتصال امن Redfish به «${s.name}» برقرار است.');
      await _loadAll();
    } catch (e) {
      await _onConnectionError(s, _clean(e), () => _test(s));
    } finally {
      if (mounted) setState(() => _busyId = 0);
    }
  }

  Future<void> _collect(ServerRow s) async {
    setState(() => _busyId = s.id);
    try {
      await _repo.collect(s.id);
      _toast('Inventory و سلامت «${s.name}» دریافت شد.');
      await _loadAll();
    } catch (e) {
      await _onConnectionError(s, _clean(e), () => _collect(s));
    } finally {
      if (mounted) setState(() => _busyId = 0);
    }
  }

  /// اگر خطا مربوط به گواهی تأییدنشده بود، شیت گواهی باز می‌شود — مثل وب
  Future<void> _onConnectionError(
    ServerRow s,
    String message,
    Future<void> Function() retry,
  ) async {
    IloCertificateCheck? check;
    try {
      check = await _repo.certificate(s.id);
    } catch (_) {}
    if (check?.certificate != null &&
        !check!.certificate!.systemTrusted &&
        !check.matchesPin) {
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => IloCertificateSheet(
          repo: _repo,
          server: s,
          initial: check,
          onTrusted: () async {
            await retry();
          },
        ),
      );
      return;
    }
    _toast(message, error: true);
  }

  Future<void> _openCertificate(ServerRow s) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IloCertificateSheet(repo: _repo, server: s),
    );
    await _loadAll();
  }

  Future<void> _openHardware(ServerRow s) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServerHardwareSheet(repo: _repo, server: s),
    );
  }

  Future<void> _delete(ServerRow s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حذف سرور',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'شناسنامهٔ سرور «${s.name}» و تمام تاریخچهٔ سلامت، هشدارها و لاگ‌های آن حذف شود؟',
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
      await _repo.delete(s.id);
      _toast('سرور حذف شد.');
      await _loadAll();
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  Future<void> _acknowledge(ServerAlertRow a) async {
    try {
      await _repo.acknowledgeAlert(a.id);
      _toast('هشدار تأیید شد.');
      await _loadAll();
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  Future<void> _resolve(ServerAlertRow a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'رفع هشدار',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'هشدار به‌صورت دستی رفع شود؟',
          style: TextStyle(fontSize: 12, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.ok),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('رفع'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.resolveAlert(a.id);
      _toast('هشدار رفع شد.');
      await _loadAll();
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  Future<void> _createWorkOrder(ServerAlertRow a) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'دستور کار از هشدار',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'برای این هشدار یک دستور کار به مسئول سرور ایجاد شود؟ ایجاد خودکار انجام نمی‌شود.',
          style: TextStyle(fontSize: 12, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ایجاد'),
          ),
        ],
      ),
    );
    if (go != true) return;
    try {
      final r = await _repo.createWorkOrderFromAlert(a.id);
      final existing = r['existing'] == true;
      final number = r['number']?.toString() ?? '';
      _toast(
        existing
            ? 'دستور کار قبلی این هشدار باز شد.'
            : 'دستور کار $number ایجاد شد.',
      );
      await _loadAll();
    } catch (e) {
      _toast(_clean(e), error: true);
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
          'مدیریت سرورها',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadAll,
            tooltip: 'بازخوانی',
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      body: !_canView
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SystemNote(
                text: 'شما مجوز مشاهدهٔ مدیریت سرورها را ندارید.',
                color: ShopColors.warn,
                icon: Icons.lock_outline_rounded,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
              children: [
                const ShopHeader(
                  title: 'مدیریت سرورها',
                  subtitle:
                      'شناسنامه، سلامت سخت‌افزار و دریافت Inventory امن از HPE iLO / Redfish',
                  icon: Icons.dns_rounded,
                  badge: 'IT',
                ),
                const SizedBox(height: 12),
                if (_companies.isEmpty && !_loading)
                  const SystemNote(
                    text:
                        'شرکتی برای شما تعریف نشده است. ابتدا شرکت و دسترسی شرکت را در بخش کاربران تعریف کنید.',
                    color: ShopColors.warn,
                    icon: Icons.domain_disabled_rounded,
                  )
                else ...[
                  if (_companies.length > 1) _companyPicker(),
                  if (_canCreate && _companyId > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ShopColors.seed,
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text(
                          'ثبت سرور',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 50),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    SystemNote(
                      text: 'بارگذاری سرورها ناموفق بود — $_error',
                      color: ShopColors.danger,
                      icon: Icons.cloud_off_rounded,
                    )
                  else ...[
                    _kpis(),
                    const SizedBox(height: 10),
                    _listCard(),
                    if (_alerts.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _alertsCard(),
                    ],
                    const SizedBox(height: 10),
                    const SystemNote(
                      text:
                          'ارتباط iLO فقط با HTTPS انجام می‌شود. رمز عبور از گاوصندوق در سمت سرور خوانده می‌شود و هرگز به مرورگر یا لاگ عملیات ارسال نمی‌شود. پایش خودکار فقط برای سرورهایی اجرا می‌شود که در فرم خود سرور فعال شده باشد؛ هیچ عملیات Power یا Firmware اجرا نمی‌شود.',
                      color: ShopColors.ok,
                      icon: Icons.shield_rounded,
                    ),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _companyPicker() {
    return Padding(
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
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _companyId = v);
            await _loadAll();
          },
        ),
      ),
    );
  }

  Widget _kpis() {
    final healthy = _rows.where((s) => ServerHealth.isHealthy(s.lastHealthStatus)).length;
    final problem = _rows.where((s) => ServerHealth.isProblem(s.lastHealthStatus)).length;
    final never = _rows.where((s) => s.lastHealthCheckAt == null).length;
    final cards = [
      ('کل سرورها', _rows.length, ShopColors.ink),
      ('وضعیت سالم', healthy, ShopColors.ok),
      ('نیازمند بررسی', problem, ShopColors.danger),
      ('بدون بررسی', never, ShopColors.inkFaint),
      ('هشدار باز', _alerts.length, ShopColors.danger),
    ];
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              decoration: BoxDecoration(
                color: ShopColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShopColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cards[i].$1,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 8.8,
                      height: 1.4,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Fa.digits(cards[i].$2),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: cards[i].$3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _listCard() {
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
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: const BoxDecoration(
              color: Color(0xfff7f9fd),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: ShopColors.line)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.dns_rounded,
                  size: 14,
                  color: ShopColors.inkSoft,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'فهرست سرورها',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: ShopColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadAll,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  tooltip: 'بازخوانی',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _loadAll(),
              style: const TextStyle(fontSize: 11.5),
              decoration: InputDecoration(
                hintText: 'نام، مدل، سریال یا iLO…',
                hintStyle: const TextStyle(
                  fontSize: 10.5,
                  color: ShopColors.inkFaint,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 17,
                  color: ShopColors.inkFaint,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 11,
                ),
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
              ),
            ),
          ),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              child: Column(
                children: [
                  Icon(
                    Icons.dns_rounded,
                    size: 40,
                    color: ShopColors.inkFaint.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سروری ثبت نشده است',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'برای شروع، نام سرور، آدرس iLO و Credential ذخیره‌شده در گاوصندوق را وارد کنید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.7,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                  if (_canCreate) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ShopColors.seed,
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text(
                        'ثبت اولین سرور',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            for (final s in _rows) _serverCard(s),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _serverCard(ServerRow s) {
    final healthColor = Color(ServerHealth.colorValue(s.lastHealthStatus));
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xfff9fbfe),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ShopColors.seed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.dns_rounded,
                  size: 17,
                  color: ShopColors.seed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.ink,
                      ),
                    ),
                    Text(
                      '${s.modelCell} · ${s.iloAddress}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 9,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              ShopTag(
                text: ServerHealth.title(s.lastHealthStatus),
                color: healthColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              s.subtitleLine,
              style: const TextStyle(fontSize: 9, color: ShopColors.inkFaint),
            ),
          ),
          Row(
            children: [
              if (s.monitoringEnabled)
                ShopTag(
                  text: 'پایش هر ${Fa.digits(s.monitoringIntervalMinutes)} دقیقه',
                  color: ShopColors.ok,
                  icon: Icons.broadcast_on_personal_rounded,
                )
              else
                const ShopTag(text: 'پایش خودکار خاموش', color: ShopColors.inkFaint),
              if (s.openAlertCount > 0) ...[
                const SizedBox(width: 5),
                ShopTag(
                  text: '${Fa.digits(s.openAlertCount)} هشدار',
                  color: ShopColors.danger,
                ),
              ],
              if (s.credentialId != null) ...[
                const SizedBox(width: 5),
                const ShopTag(
                  text: 'Credential امن متصل است',
                  color: ShopColors.teal,
                  icon: Icons.shield_rounded,
                ),
              ],
              if (s.certPinned) ...[
                const SizedBox(width: 5),
                const ShopTag(
                  text: 'گواهی تأییدشده',
                  color: ShopColors.accent,
                  icon: Icons.verified_rounded,
                ),
              ],
            ],
          ),
          if ((s.responsibleName ?? '').isNotEmpty || s.inMaintenance)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if ((s.responsibleName ?? '').isNotEmpty)
                    Text(
                      '${s.responsibleName} · ${s.alertNotificationsEnabled ? 'اعلان فعال' : 'اعلان خاموش'}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  if (s.inMaintenance)
                    ShopTag(
                      text:
                          'تعمیرات تا ${Fa.date(s.maintenanceUntil?.toIso8601String(), time: false)}',
                      color: ShopColors.warn,
                      icon: Icons.build_rounded,
                    ),
                ],
              ),
            ),
          const Divider(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoRow(
                      label: 'مدل / سریال',
                      value: '${s.modelCell} · ${s.serialCell}',
                    ),
                    InfoRow(label: 'iLO', value: s.iloLabel, ltr: true),
                    InfoRow(
                      label: 'رک / نقش',
                      value: '${s.rackTitle} · ${(s.role ?? '').isEmpty ? '—' : s.role}',
                    ),
                    InfoRow(
                      label: 'آخرین بررسی',
                      value: Fa.date(s.lastHealthCheckAt?.toIso8601String()),
                    ),
                    if ((s.lastPowerState ?? '').isNotEmpty)
                      InfoRow(
                        label: 'وضعیت توان',
                        value: s.lastPowerState!,
                        ltr: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _btn(
                'جزئیات',
                icon: Icons.memory_rounded,
                color: ShopColors.seed,
                onTap: () => _openHardware(s),
              ),
              _btn(
                'گواهی',
                icon: Icons.verified_user_rounded,
                color: ShopColors.accent,
                onTap: () => _openCertificate(s),
              ),
              if (_canCollect && s.credentialId != null) ...[
                _btn(
                  'تست اتصال',
                  icon: Icons.cable_rounded,
                  color: ShopColors.teal,
                  onTap: _busyId == s.id ? null : () => _test(s),
                  busy: _busyId == s.id,
                ),
                _btn(
                  'دریافت Inventory',
                  icon: Icons.sync_rounded,
                  color: ShopColors.ok,
                  onTap: _busyId == s.id ? null : () => _collect(s),
                  busy: _busyId == s.id,
                ),
              ],
              if (_canUpdate)
                _btn(
                  'ویرایش',
                  icon: Icons.edit_rounded,
                  color: ShopColors.inkSoft,
                  onTap: () => _openForm(server: s),
                ),
              if (_canDelete)
                _btn(
                  'حذف',
                  icon: Icons.delete_rounded,
                  color: ShopColors.danger,
                  onTap: () => _delete(s),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(
    String label, {
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool busy = false,
  }) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    onPressed: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
          )
        else
          Icon(icon, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _alertsCard() {
    return Container(
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: BoxDecoration(
              color: ShopColors.danger.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 15,
                  color: ShopColors.danger,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'هشدارهای باز سرورها',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: ShopColors.danger,
                    ),
                  ),
                ),
                ShopTag(
                  text: Fa.digits(_alerts.length),
                  color: ShopColors.danger,
                ),
              ],
            ),
          ),
          for (final a in _alerts) _alertCard(a),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _alertCard(ServerAlertRow a) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xfff9fbfe),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.serverName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              ShopTag(
                text: a.categoryFa,
                color: a.isCritical ? ShopColors.danger : ShopColors.warn,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            a.message,
            style: const TextStyle(
              fontSize: 10,
              height: 1.7,
              color: ShopColors.inkSoft,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                Fa.date(a.lastSeenAt?.toIso8601String()),
                style: const TextStyle(
                  fontSize: 8.8,
                  color: ShopColors.inkFaint,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                a.statusFa,
                style: TextStyle(
                  fontSize: 8.8,
                  fontWeight: FontWeight.w700,
                  color: a.status == 'Resolved'
                      ? ShopColors.ok
                      : a.status == 'Acknowledged'
                      ? ShopColors.warn
                      : ShopColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_canUpdate && _canCreateWorkOrders)
                _btn(
                  'دستور کار',
                  icon: Icons.assignment_rounded,
                  color: ShopColors.seed,
                  onTap: a.status == 'Resolved'
                      ? null
                      : () => _createWorkOrder(a),
                ),
              if (_canUpdate && a.status == 'Open')
                _btn(
                  'تأیید',
                  icon: Icons.check_rounded,
                  color: ShopColors.warn,
                  onTap: () => _acknowledge(a),
                ),
              if (_canUpdate && a.status != 'Resolved')
                _btn(
                  'رفع',
                  icon: Icons.done_all_rounded,
                  color: ShopColors.ok,
                  onTap: () => _resolve(a),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// کارت میان‌بر به «مدیریت آی‌پی» — برای پیمایش سریع از خانهٔ IT
Widget ipamShortcut(BuildContext context) => Container(
  margin: const EdgeInsets.only(bottom: 8),
  decoration: BoxDecoration(
    color: ShopColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: ShopColors.line),
  ),
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const IpamPage()),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.hub_rounded, size: 18, color: ShopColors.teal),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'مدیریت آی‌پی',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: ShopColors.inkFaint,
            ),
          ],
        ),
      ),
    ),
  ),
);
