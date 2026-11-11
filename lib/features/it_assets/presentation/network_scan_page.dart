// ============================================================
//  «اسکن شبکه» — فاز ۹-ز
//  آینهٔ `Pages/ItAssets/NetworkScan.razor` (مسیر وب: /network-scan)
//
//  • سرصفحهٔ «اسکن شبکه» / «سیستم‌های شبکه و دوربین‌های مداربسته — با پیشرفت زنده»
//  • کارت ۱ (آبی/بنفش): «لیست سیستم‌های داخل شبکه»
//      – انتخاب رنج: «خودکار — شبکه‌ی خودم» / «دستی — خودم می‌نویسم»
//        + فیلد رنج دستی با همان مثال و راهنما
//      – دکمهٔ «شروع اسکن» / «در حال اسکن…»
//      – نوار پیشرفت با درصد + «N از M آدرس بررسی شد — K سیستم پیدا شد»
//        و «(کل اسکن: X ثانیه)» و خطا
//      – پیام «چیزی پیدا نشد — …»
//      – ردیف هر میزبان: آی‌پی، تشخیص (TCP/پینگ)، نام کامپیوتر، مک،
//        «ثبت‌شده (#id)» با پرش به شناسنامهٔ سیستم
//  • کارت ۲ (سرخ): «دوربین‌ها و دستگاه‌های NVR/DVR»
//      – «اسکن دوربین و NVR» با توضیح چندلایه و پیام انتظار ۱۰–۳۰ ثانیه
//      – «N دستگاه CCTV پیدا شد» + ردیف هر دستگاه: آی‌پی، نوع، برند،
//        پورت‌های باز، RTSP، ONVIF، MAC (برند)، دقت تشخیص
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/network_scan_repository.dart';
import '../models/network_scan_models.dart';
import 'system_detail_page.dart';
import 'system_style.dart';

class NetworkScanPage extends StatefulWidget {
  const NetworkScanPage({super.key});

  @override
  State<NetworkScanPage> createState() => _NetworkScanPageState();
}

class _NetworkScanPageState extends State<NetworkScanPage> {
  late final NetworkScanRepository _repo;

  ScanRangeMode _rangeMode = ScanRangeMode.auto;
  final _manualRange = TextEditingController();

  bool _scanStarting = false;
  ScanStatus? _scanStatus;
  String? _error;

  CctvScanResult? _cctv;
  bool _cctvBusy = false;

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _repo = NetworkScanRepository(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _manualRange.dispose();
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  bool get _running => _scanStarting || (_scanStatus?.running ?? false);

  void _onRangeModeChanged(ScanRangeMode m) {
    setState(() {
      _rangeMode = m;
      _scanStatus = null;
      _error = null;
    });
  }

  // ---------------- اسکن سیستم‌ها ----------------

  Future<void> _startScan() async {
    setState(() {
      _scanStarting = true;
      _error = null;
    });
    try {
      final range = _rangeMode == ScanRangeMode.auto
          ? 'auto'
          : _manualRange.text.trim();
      if (_rangeMode == ScanRangeMode.manual && range.isEmpty) {
        setState(() {
          _error = 'رنج آی‌پی را وارد کنید (مثلاً 192.168.1)';
          _scanStarting = false;
        });
        return;
      }

      final started = await _repo.start(range);
      if (!mounted) return;
      setState(() => _scanStarting = false);

      // پایش زندهٔ وضعیت — هر ثانیه، مثل وب
      _poll?.cancel();
      Future<void> tick() async {
        try {
          final st = await _repo.status(started.jobId);
          if (!mounted) return;
          setState(() => _scanStatus = st);
          if (st.running) {
            _poll = Timer(const Duration(seconds: 1), tick);
          }
        } catch (_) {
          if (mounted) setState(() => _poll = null);
        }
      }

      await tick();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanStarting = false;
        _error = 'سرور: ${_clean(e)}';
      });
    }
  }

  // ---------------- اسکن دوربین ----------------

  Future<void> _scanCctv() async {
    setState(() => _cctvBusy = true);
    try {
      final res = await _repo.scanCctv();
      if (!mounted) return;
      setState(() => _cctv = res);
    } catch (_) {
      if (!mounted) return;
      setState(() => _cctv = const CctvScanResult());
    } finally {
      if (mounted) setState(() => _cctvBusy = false);
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
          'اسکن شبکه',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
        children: [
          const ShopHeader(
            title: 'اسکن شبکه',
            subtitle: 'سیستم‌های شبکه و دوربین‌های مداربسته — با پیشرفت زنده',
            icon: Icons.radar_rounded,
            badge: 'LAN',
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            SystemNote(
              text: _error!,
              color: ShopColors.danger,
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 10),
          ],
          _systemsCard(),
          const SizedBox(height: 10),
          _cctvCard(),
          const SizedBox(height: 10),
          const SystemNote(
            text:
                'اسکن از روی سرور برنامه انجام می‌شود، نه از گوشی؛ نتیجه به شبکهٔ قابل دسترس همان سرور بستگی دارد. اگر چیزی پیدا نشد، کارت شبکهٔ سرور و تنظیمات شبکه (Client Isolation و پروفایل Private) را بررسی کنید.',
            color: ShopColors.seed,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _systemsCard() {
    final st = _scanStatus;
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
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff4f8cff), Color(0xff8e5cff)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.desktop_windows_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'لیست سیستم‌های داخل شبکه',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShopField(
                  label: 'رنج آی‌پی',
                  child: DropdownButtonFormField<ScanRangeMode>(
                    initialValue: _rangeMode,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.ink,
                    ),
                    decoration: _dec(),
                    items: [
                      for (final m in kScanRangeModes)
                        DropdownMenuItem(
                          value: m.key,
                          child: Text(
                            m.value,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        _onRangeModeChanged(v ?? ScanRangeMode.auto),
                  ),
                ),
                if (_rangeMode == ScanRangeMode.manual)
                  ShopField(
                    label: 'رنج دلخواه',
                    hint: kScanRangeHint,
                    child: TextField(
                      controller: _manualRange,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: _dec(kScanRangePlaceholder),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      st != null && st.localIp.isNotEmpty
                          ? 'رنج به‌صورت خودکار از کارت شبکه‌ی سرور تشخیص داده می‌شود — سرور: ${st.localIp} (${st.range})'
                          : 'رنج به‌صورت خودکار از کارت شبکه‌ی سرور تشخیص داده می‌شود',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.8,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff5a74e0),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: _running ? null : _startScan,
                    icon: _running
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 17),
                    label: Text(
                      _running ? 'در حال اسکن…' : 'شروع اسکن',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (st != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (st.progress.clamp(0, 100)) / 100,
                      minHeight: 20,
                      backgroundColor: const Color(0xffe8edf6),
                      color: const Color(0xff6d7ce0),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${Fa.digits(st.progress)}٪',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff5a74e0),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${Fa.digits(st.scanned)} از ${Fa.digits(st.targetCount)} آدرس بررسی شد — ',
                        ),
                        TextSpan(
                          text: '${Fa.digits(st.foundCount)} سیستم پیدا شد',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (st.finished && st.elapsedMs > 0)
                          TextSpan(text: ' (کل اسکن: ${st.elapsedFa} ثانیه)'),
                        if ((st.error ?? '').isNotEmpty)
                          TextSpan(
                            text: ' — خطا: ${st.error}',
                            style: const TextStyle(color: ShopColors.danger),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.9,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                  if (st.isEmptyAndDone) ...[
                    const SizedBox(height: 8),
                    const SystemNote(
                      text:
                          'چیزی پیدا نشد — بررسی کنید: API روی سیستمی که به شبکه وصل است اجرا شود؛ «Client Isolation» روتر خاموش باشد؛ شبکه در ویندوز Private باشد. می‌توانید رنج را دستی وارد کنید و دوباره امتحان کنید.',
                      color: ShopColors.seed,
                      icon: Icons.search_off_rounded,
                    ),
                  ],
                  if (st.hosts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _hostsHeader(st.hosts.length),
                    for (final h in st.hosts) _hostRow(h),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hostsHeader(int count) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        const Icon(
          Icons.list_alt_rounded,
          size: 14,
          color: ShopColors.inkSoft,
        ),
        const SizedBox(width: 5),
        const Expanded(
          child: Text(
            'سیستم‌های پیدا‌شده',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
          ),
        ),
        ShopTag(text: Fa.digits(count), color: ShopColors.seed),
      ],
    ),
  );

  Widget _hostRow(ScanHost h) => Container(
    margin: const EdgeInsets.only(bottom: 6),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: ShopColors.ink,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                h.ip,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            ShopTag(
              text: h.methodLabel,
              color: h.isTcp ? ShopColors.warn : ShopColors.inkFaint,
            ),
            const Spacer(),
            if (h.isRegistered)
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: ShopColors.ok,
                  backgroundColor: ShopColors.ok.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SystemDetailPage(systemId: h.systemInfoId!),
                  ),
                ),
                icon: const Icon(Icons.fact_check_rounded, size: 13),
                label: Text(
                  h.registeredLabel,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              const Text(
                '—',
                style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
              ),
          ],
        ),
        const SizedBox(height: 4),
        InfoRow(label: 'نام کامپیوتر', value: h.hostnameCell, ltr: true),
        InfoRow(label: 'مک آدرس', value: h.macCell, ltr: true),
      ],
    ),
  );

  Widget _cctvCard() {
    final cctv = _cctv;
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
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xffe0245e), Color(0xffff5f6d)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'دوربین‌ها و دستگاه‌های NVR/DVR',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (cctv != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    cctv.summaryFa,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white70,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xffc81e51),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                    onPressed: _cctvBusy ? null : _scanCctv,
                    icon: _cctvBusy
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Color(0xffc81e51),
                            ),
                          )
                        : const Icon(Icons.videocam_rounded, size: 16),
                    label: Text(
                      _cctvBusy ? 'در حال اسکن دوربین‌ها…' : 'اسکن دوربین و NVR',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تشخیص چندلایه: ONVIF WS-Discovery + پورت‌های RTSP/Hikvision/Dahua + پروب RTSP و HTTP + برند از MAC',
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.8,
                    color: ShopColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 8),
                if (_cctvBusy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xffe0245e)),
                        SizedBox(height: 10),
                        Text(
                          'اسکن پورت‌های ۵۵۴ / ۸۰۰۰ / ۳۷۷۷۷ … — ممکن است ۱۰ تا ۳۰ ثانیه طول بکشد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (cctv != null && cctv.isEmpty)
                  const SystemNote(
                    text: 'دوربین یا NVR ای در این شبکه پیدا نشد.',
                    color: ShopColors.seed,
                    icon: Icons.videocam_off_rounded,
                  )
                else if (cctv != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: ShopColors.warn.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: ShopColors.warn.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: Fa.digits(cctv.devices.length),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const TextSpan(text: ' دستگاه CCTV پیدا شد'),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: ShopColors.warn,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final d in cctv.devices) _deviceRow(d),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceRow(CctvScanDevice d) {
    final color = switch (d.kind) {
      'camera' => ShopColors.ok,
      'nvr' => ShopColors.seed,
      _ => ShopColors.inkFaint,
    };
    final confColor = switch (d.confidence) {
      'high' => ShopColors.ok,
      'medium' => ShopColors.warn,
      _ => ShopColors.inkFaint,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xfffdf7f9),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: ShopColors.ink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  d.ip,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ShopTag(text: d.kindLabel, color: color),
              const Spacer(),
              ShopTag(text: d.confidenceLabel, color: confColor),
            ],
          ),
          const SizedBox(height: 4),
          InfoRow(label: 'برند', value: d.vendorCell),
          InfoRow(label: 'پورت‌های باز', value: d.portsCell, ltr: true),
          InfoRow(label: 'RTSP', value: d.rtspCell, ltr: true),
          InfoRow(
            label: 'ONVIF',
            value: d.onvif ? 'ONVIF ✅' : '—',
            valueColor: d.onvif ? ShopColors.teal : null,
          ),
          InfoRow(label: 'MAC', value: d.macCell, ltr: true),
        ],
      ),
    );
  }

  InputDecoration _dec([String? hint]) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
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
}
