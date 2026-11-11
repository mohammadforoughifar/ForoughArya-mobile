// ============================================================
//  «دستگاه‌های NVR» — فاز ۹-و
//  آینهٔ `Pages/Cctv/CctvNvrs.razor` (مسیر وب: /cctv-nvrs)
//
//  • سرصفحهٔ گرادیانی «لیست دستگاه‌های NVR / DVR» + شمارنده + «افزودن NVR»
//  • جستجوی «مدل / سریال / آی‌پی...» + نشان «N دستگاه»
//  • کارت هر دستگاه: مدل، سریال، آی‌پی، مک، محل، «N دوربین»، وضعیت،
//    فهرست نام دوربین‌های متصل (۵ مورد اول + «…»)، ویرایش/حذف
//  • مودال فرم: مدل*، سریال*، آی‌پی، مک، محل، توضیحات، فعال
//  • حذف NVR در سرور دوربین‌ها را جدا می‌کند (یتیم نمی‌مانند)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/cctv_repository.dart';
import '../models/cctv_models.dart';
import 'system_style.dart';

class CctvNvrsPage extends StatefulWidget {
  const CctvNvrsPage({super.key});

  @override
  State<CctvNvrsPage> createState() => _CctvNvrsPageState();
}

class _CctvNvrsPageState extends State<CctvNvrsPage> {
  late final CctvRepository _repo;

  List<CctvNvrRow> _items = const [];
  List<CctvCameraRow> _cameras = const [];
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = CctvRepository(context.read<ApiClient>());
    _load();
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

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 11.5)),
        backgroundColor: error ? ShopColors.danger : ShopColors.ok,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.nvrs();
      List<CctvCameraRow> cams = const [];
      try {
        cams = await _repo.cameras();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = items;
        _cameras = cams;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
        _error = _clean(e);
      });
    }
  }

  List<CctvNvrRow> get _filtered {
    final q = _search.text.trim();
    if (q.isEmpty) return _items;
    return _items.where((n) => n.matches(q)).toList();
  }

  /// `CamerasOf()` وب
  List<CctvCameraRow> _camerasOf(int nvrId) =>
      _cameras.where((c) => c.nvrId == nvrId).toList();

  Future<void> _openForm({CctvNvrRow? row}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CctvNvrFormSheet(repo: _repo, row: row),
    );
    if (saved == true) {
      _toast(row == null ? 'دستگاه NVR ثبت شد.' : 'تغییرات ذخیره شد.');
      await _load();
    }
  }

  Future<void> _delete(CctvNvrRow n) async {
    final attached = _camerasOf(n.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حذف دستگاه NVR',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: Text(
          attached > 0
              ? 'دستگاه «${n.model}» حذف شود؟ ${Fa.digits(attached)} دوربین متصل به آن از NVR جدا می‌شوند (حذف نمی‌شوند).'
              : 'دستگاه «${n.model}» حذف شود؟',
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
      await _repo.deleteNvr(n.id);
      _toast('دستگاه حذف شد.');
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
          'دستگاه‌های NVR',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'بازخوانی',
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
        children: [
          _header(),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
              hintText: 'جستجو: مدل / سریال / آی‌پی...',
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
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ShopColors.inkFaint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${Fa.digits(_filtered.length)} دستگاه',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SystemNote(
              text: 'بارگذاری دستگاه‌ها ناموفق بود — $_error',
              color: ShopColors.danger,
              icon: Icons.cloud_off_rounded,
            )
          else if (_filtered.isEmpty)
            const SystemNote(
              text: 'هنوز دستگاهی ثبت نشده است — «افزودن NVR» را بزنید.',
              color: ShopColors.seed,
              icon: Icons.dns_rounded,
            )
          else
            for (final n in _filtered) _nvrCard(n),
          const SizedBox(height: 10),
          const SystemNote(
            text:
                'با حذف یک NVR، دوربین‌های متصل به آن حذف نمی‌شوند و فقط از NVR جدا می‌شوند؛ می‌توانید بعداً به دستگاه دیگری وصلشان کنید.',
            color: ShopColors.seed,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(
        colors: [Color(0xff4f8cff), Color(0xff8e5cff)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.dns_rounded, size: 18, color: Colors.white),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'لیست دستگاه‌های NVR / DVR',
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            Fa.digits(_filtered.length),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xff4f5b8a),
            ),
          ),
        ),
        const SizedBox(width: 6),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xff4f5b8a),
            backgroundColor: Colors.white,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_rounded, size: 14),
          label: const Text(
            'افزودن NVR',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _nvrCard(CctvNvrRow n) {
    final cams = _camerasOf(n.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(13),
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
                  color: const Color(0xff8e5cff).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.dns_rounded,
                  size: 16,
                  color: Color(0xff6d43d6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.model,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.ink,
                      ),
                    ),
                    Text(
                      n.serialNumber,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              ShopTag(
                text: n.isActive ? 'فعال' : 'غیرفعال',
                color: n.isActive ? ShopColors.ok : ShopColors.inkFaint,
              ),
            ],
          ),
          const Divider(height: 14),
          InfoRow(label: 'آی‌پی', value: n.ipCell, ltr: true),
          InfoRow(label: 'مک آدرس', value: n.macCell, ltr: true),
          InfoRow(label: 'محل استقرار', value: n.locationCell),
          InfoRow(
            label: 'دوربین‌ها',
            value: '${Fa.digits(cams.length)} دستگاه',
            valueColor: ShopColors.teal,
          ),
          if (cams.isNotEmpty)
            InfoRow(
              label: 'فهرست',
              value:
                  '${cams.take(5).map((c) => c.model).join('، ')}${cams.length > 5 ? ' …' : ''}',
            ),
          if ((n.notes ?? '').isNotEmpty)
            InfoRow(label: 'توضیحات', value: n.notes!),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _btn(
                'ویرایش',
                Icons.edit_rounded,
                ShopColors.seed,
                () => _openForm(row: n),
              ),
              _btn(
                'حذف',
                Icons.delete_rounded,
                ShopColors.danger,
                () => _delete(n),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(
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
}

// ============================================================
//  مودال فرم NVR
// ============================================================

class CctvNvrFormSheet extends StatefulWidget {
  const CctvNvrFormSheet({super.key, required this.repo, this.row});
  final CctvRepository repo;
  final CctvNvrRow? row;

  @override
  State<CctvNvrFormSheet> createState() => _CctvNvrFormSheetState();
}

class _CctvNvrFormSheetState extends State<CctvNvrFormSheet> {
  final _model = TextEditingController();
  final _serial = TextEditingController();
  final _ip = TextEditingController();
  final _mac = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  bool _isActive = true;
  bool _busy = false;
  String? _error;

  bool get _isEdit => (widget.row?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    if (r != null) {
      _model.text = r.model;
      _serial.text = r.serialNumber;
      _ip.text = r.ip ?? '';
      _mac.text = r.mac ?? '';
      _location.text = r.location ?? '';
      _notes.text = r.notes ?? '';
      _isActive = r.isActive;
    }
  }

  @override
  void dispose() {
    for (final c in [_model, _serial, _ip, _mac, _location, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  CctvNvrForm _build() => CctvNvrForm(
    id: widget.row?.id ?? 0,
    model: _model.text.trim(),
    serialNumber: _serial.text.trim(),
    ip: _ip.text.trim().isEmpty ? null : _ip.text.trim(),
    mac: _mac.text.trim().isEmpty ? null : _mac.text.trim(),
    location: _location.text.trim().isEmpty ? null : _location.text.trim(),
    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    isActive: _isActive,
  );

  Future<void> _save() async {
    final f = _build();
    final err = validateNvrForm(f);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.saveNvr(f);
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
      height: MediaQuery.of(context).size.height * 0.82,
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
                  Icons.dns_rounded,
                  size: 17,
                  color: Color(0xff6d43d6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isEdit ? 'ویرایش NVR' : 'افزودن دستگاه NVR/DVR',
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
                  label: 'مدل',
                  required: true,
                  child: TextField(
                    controller: _model,
                    maxLength: 150,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('مثلاً: Hikvision DS-7716NI-M4'),
                  ),
                ),
                ShopField(
                  label: 'شماره سریال',
                  required: true,
                  child: TextField(
                    controller: _serial,
                    maxLength: 150,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec(),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ShopField(
                        label: 'آی‌پی',
                        child: TextField(
                          controller: _ip,
                          maxLength: 50,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 11.5),
                          decoration: _dec('192.168.1.10'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShopField(
                        label: 'مک آدرس',
                        child: TextField(
                          controller: _mac,
                          maxLength: 50,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 11.5),
                          decoration: _dec(),
                        ),
                      ),
                    ),
                  ],
                ),
                ShopField(
                  label: 'محل استقرار',
                  child: TextField(
                    controller: _location,
                    maxLength: 250,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('مثلاً: اتاق سرور'),
                  ),
                ),
                ShopField(
                  label: 'توضیحات',
                  child: TextField(
                    controller: _notes,
                    maxLines: 2,
                    maxLength: 500,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec(),
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
                      'فعال باشد',
                      style: TextStyle(fontSize: 11, color: ShopColors.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
