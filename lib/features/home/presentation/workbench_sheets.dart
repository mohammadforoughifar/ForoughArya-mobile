// ============================================================
//  شیت‌های تعاملی «میز کار حرفه‌ای فروغ آریا»
//    ۱) WorkbenchCommandSheet   — فرمان‌یار و جستجوی فوری سراسر سازمان
//    ۲) WorkbenchCustomizeSheet — شخصی‌سازی چیدمان و بخش‌های میز کار
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/home_models.dart';
import 'home_style.dart';

/// تنظیمات ذخیره‌شدهٔ میز کار کاربر در حافظهٔ امن دستگاه.
class WorkbenchPrefs {
  const WorkbenchPrefs({
    this.showQuickActions = true,
    this.showCartable = true,
    this.showKpis = true,
    this.compactModules = false,
    this.pinnedIds = const {'letters', 'workorders', 'shop', 'chat'},
  });

  final bool showQuickActions;
  final bool showCartable;
  final bool showKpis;
  final bool compactModules;
  final Set<String> pinnedIds;

  static const _storageKey = 'workbench_prefs_v1';

  WorkbenchPrefs copyWith({
    bool? showQuickActions,
    bool? showCartable,
    bool? showKpis,
    bool? compactModules,
    Set<String>? pinnedIds,
  }) => WorkbenchPrefs(
    showQuickActions: showQuickActions ?? this.showQuickActions,
    showCartable: showCartable ?? this.showCartable,
    showKpis: showKpis ?? this.showKpis,
    compactModules: compactModules ?? this.compactModules,
    pinnedIds: pinnedIds ?? this.pinnedIds,
  );

  Map<String, dynamic> toJson() => {
    'showQuickActions': showQuickActions,
    'showCartable': showCartable,
    'showKpis': showKpis,
    'compactModules': compactModules,
    'pinnedIds': pinnedIds.toList(),
  };

  factory WorkbenchPrefs.fromJson(Map<String, dynamic> j) => WorkbenchPrefs(
    showQuickActions: j['showQuickActions'] != false,
    showCartable: j['showCartable'] != false,
    showKpis: j['showKpis'] != false,
    compactModules: j['compactModules'] == true,
    pinnedIds: j['pinnedIds'] is List
        ? (j['pinnedIds'] as List).map((e) => e.toString()).toSet()
        : const {'letters', 'workorders', 'shop', 'chat'},
  );

  static Future<WorkbenchPrefs> load(FlutterSecureStorage storage) async {
    try {
      final raw = await storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        return WorkbenchPrefs.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
    } catch (_) {}
    return const WorkbenchPrefs();
  }

  Future<void> save(FlutterSecureStorage storage) async {
    try {
      await storage.write(key: _storageKey, value: jsonEncode(toJson()));
    } catch (_) {}
  }
}

/// یک دستور یا مسیر قابل جستجو در فرمان‌یار میز کار.
class WorkbenchCommandItem {
  const WorkbenchCommandItem({
    required this.title,
    required this.subtitle,
    required this.group,
    required this.icon,
    required this.color,
    required this.onSelect,
    this.keywords = const [],
    this.badge,
  });

  final String title;
  final String subtitle;
  final String group;
  final IconData icon;
  final Color color;
  final VoidCallback onSelect;
  final List<String> keywords;
  final String? badge;

  bool matches(String rawQuery) {
    final q = _norm(rawQuery);
    if (q.isEmpty) return true;
    final hay = _norm('$title $subtitle $group ${keywords.join(' ')}');
    return q.split(' ').where((t) => t.isNotEmpty).every(hay.contains);
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('\u200c', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

// ============================================================
//  شیت فرمان‌یار و جستجوی فوری سراسر میز کار
// ============================================================

class WorkbenchCommandSheet extends StatefulWidget {
  const WorkbenchCommandSheet({
    super.key,
    required this.items,
  });

  final List<WorkbenchCommandItem> items;

  @override
  State<WorkbenchCommandSheet> createState() => _WorkbenchCommandSheetState();
}

class _WorkbenchCommandSheetState extends State<WorkbenchCommandSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filtered = widget.items.where((i) => i.matches(_query)).toList();

    // گروه‌بندی نتایج
    final groups = <String, List<WorkbenchCommandItem>>{};
    for (final item in filtered) {
      (groups[item.group] ??= []).add(item);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          decoration: const BoxDecoration(
            color: HomeColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HomeColors.line,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: HomeColors.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: HomeColors.seed.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.manage_search_rounded,
                        color: HomeColors.seed,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          autofocus: true,
                          onChanged: (v) => setState(() => _query = v),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: HomeColors.ink,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                'جستجوی ماژول، فرم یا عملیات (مثلاً فاکتور فروش، توکا، چک، رایکا)…',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: HomeColors.inkFaint,
                            ),
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: HomeColors.inkSoft,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: HomeColors.line),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 42),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: HomeColors.inkFaint.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'موردی مطابق جستجوی شما پیدا نشد',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: HomeColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                        shrinkWrap: true,
                        children: [
                          for (final entry in groups.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: HomeColors.inkFaint,
                                ),
                              ),
                            ),
                            for (final item in entry.value)
                              _CommandTile(
                                item: item,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(context);
                                  item.onSelect();
                                },
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({required this.item, required this.onTap});

  final WorkbenchCommandItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: HomeColors.surfaceSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, color: item.color, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: HomeColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: HomeColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if ((item.badge ?? '').isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    item.badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: item.color,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: HomeColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ============================================================
//  شیت شخصی‌سازی میز کار حرفه‌ای
// ============================================================

class WorkbenchCustomizeSheet extends StatefulWidget {
  const WorkbenchCustomizeSheet({
    super.key,
    required this.initial,
    required this.modules,
    required this.onChanged,
  });

  final WorkbenchPrefs initial;
  final List<ModuleTile> modules;
  final ValueChanged<WorkbenchPrefs> onChanged;

  @override
  State<WorkbenchCustomizeSheet> createState() =>
      _WorkbenchCustomizeSheetState();
}

class _WorkbenchCustomizeSheetState extends State<WorkbenchCustomizeSheet> {
  late WorkbenchPrefs _prefs = widget.initial;

  void _apply(WorkbenchPrefs next) {
    HapticFeedback.selectionClick();
    setState(() => _prefs = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: const BoxDecoration(
          color: HomeColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: HomeColors.line,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: HomeColors.hero,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'شخصی‌سازی میز کار',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: HomeColors.ink,
                        ),
                      ),
                      Text(
                        'بخش‌های قابل نمایش، تراکم کاشی‌ها و ماژول‌های سنجاق‌شده',
                        style: TextStyle(
                          fontSize: 11,
                          color: HomeColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _apply(const WorkbenchPrefs()),
                  child: const Text(
                    'پیش‌فرض',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: HomeColors.line),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 10),
                children: [
                  _switchTile(
                    icon: Icons.bolt_rounded,
                    color: const Color(0xffd97706),
                    title: 'نوار عملیات سریع یک‌ضربه‌ای',
                    subtitle:
                        'ثبت سریع فاکتور فروش/خرید، نامه، دستور کار، سند خزانه و…',
                    value: _prefs.showQuickActions,
                    onChanged: (v) =>
                        _apply(_prefs.copyWith(showQuickActions: v)),
                  ),
                  _switchTile(
                    icon: Icons.inbox_rounded,
                    color: HomeColors.seed,
                    title: 'کارتابل یکپارچه و میز اقدام',
                    subtitle:
                        'نمایش امور منتظر اقدام، اقدامات اصلی و پیگیری‌ها در صفحهٔ اول',
                    value: _prefs.showCartable,
                    onChanged: (v) => _apply(_prefs.copyWith(showCartable: v)),
                  ),
                  _switchTile(
                    icon: Icons.insights_rounded,
                    color: const Color(0xff059669),
                    title: 'شاخص‌های کلیدی عملکرد (KPI)',
                    subtitle: 'کارت‌های آماری امروز، هفته و ماه همراه نمودار روند',
                    value: _prefs.showKpis,
                    onChanged: (v) => _apply(_prefs.copyWith(showKpis: v)),
                  ),
                  _switchTile(
                    icon: Icons.grid_view_rounded,
                    color: const Color(0xff7c3aed),
                    title: 'چیدمان فشردهٔ ماژول‌ها (۳ ستونی)',
                    subtitle: 'نمایش تعداد بیشتری از ماژول‌ها در یک قاب',
                    value: _prefs.compactModules,
                    onChanged: (v) =>
                        _apply(_prefs.copyWith(compactModules: v)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ماژول‌های سنجاق‌شده در صدر میز کار',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: HomeColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final m in widget.modules)
                        FilterChip(
                          selected: _prefs.pinnedIds.contains(m.id),
                          showCheckmark: false,
                          avatar: Icon(
                            _prefs.pinnedIds.contains(m.id)
                                ? Icons.push_pin_rounded
                                : m.icon,
                            size: 15,
                            color: _prefs.pinnedIds.contains(m.id)
                                ? m.color
                                : HomeColors.inkSoft,
                          ),
                          label: Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _prefs.pinnedIds.contains(m.id)
                                  ? m.color
                                  : HomeColors.ink,
                            ),
                          ),
                          selectedColor: m.color.withValues(alpha: 0.13),
                          backgroundColor: HomeColors.bg,
                          side: BorderSide(
                            color: _prefs.pinnedIds.contains(m.id)
                                ? m.color.withValues(alpha: 0.45)
                                : HomeColors.line,
                          ),
                          onSelected: (sel) {
                            final next = Set<String>.from(_prefs.pinnedIds);
                            if (sel) {
                              next.add(m.id);
                            } else {
                              next.remove(m.id);
                            }
                            _apply(_prefs.copyWith(pinnedIds: next));
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.seed,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'تأیید و بازگشت به میز کار',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: HomeColors.surfaceSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: HomeColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: HomeColors.seed,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: HomeColors.ink,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 10.5, color: HomeColors.inkSoft),
        ),
      ),
    ),
  );
}
