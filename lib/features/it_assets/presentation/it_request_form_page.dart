// ============================================================
//  «درخواست خدمت جدید» — فاز ۹-ب
//  آینهٔ مودال ثبت درخواست `Pages/ItAssets/ItRequests.razor`:
//    نام و نام خانوادگی درخواست‌کننده (پیش‌فرض از کاربر لاگین، قابل ویرایش)
//    نوع درخواست * (سخت‌افزار / نرم‌افزار / شبکه و زیرساخت / مخابرات)
//    سیستم مربوطه (جستجو در نام سیستم، IP، مالک — «بدون سیستم / سایر»)
//    موضوع درخواست * («مثلاً: سیستم روشن نمی‌شود»)
//    شرح درخواست + فایل پیوست (اختیاری)
//  دکمه‌ها: «انصراف» / «ثبت درخواست» و پیام موفقیت «درخواست شما ثبت شد.»
//  اعتبارسنجی وب: «موضوع درخواست را وارد کنید.»
// ============================================================

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/it_request_repository.dart';
import '../models/it_request_models.dart';

class ItRequestFormPage extends StatefulWidget {
  const ItRequestFormPage({super.key});

  @override
  State<ItRequestFormPage> createState() => _ItRequestFormPageState();
}

class _ItRequestFormPageState extends State<ItRequestFormPage> {
  late final ItRequestRepository _repo;

  final _requesterName = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();

  String _type = ItRequestType.hardware;
  ItSystemOption? _system;
  List<ItSystemOption> _systems = const [];

  List<({String name, Uint8List bytes})> _files = const [];

  bool _loadingSystems = true;
  bool _busy = false;
  String? _error;
  bool _editName = false;

  @override
  void initState() {
    super.initState();
    _repo = ItRequestRepository(context.read<ApiClient>());
    final session = context.read<AuthController>().session;
    if (session != null) _requesterName.text = session.displayName;
    _loadSystems();
  }

  @override
  void dispose() {
    _requesterName.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _loadSystems() async {
    try {
      final list = await _repo.systems();
      if (!mounted) return;
      setState(() {
        _systems = list;
        _loadingSystems = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSystems = false);
    }
  }

  Future<void> _pickFiles() async {
    try {
      final res = await FilePicker.pickFiles();
      if (res.isEmpty) return;
      final picked = <({String name, Uint8List bytes})>[];
      for (final f in res) {
        final b = await f.xFile.readAsBytes();
        if (b.length > 10 * 1024 * 1024) continue;
        picked.add((name: f.name, bytes: b));
      }
      if (!mounted) return;
      setState(() => _files = [..._files, ...picked]);
    } catch (e) {
      setState(() => _error = _clean(e));
    }
  }

  Future<void> _pickSystem() async {
    final picked = await showModalBottomSheet<ItSystemOption?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _SystemPickerSheet(systems: _systems),
    );
    if (picked == null) return;
    setState(() => _system = picked.id == 0 ? null : picked);
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    // همان اعتبارسنجی وب
    if (_title.text.trim().isEmpty) {
      setState(() {
        _error = 'موضوع درخواست را وارد کنید.';
        _busy = false;
      });
      return;
    }
    try {
      final created = await _repo.create(
        requesterName: _requesterName.text.trim(),
        requestType: _type,
        title: _title.text.trim(),
        description: _description.text.trim(),
        systemInfoId: _system?.id,
        systemLabel: _system?.display,
      );
      final id = (created['id'] as num?)?.toInt() ?? 0;
      if (id > 0) {
        for (final f in _files) {
          try {
            await _repo.uploadAttachment(
              id,
              fileName: f.name,
              bytes: f.bytes,
              role: 'Requester',
            );
          } catch (_) {}
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('درخواست شما ثبت شد.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
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
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Row(
          children: [
            Icon(Icons.headset_mic_rounded, size: 17, color: ShopColors.seed),
            SizedBox(width: 6),
            Text(
              'درخواست خدمت جدید',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: ShopColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: ShopColors.danger,
                  height: 1.7,
                ),
              ),
            ),
          // نام درخواست‌کننده
          _label('نام و نام خانوادگی درخواست‌کننده'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _requesterName,
                  enabled: _editName,
                  style: const TextStyle(fontSize: 11.5),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _editName = !_editName),
                icon: Icon(
                  _editName ? Icons.lock_outline_rounded : Icons.edit_rounded,
                  size: 17,
                ),
                tooltip: 'ویرایش نام',
              ),
            ],
          ),
          const SizedBox(height: 10),
          // نوع درخواست
          _label('نوع درخواست *'),
          DropdownButtonFormField<String>(
            initialValue: _type,
            style: const TextStyle(fontSize: 11.5, color: ShopColors.ink),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 12,
              ),
            ),
            items: [
              for (final t in ItRequestType.all)
                DropdownMenuItem(
                  value: t,
                  child: Text(
                    ItRequestType.label(t),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 10),
          // سیستم مربوطه
          _label('سیستم مربوطه'),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: _loadingSystems ? null : _pickSystem,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: ShopColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ShopColors.inkFaint),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.desktop_windows_rounded,
                      size: 15,
                      color: ShopColors.inkFaint,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _system == null
                            ? '— بدون سیستم / سایر —'
                            : _system!.display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: _system == null
                              ? ShopColors.inkFaint
                              : ShopColors.ink,
                        ),
                      ),
                    ),
                    if (_system != null)
                      InkWell(
                        onTap: () => setState(() => _system = null),
                        child: const Icon(
                          Icons.cancel_rounded,
                          size: 15,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 17,
                      color: ShopColors.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // موضوع
          _label('موضوع درخواست *'),
          TextField(
            controller: _title,
            style: const TextStyle(fontSize: 11.5),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'مثلاً: سیستم روشن نمی‌شود',
              hintStyle: TextStyle(fontSize: 10.5),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          // شرح
          _label('شرح درخواست'),
          TextField(
            controller: _description,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontSize: 11.5, height: 1.8),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'جزئیات مشکل یا درخواست را بنویسید…',
              hintStyle: TextStyle(fontSize: 10.5),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          // پیوست
          _label('فایل پیوست (اختیاری — بدون محدودیت حجم)'),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickFiles,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
            ),
            icon: const Icon(Icons.attach_file_rounded, size: 16),
            label: const Text(
              'انتخاب فایل',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              '${_files.length} فایل انتخاب شد.',
              style: const TextStyle(
                fontSize: 10,
                color: ShopColors.ok,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final f in _files)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file_rounded,
                      size: 13,
                      color: ShopColors.inkFaint,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(
                        () => _files = _files.where((x) => x != f).toList(),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: ShopColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text(
                    'انصراف',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: ShopColors.seed,
                    minimumSize: const Size(0, 44),
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
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text(
                    'ثبت درخواست',
                    style: TextStyle(
                      fontSize: 11.5,
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

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: ShopColors.inkSoft,
      ),
    ),
  );
}

/// انتخابگر سیستم با جستجو — مثل کمبوی وب
class _SystemPickerSheet extends StatefulWidget {
  const _SystemPickerSheet({required this.systems});
  final List<ItSystemOption> systems;

  @override
  State<_SystemPickerSheet> createState() => _SystemPickerSheetState();
}

class _SystemPickerSheetState extends State<_SystemPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ItSystemOption> get _items {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.systems;
    return widget.systems.where((s) {
      return s.label.toLowerCase().contains(q) ||
          s.ip.toLowerCase().contains(q) ||
          s.userName.toLowerCase().contains(q) ||
          s.departmentName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: ShopColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            TextField(
              controller: _search,
              autofocus: true,
              style: const TextStyle(fontSize: 11.5),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'جستجو (نام سیستم، IP، مالک)...',
                hintStyle: TextStyle(fontSize: 10.5),
                prefixIcon: Icon(Icons.search_rounded, size: 16),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.remove_circle_outline, size: 16),
                    title: const Text(
                      'بدون سیستم / سایر',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(const ItSystemOption()),
                  ),
                  for (final s in _items)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.desktop_windows_rounded,
                        size: 16,
                        color: ShopColors.seed,
                      ),
                      title: Text(
                        s.display,
                        style: const TextStyle(fontSize: 11),
                      ),
                      subtitle: s.ip.trim().isEmpty
                          ? null
                          : Text(
                              s.ip,
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                      onTap: () => Navigator.of(context).pop(s),
                    ),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'سیستمی پیدا نشد.',
                        style: TextStyle(
                          fontSize: 10.5,
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
    );
  }
}
