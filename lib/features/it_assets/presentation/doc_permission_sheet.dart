// ============================================================
//  ویرایشگر دسترسی اختصاصی مدرک — فاز ۹-ط
//  آینهٔ `DocPermissionEditor.razor` + مودال «دسترسی اختصاصی» در وب
//
//  «نوع دسترسی» نفر / گروه، انتخاب کاربر یا نقش، سطح دسترسی
//  (مشاهده / خواندن / نوشتن / دسترسی کامل)، سوئیچ «دانلود»،
//  فهرست ردیف‌ها با حذف، و در همین شیت چهار سوئیچ امنیتی مدرک.
// ============================================================

import 'package:flutter/material.dart';

import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'doc_archive_page.dart' show docLevelColor;

class DocPermResult {
  const DocPermResult({
    required this.items,
    required this.isPublic,
    required this.publicCanDownload,
    required this.requireDownloadConfirm,
    required this.watermarkPreview,
  });
  final List<DocPermissionInput> items;
  final bool isPublic;
  final bool publicCanDownload;
  final bool requireDownloadConfirm;
  final bool watermarkPreview;
}

class DocPermissionSheet extends StatefulWidget {
  const DocPermissionSheet({
    super.key,
    required this.users,
    required this.roles,
    this.initialItems = const [],
    this.isPublic = false,
    this.publicCanDownload = false,
    this.requireDownloadConfirm = false,
    this.watermarkPreview = false,
    this.showSecurity = true,
  });

  final List<DocLookup> users;
  final List<DocLookup> roles;
  final List<DocPermissionInput> initialItems;
  final bool isPublic;
  final bool publicCanDownload;
  final bool requireDownloadConfirm;
  final bool watermarkPreview;

  /// در ویرایش پوشه سوئیچ‌های امنیتی مدرک نمایش داده نمی‌شوند
  final bool showSecurity;

  @override
  State<DocPermissionSheet> createState() => _DocPermissionSheetState();
}

class _DocPermissionSheetState extends State<DocPermissionSheet> {
  late final List<DocPermissionInput> _items = [...widget.initialItems];
  bool _pickRole = false;
  int _pickId = 0;
  int _pickLevel = DocLevel.read;
  bool _pickDownload = false;

  late bool _isPublic = widget.isPublic;
  late bool _publicDl = widget.publicCanDownload;
  late bool _confirm = widget.requireDownloadConfirm;
  late bool _watermark = widget.watermarkPreview;

  String _name(int id, bool isRole) {
    final list = isRole ? widget.roles : widget.users;
    for (final x in list) {
      if (x.id == id) return x.name;
    }
    return '#$id';
  }

  void _add() {
    if (_pickId <= 0) return;
    setState(() {
      _items.add(
        DocPermissionInput(
          userId: _pickRole ? 0 : _pickId,
          roleId: _pickRole ? _pickId : 0,
          level: _pickLevel,
          canDownload: _pickDownload,
        ),
      );
      _pickId = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = _pickRole ? widget.roles : widget.users;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 2),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'دسترسی اختصاصی',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(
                      DocPermResult(
                        items: _items,
                        isPublic: _isPublic,
                        publicCanDownload: _publicDl,
                        requireDownloadConfirm: _confirm,
                        watermarkPreview: _watermark,
                      ),
                    ),
                    child: const Text(
                      'ذخیره',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                children: [
                  const Text(
                    '«خواندن» فقط برای مشاهده است؛ ویرایش و ورژن جدید نیازمند «نوشتن» است. دانلود باید جداگانه انتخاب شود. مجوز اختصاصی فرد بر گروه و پوشهٔ والد اولویت دارد.',
                    style: TextStyle(
                      fontSize: 8.5,
                      height: 1.9,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShopSegmented(
                    labels: const ['نفر', 'گروه'],
                    index: _pickRole ? 1 : 0,
                    onChanged: (i) => setState(() {
                      _pickRole = i == 1;
                      _pickId = 0;
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: ValueKey('pick-$_pickRole'),
                    initialValue: _pickId == 0 ? null : _pickId,
                    isDense: true,
                    style: const TextStyle(fontSize: 10.5, color: ShopColors.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: _pickRole
                          ? 'افزودن گروه/نقش'
                          : 'افزودن نفر',
                      labelStyle: const TextStyle(fontSize: 9.5),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final u in list)
                        DropdownMenuItem(
                          value: u.id,
                          child: Text(
                            u.name,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _pickId = v ?? 0),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _pickLevel,
                          isDense: true,
                          style: const TextStyle(
                            fontSize: 10,
                            color: ShopColors.ink,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'سطح دسترسی',
                            labelStyle: TextStyle(fontSize: 9),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final o in DocLevel.options)
                              DropdownMenuItem(
                                value: o.key,
                                child: Text(
                                  o.key == 4 ? 'دسترسی کامل' : o.value,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            _pickLevel = v ?? DocLevel.read;
                            if (_pickLevel < DocLevel.read) _pickDownload = false;
                          }),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        children: [
                          const Text(
                            'دانلود',
                            style: TextStyle(
                              fontSize: 8.5,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                          Switch(
                            value: _pickDownload,
                            onChanged: _pickLevel < DocLevel.read
                                ? null
                                : (v) => setState(() => _pickDownload = v),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'افزودن',
                        icon: const Icon(
                          Icons.add_circle_rounded,
                          size: 22,
                          color: ShopColors.seed,
                        ),
                        onPressed: _pickId > 0 ? _add : null,
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  if (_items.isEmpty)
                    const Text(
                      'هنوز نفر یا گروهی اضافه نشده است.',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    )
                  else
                    for (var i = 0; i < _items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _name(
                                  _items[i].isRole
                                      ? _items[i].roleId
                                      : _items[i].userId,
                                  _items[i].isRole,
                                ),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            ShopTag(
                              text: DocLevel.name(_items[i].level),
                              color: docLevelColor(_items[i].level),
                            ),
                            if (_items[i].canDownload)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.download_rounded,
                                  size: 13,
                                  color: ShopColors.ok,
                                ),
                              ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: ShopColors.danger,
                              ),
                              onPressed: () =>
                                  setState(() => _items.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                  if (widget.showSecurity) ...[
                    const Divider(height: 20),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _isPublic,
                      onChanged: (v) => setState(() {
                        _isPublic = v;
                        if (!v) _publicDl = false;
                      }),
                      title: const Text(
                        'نمایش برای همه کاربران',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _publicDl,
                      onChanged: _isPublic
                          ? (v) => setState(() => _publicDl = v)
                          : null,
                      title: const Text(
                        'دانلود برای همه کاربران',
                        style: TextStyle(fontSize: 10.5),
                      ),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _confirm,
                      onChanged: (v) => setState(() => _confirm = v),
                      title: const Text(
                        'تأیید رمز برای مشاهده و دانلود',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: ShopColors.danger,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _watermark,
                      onChanged: (v) => setState(() => _watermark = v),
                      title: const Text(
                        'واترمارک نام کاربر و زمان مشاهده',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
