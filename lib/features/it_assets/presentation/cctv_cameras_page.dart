// ============================================================
//  «دوربین‌های مداربسته» — فاز ۹-و
//  آینهٔ `Pages/Cctv/CctvCameras.razor` (مسیر وب: /cctv-cameras)
//
//  • سرصفحهٔ گرادیانی «لیست دوربین‌های ثبت‌شده» + شمارنده
//    و دکمه‌های «خروجی اکسل» و «افزودن دوربین»
//  • نوار ابزار: «انتخاب فایل اکسل» + «ورود از اکسل» + نام فایل،
//    جستجوی «مدل / سریال / آی‌پی / مک...»، فیلتر محل استقرار
//    («همه‌ی محل‌های استقرار» + «محل (تعداد)»)، گروه‌بندی (محل/NVR/بدون)
//    و نشان «N دوربین»
//  • فهرست گروه‌بندی‌شده: سرگروه + کارت هر دوربین (مدل، سریال، آی‌پی،
//    مک، محل، NVR، وضعیت) + ویرایش/حذف
//  • مودال فرم: مدل*، سریال*، آی‌پی، مک، محل*، NVR متصل، توضیحات، فعال
//  • گزارش نتیجهٔ ورود اکسل: «N دوربین ثبت شد؛ M رد شد (خالی/تکراری).»
// ============================================================

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/cctv_repository.dart';
import '../models/cctv_models.dart';
import 'system_style.dart';

class CctvCamerasPage extends StatefulWidget {
  const CctvCamerasPage({super.key});

  @override
  State<CctvCamerasPage> createState() => _CctvCamerasPageState();
}

class _CctvCamerasPageState extends State<CctvCamerasPage> {
  late final CctvRepository _repo;

  List<CctvCameraRow> _items = const [];
  List<CctvNvrRow> _nvrs = const [];
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();
  String _locationFilter = '';
  CctvGroupMode _groupMode = CctvGroupMode.location;

  // ورود اکسل
  File? _importFile;
  bool _importing = false;
  CctvImportResult? _importResult;
  bool _downloadingTemplate = false;

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
      final items = await _repo.cameras();
      List<CctvNvrRow> nvrs = const [];
      try {
        nvrs = await _repo.nvrs();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = items;
        _nvrs = nvrs;
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

  // ---------------- فیلتر و گروه‌بندی ----------------

  List<CctvCameraRow> get _filtered {
    final q = _search.text.trim();
    return _items
        .where((c) => _locationFilter.isEmpty || c.location == _locationFilter)
        .where((c) => q.isEmpty || c.matches(q))
        .toList();
  }

  List<CctvGroup> get _grouped =>
      groupCameras(_filtered, _groupMode, _nvrs);

  // ---------------- فرم ----------------

  Future<void> _openForm({CctvCameraRow? row}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CctvCameraFormSheet(
        repo: _repo,
        nvrs: _nvrs,
        row: row,
      ),
    );
    if (saved == true) {
      _toast(row == null ? 'دوربین ثبت شد.' : 'تغییرات دوربین ذخیره شد.');
      await _load();
    }
  }

  Future<void> _delete(CctvCameraRow c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حذف دوربین',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'دوربین «${c.model}» با سریال «${c.serialNumber}» حذف شود؟',
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
      await _repo.deleteCamera(c.id);
      _toast('دوربین حذف شد.');
      await _load();
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  // ---------------- اکسل ----------------

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.pickFiles();
      final path = picked.isEmpty ? null : picked.first.path;
      if (path == null) return;
      final low = path.toLowerCase();
      if (!low.endsWith('.xlsx') && !low.endsWith('.xls')) {
        _toast('فقط فایل اکسل (xlsx/xls) پشتیبانی می‌شود.', error: true);
        return;
      }
      setState(() {
        _importFile = File(path);
        _importResult = null;
      });
    } catch (e) {
      _toast('انتخاب فایل انجام نشد: $e', error: true);
    }
  }

  Future<void> _doImport() async {
    if (_importFile == null) return;
    setState(() {
      _importing = true;
      _importResult = null;
    });
    try {
      final bytes = await _importFile!.readAsBytes();
      final res = await _repo.importCameras(
        bytes,
        _importFile!.uri.pathSegments.last,
      );
      if (!mounted) return;
      setState(() => _importResult = res);
      if (!res.hasErrors) {
        _toast('${res.inserted} دوربین از اکسل ثبت شد.');
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _importResult = CctvImportResult(errors: [_clean(e)]));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _downloadTemplate() async {
    setState(() => _downloadingTemplate = true);
    try {
      final bytes = await _repo.cameraTemplate();
      if (bytes.isEmpty) {
        _toast('فایل نمونه خالی برگشت.', error: true);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/CctvCameras-Template.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      final share = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text(
            'قالب اکسل دوربین‌ها',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'فایل نمونه ذخیره شد. آن را با اکسل پر کنید و دوباره «ورود از اکسل» را بزنید.',
            style: TextStyle(fontSize: 12, height: 1.7),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('باز کردن'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('ارسال/اشتراک'),
            ),
          ],
        ),
      );
      if (share == true) {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      } else {
        await OpenFilex.open(file.path);
      }
      if (mounted) _toast('قالب اکسل آماده شد.');
    } catch (e) {
      _toast(_clean(e), error: true);
    } finally {
      if (mounted) setState(() => _downloadingTemplate = false);
    }
  }

  Future<void> _export() async {
    try {
      final bytes = await _repo.cameraExport(q: _search.text.trim());
      if (bytes.isEmpty) {
        _toast('خروجی خالی برگشت.', error: true);
        return;
      }
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/CctvCameras-$stamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      final share = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text(
            'خروجی اکسل دوربین‌ها',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'فایل خروجی ذخیره شد. با اکسل باز کنید یا برای رایانه بفرستید.',
            style: TextStyle(fontSize: 12, height: 1.7),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('باز کردن'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('ارسال/اشتراک'),
            ),
          ],
        ),
      );
      if (share == true) {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      } else {
        await OpenFilex.open(file.path);
      }
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
          'دوربین‌های مداربسته',
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
          _toolbar(),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SystemNote(
              text: 'بارگذاری دوربین‌ها ناموفق بود — $_error',
              color: ShopColors.danger,
              icon: Icons.cloud_off_rounded,
            )
          else if (_filtered.isEmpty)
            const SystemNote(
              text:
                  'هنوز دوربینی ثبت نشده — با دکمه‌ی «افزودن دوربین» یا «ورود از اکسل» شروع کنید.',
              color: ShopColors.seed,
              icon: Icons.videocam_off_rounded,
            )
          else
            for (final g in _grouped) ...[
              if (_groupMode != CctvGroupMode.none) _groupHeader(g),
              for (final c in g.items) _cameraCard(c),
            ],
          if (_importResult != null) ...[
            const SizedBox(height: 10),
            _importResultBox(_importResult!),
          ],
          const SizedBox(height: 10),
          const SystemNote(
            text:
                'ورود گروهی از اکسل: ستون‌های «مدل» و «شماره سریال» الزامی است؛ ستون‌های آی‌پی، مک، محل، توضیحات، فعال و NVR اختیاری‌اند. ردیف‌های تکراری یا خالی نادیده گرفته می‌شوند.',
            color: ShopColors.seed,
            icon: Icons.table_chart_rounded,
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.videocam_rounded,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'لیست دوربین‌های ثبت‌شده',
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
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _headerBtn(
              'خروجی اکسل',
              Icons.file_download_rounded,
              _export,
            ),
            _headerBtn(
              'قالب اکسل',
              Icons.description_rounded,
              _downloadingTemplate ? null : _downloadTemplate,
            ),
            _headerBtn(
              'افزودن دوربین',
              Icons.add_rounded,
              () => _openForm(),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _headerBtn(String label, IconData icon, VoidCallback? onTap) =>
      TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xff4f5b8a),
          backgroundColor: Colors.white,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
      );

  Widget _toolbar() {
    final locations = cctvLocations(_items);
    return Container(
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
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    foregroundColor: ShopColors.seed,
                    side: BorderSide(
                      color: ShopColors.seed.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file_rounded, size: 15),
                  label: Text(
                    _importFile == null
                        ? 'انتخاب فایل اکسل'
                        : _importFile!.uri.pathSegments.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ShopColors.ok,
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: (_importFile == null || _importing) ? null : _doImport,
                icon: _importing
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_rounded, size: 15),
                label: const Text(
                  'ورود از اکسل',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
              hintText: 'جستجو: مدل / سریال / آی‌پی / مک...',
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
              fillColor: const Color(0xfff9fbfe),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xfff9fbfe),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ShopColors.line),
            ),
            child: DropdownButton<String>(
              value: _locationFilter,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style: const TextStyle(fontSize: 11, color: ShopColors.ink),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text(
                    'همه‌ی محل‌های استقرار',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                for (final loc in locations)
                  DropdownMenuItem(
                    value: loc,
                    child: Text(
                      '$loc (${Fa.digits(cctvCamerasAt(_items, loc))})',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _locationFilter = v ?? ''),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xfff9fbfe),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: DropdownButton<CctvGroupMode>(
                    value: _groupMode,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 11, color: ShopColors.ink),
                    items: [
                      for (final m in kCctvGroupModes)
                        DropdownMenuItem(
                          value: m.key,
                          child: Text(
                            m.value,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(
                      () => _groupMode = v ?? CctvGroupMode.location,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ShopColors.inkFaint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${Fa.digits(_filtered.length)} دوربین',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _groupHeader(CctvGroup g) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
    child: Row(
      children: [
        Icon(
          _groupMode == CctvGroupMode.nvr
              ? Icons.dns_rounded
              : Icons.place_rounded,
          size: 14,
          color: const Color(0xff4f5b8a),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            g.key,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xff4f5b8a),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: ShopColors.seed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            Fa.digits(g.items.length),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: ShopColors.seed,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _cameraCard(CctvCameraRow c) => Container(
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
                Icons.videocam_rounded,
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
                    c.model,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: ShopColors.ink,
                    ),
                  ),
                  Text(
                    c.serialNumber,
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
              text: c.isActive ? 'فعال' : 'غیرفعال',
              color: c.isActive ? ShopColors.ok : ShopColors.inkFaint,
            ),
          ],
        ),
        const Divider(height: 14),
        InfoRow(label: 'آی‌پی', value: c.ipCell, ltr: true),
        InfoRow(label: 'مک آدرس', value: c.macCell, ltr: true),
        InfoRow(label: 'محل استقرار', value: c.locationCell),
        InfoRow(label: 'NVR', value: cctvNvrName(_nvrs, c.nvrId)),
        if ((c.notes ?? '').isNotEmpty)
          InfoRow(label: 'توضیحات', value: c.notes!),
        if (_groupMode == CctvGroupMode.none)
          InfoRow(
            label: 'تاریخ ثبت',
            value: Fa.date(c.createdAt?.toIso8601String()),
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _btn(
              'ویرایش',
              Icons.edit_rounded,
              ShopColors.seed,
              () => _openForm(row: c),
            ),
            _btn(
              'حذف',
              Icons.delete_rounded,
              ShopColors.danger,
              () => _delete(c),
            ),
          ],
        ),
      ],
    ),
  );

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

  Widget _importResultBox(CctvImportResult r) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: (r.hasErrors ? ShopColors.warn : ShopColors.ok).withValues(
        alpha: 0.08,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: (r.hasErrors ? ShopColors.warn : ShopColors.ok).withValues(
          alpha: 0.3,
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              r.hasErrors
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              size: 15,
              color: r.hasErrors ? ShopColors.warn : ShopColors.ok,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                r.summaryFa,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: r.hasErrors ? ShopColors.warn : ShopColors.ok,
                ),
              ),
            ),
          ],
        ),
        for (final e in r.firstErrors)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '• $e',
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.7,
                color: ShopColors.inkSoft,
              ),
            ),
          ),
      ],
    ),
  );
}

// ============================================================
//  مودال فرم دوربین
// ============================================================

class CctvCameraFormSheet extends StatefulWidget {
  const CctvCameraFormSheet({
    super.key,
    required this.repo,
    required this.nvrs,
    this.row,
  });
  final CctvRepository repo;
  final List<CctvNvrRow> nvrs;
  final CctvCameraRow? row;

  @override
  State<CctvCameraFormSheet> createState() => _CctvCameraFormSheetState();
}

class _CctvCameraFormSheetState extends State<CctvCameraFormSheet> {
  final _model = TextEditingController();
  final _serial = TextEditingController();
  final _ip = TextEditingController();
  final _mac = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  int? _nvrId;
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
      _nvrId = r.nvrId;
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

  CctvCameraForm _build() => CctvCameraForm(
    id: widget.row?.id ?? 0,
    model: _model.text.trim(),
    serialNumber: _serial.text.trim(),
    ip: _ip.text.trim().isEmpty ? null : _ip.text.trim(),
    mac: _mac.text.trim().isEmpty ? null : _mac.text.trim(),
    location: _location.text.trim(),
    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    isActive: _isActive,
    nvrId: _nvrId,
  );

  Future<void> _save() async {
    final f = _build();
    final err = validateCameraForm(f);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.saveCamera(f);
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
    final activeNvrs = widget.nvrs.where((n) => n.isActive).toList()
      ..sort((a, b) => a.model.compareTo(b.model));
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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
                  Icons.videocam_rounded,
                  size: 17,
                  color: Color(0xff6d43d6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isEdit ? 'ویرایش دوربین' : 'افزودن دوربین مداربسته',
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
                    decoration: _dec('مثلاً: Hikvision DS-2CD2143G2-I'),
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
                          decoration: _dec('192.168.1.101'),
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
                          decoration: _dec('C0:56:E3:AA:BB:01'),
                        ),
                      ),
                    ),
                  ],
                ),
                ShopField(
                  label: 'محل استقرار',
                  required: true,
                  child: TextField(
                    controller: _location,
                    maxLength: 250,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('مثلاً: انبار مرکزی — سردر شرقی'),
                  ),
                ),
                ShopField(
                  label: 'دستگاه NVR متصل',
                  child: DropdownButtonFormField<int>(
                    initialValue: _nvrId,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.ink,
                    ),
                    decoration: _dec(),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          '— بدون NVR / مستقیم —',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      for (final n in activeNvrs)
                        DropdownMenuItem<int>(
                          value: n.id,
                          child: Text(
                            n.optionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _nvrId = v),
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
                      'دوربین فعال باشد',
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
                                _isEdit ? 'ذخیره تغییرات' : 'افزودن دوربین',
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
