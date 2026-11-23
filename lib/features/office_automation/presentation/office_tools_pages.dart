// ============================================================
//  صفحات مکمل و مدیریتی «اتوماسیون اداری توکا» — هم‌تراز با وب:
//    ۱) `LetterGroupsPage`     ← گروه‌های گیرندگان نامه (`LetterGroups.razor`)
//    ۲) `LetterStructurePage`  ← ساختار شماره نامه / اندیکاتور (`LetterStructure.razor`)
//    ۳) `AmalgarsManagerPage`  ← عناوین و دستورات ارجاع (`amalgars`)
//    ۴) `PersonalArchivePage`  ← بایگانی شخصی من (`MyArchive.razor`)
//    ۵) `OfficeGuidePage`      ← راهنمای جامع اتوماسیون و دبیرخانه (`OfficeGuide.razor`)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/web_access.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/office_repository.dart';
import '../models/letter_models.dart';
import '../models/office_common.dart';
import 'office_style.dart';

OfficeAutomationRepository _resolveRepo(BuildContext context) =>
    Provider.of<OfficeAutomationRepository?>(context, listen: false) ??
    OfficeAutomationRepository(context.read<ApiClient>());

PreferredSizeWidget _luxuryAppBar(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  List<Widget>? actions,
}) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(72),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff0f172a), Color(0xff1e3a8a), Color(0xff4338ca)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              ...?actions,
            ],
          ),
        ),
      ),
    ),
  );
}

// ============================================================
//  ۱) گروه‌های گیرندگان نامه (`LetterGroups.razor`)
// ============================================================

class LetterGroupsPage extends StatefulWidget {
  const LetterGroupsPage({super.key});

  @override
  State<LetterGroupsPage> createState() => _LetterGroupsPageState();
}

class _LetterGroupsPageState extends State<LetterGroupsPage> {
  OfficeAutomationRepository get _repo => _resolveRepo(context);

  bool _loading = true;
  String? _error;
  List<LetterGroup> _groups = const [];
  List<LetterRecipient> _people = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Future.wait([
        _repo.groups(LetterKind.inner),
        _repo
            .recipients(LetterKind.inner)
            .catchError((_) => const <LetterRecipient>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = res[0] as List<LetterGroup>;
        _people = res[1] as List<LetterRecipient>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? OfficeColors.danger : const Color(0xff0f766e),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openEditor({LetterGroup? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final selectedIds = <int>{
      for (final m in existing?.members ?? const <LetterRecipient>[]) m.userId,
    };
    String search = '';
    bool saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final filtered = _people.where((p) {
            if (search.trim().isEmpty) return true;
            final q = search.trim().toLowerCase();
            return p.label.toLowerCase().contains(q) ||
                (p.sematTitle ?? '').toLowerCase().contains(q);
          }).toList();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  MediaQuery.of(ctx).viewInsets.bottom + 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          color: Color(0xff4f46e5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            existing == null
                                ? 'تعریف گروه گیرندگان جدید'
                                : 'ویرایش گروه «${existing.name}»',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'نام گروه (مثلاً مدیران واحد مالی) *',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (v) => setS(() => search = v),
                      decoration: InputDecoration(
                        hintText:
                            'جستجوی اعضا (${Fa.digits(selectedIds.length)} نفر انتخاب شده)…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 19),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: filtered.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('کاربری یافت نشد'),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final p = filtered[i];
                                final checked = selectedIds.contains(p.userId);
                                return CheckboxListTile(
                                  dense: true,
                                  value: checked,
                                  onChanged: (_) => setS(() {
                                    if (!selectedIds.remove(p.userId)) {
                                      selectedIds.add(p.userId);
                                    }
                                  }),
                                  title: Text(
                                    p.label,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: (p.sematTitle ?? '').isEmpty
                                      ? null
                                      : Text(
                                          p.sematTitle!,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff4f46e5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty) {
                                _toast('نام گروه الزامی است.', error: true);
                                return;
                              }
                              if (selectedIds.isEmpty) {
                                _toast('حداقل یک عضو انتخاب کنید.', error: true);
                                return;
                              }
                              setS(() => saving = true);
                              try {
                                await _repo.saveGroup(
                                  groupId: existing?.groupId ?? 0,
                                  nameGroup: nameCtrl.text,
                                  memberUserIds: selectedIds.toList(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (e) {
                                _toast(e.toString(), error: true);
                              } finally {
                                if (ctx.mounted) setS(() => saving = false);
                              }
                            },
                      icon: const Icon(Icons.check_rounded),
                      label: Text(saving ? 'در حال ذخیره…' : 'ذخیره گروه گیرندگان'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    nameCtrl.dispose();
    if (saved == true) {
      _toast('گروه گیرندگان ذخیره شد.');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<AuthController?>(context)?.session;
    final access = WebAccess(session, unrestrictedWhenNull: true);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfff4f6fb),
        appBar: _luxuryAppBar(
          context,
          title: 'گروه‌های گیرندگان نامه',
          subtitle: 'تعریف گروه برای انتخاب سریع در نامه داخلی، ارجاع و هامش',
          icon: Icons.groups_2_rounded,
          actions: [
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
        floatingActionButton: access.canManageLetterGroups
            ? FloatingActionButton.extended(
                backgroundColor: const Color(0xff4f46e5),
                foregroundColor: Colors.white,
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.group_add_rounded),
                label: const Text(
                  'گروه جدید',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : _groups.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'هنوز گروه گیرندگان تعریف نشده است.\nبا دکمهٔ «گروه جدید» اعضای یک واحد یا کمیته را گروه کنید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xff64748b),
                      height: 1.8,
                    ),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
                  itemCount: _groups.length,
                  itemBuilder: (_, i) {
                    final g = _groups[i];
                    final count = g.memberCount > 0
                        ? g.memberCount
                        : g.members.length;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xffe2e8f0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xff4f46e5,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              color: Color(0xff4f46e5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.name,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${Fa.digits(count)} عضو در این گروه',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xff64748b),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (access.canManageLetterGroups) ...[
                            IconButton(
                              tooltip: 'ویرایش',
                              onPressed: () => _openEditor(existing: g),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Color(0xff4f46e5),
                              ),
                            ),
                            IconButton(
                              tooltip: 'حذف',
                              onPressed: () async {
                                try {
                                  await _repo.deleteGroup(g.groupId);
                                  _toast('گروه حذف شد.');
                                  await _load();
                                } catch (e) {
                                  _toast(e.toString(), error: true);
                                }
                              },
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: OfficeColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

// ============================================================
//  ۲) ساختار شماره نامه و اندیکاتور (`LetterStructure.razor`)
// ============================================================

class LetterStructurePage extends StatefulWidget {
  const LetterStructurePage({super.key});

  @override
  State<LetterStructurePage> createState() => _LetterStructurePageState();
}

class _LetterStructurePageState extends State<LetterStructurePage> {
  OfficeAutomationRepository get _repo => _resolveRepo(context);

  bool _loading = true;
  String? _error;
  List<LetterStructureItem> _items = const [];
  final Map<int, List<String>> _draftParts = {};
  final Set<int> _savingForms = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.getLetterStructures();
      if (!mounted) return;
      setState(() {
        _items = list;
        _draftParts.clear();
        for (final it in list) {
          _draftParts[it.typeForm] = List<String>.from(it.parts);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _previewFor(List<String> parts) {
    if (parts.isEmpty) return '—';
    return parts
        .map(
          (p) => switch (p) {
            'سال' => '۱۴۰۵',
            'واحد' => 'FA',
            'شماره' => '۱۰۲۴',
            _ => p,
          },
        )
        .join('/');
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<AuthController?>(context)?.session;
    final access = WebAccess(session, unrestrictedWhenNull: true);
    final canEdit = access.canUpdateLetterStructures;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfff4f6fb),
        appBar: _luxuryAppBar(
          context,
          title: 'ساختار شماره نامه (اندیکاتور)',
          subtitle: 'چیدمان اجزای «سال / واحد / شماره» برای داخلی، صادره و وارده',
          icon: Icons.format_list_numbered_rtl_rounded,
          actions: [
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffeef2ff),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xffc7d2fe)),
                    ),
                    child: const Text(
                      'هر ساختار باید حداقل شامل جزء «شماره» به همراه یک جزء دیگر («سال» یا «واحد») باشد. تغییر فرمت فقط روی نامه‌های جدید اثر می‌گذارد.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xff3730a3),
                        height: 1.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final it in _items) _buildStructureCard(it, canEdit),
                ],
              ),
      ),
    );
  }

  Widget _buildStructureCard(LetterStructureItem item, bool canEdit) {
    final parts = _draftParts[item.typeForm] ?? const [];
    final remaining = LetterStructureItem.availableParts
        .where((p) => !parts.contains(p))
        .toList();
    final saving = _savingForms.contains(item.typeForm);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title.isEmpty
                      ? 'نوع نامه ${Fa.digits(item.typeForm)}'
                      : item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xfff1f5f9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'پیش‌نمایش: ${_previewFor(parts)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff334155),
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
              for (var i = 0; i < parts.length; i++)
                Chip(
                  label: Text(
                    parts[i],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  deleteIcon: canEdit
                      ? const Icon(Icons.close_rounded, size: 16)
                      : null,
                  onDeleted: canEdit
                      ? () => setState(() => parts.removeAt(i))
                      : null,
                ),
            ],
          ),
          if (canEdit && remaining.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in remaining)
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 15),
                    label: Text('افزودن $r'),
                    onPressed: () => setState(() => parts.add(r)),
                  ),
              ],
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                onPressed: saving
                    ? null
                    : () async {
                        if (!parts.contains('شماره') || parts.length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'حداقل «شماره» و یک جزء دیگر لازم است.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _savingForms.add(item.typeForm));
                        try {
                          await _repo.updateLetterStructure(
                            item.typeForm,
                            parts,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ساختار شماره نامه ذخیره شد.'),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        } finally {
                          if (mounted) {
                            setState(() => _savingForms.remove(item.typeForm));
                          }
                        }
                      },
                icon: const Icon(Icons.save_outlined, size: 17),
                label: Text(saving ? 'در حال ذخیره…' : 'ذخیره فرمت'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
//  ۳) عناوین و دستورات ارجاع (`AmalgarsManagerPage`)
// ============================================================

class AmalgarsManagerPage extends StatefulWidget {
  const AmalgarsManagerPage({super.key});

  @override
  State<AmalgarsManagerPage> createState() => _AmalgarsManagerPageState();
}

class _AmalgarsManagerPageState extends State<AmalgarsManagerPage> {
  OfficeAutomationRepository get _repo => _resolveRepo(context);

  LetterKind _kind = LetterKind.inner;
  bool _loading = true;
  List<Amalgar> _list = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _repo.amalgars(_kind);
      if (!mounted) return;
      setState(() {
        _list = res;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAmalgar() async {
    final ctrl = TextEditingController();
    bool reqSign = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text(
              'تعریف دستور ارجاع جدید',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    labelText: 'عنوان ارجاع (مثلاً جهت اقدام فوری)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: reqSign,
                  onChanged: (v) => setS(() => reqSign = v ?? false),
                  title: const Text(
                    'نیازمند تأیید / امضا',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ثبت'),
              ),
            ],
          ),
        ),
      ),
    );
    final t = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || t.isEmpty) return;
    try {
      await _repo.createAmalgar(_kind, title: t, requiresSign: reqSign);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfff4f6fb),
        appBar: _luxuryAppBar(
          context,
          title: 'عناوین و دستورات ارجاع',
          subtitle: 'مدیریت قالب‌های دستور ارجاع برای نامه‌های داخلی، صادره و وارده',
          icon: Icons.alt_route_rounded,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xff4f46e5),
          foregroundColor: Colors.white,
          onPressed: _addAmalgar,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'دستور جدید',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: SegmentedButton<LetterKind>(
                segments: const [
                  ButtonSegment(
                    value: LetterKind.inner,
                    label: Text('داخلی'),
                  ),
                  ButtonSegment(
                    value: LetterKind.outgoing,
                    label: Text('صادره'),
                  ),
                  ButtonSegment(
                    value: LetterKind.incoming,
                    label: Text('وارده'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) {
                  setState(() => _kind = s.first);
                  _load();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _list.isEmpty
                  ? const Center(child: Text('عنوان ارجاعی ثبت نشده است.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 96),
                      itemCount: _list.length,
                      itemBuilder: (_, i) {
                        final a = _list[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xffe2e8f0)),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.subdirectory_arrow_left_rounded,
                              color: Color(0xff4f46e5),
                            ),
                            title: Text(
                              a.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            trailing: a.requiresSign
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfffef3c7),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'نیازمند امضا',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xffb45309),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  ۴) بایگانی شخصی من (`MyArchive.razor`)
// ============================================================

class PersonalArchivePage extends StatefulWidget {
  const PersonalArchivePage({super.key});

  @override
  State<PersonalArchivePage> createState() => _PersonalArchivePageState();
}

class _PersonalArchivePageState extends State<PersonalArchivePage> {
  OfficeAutomationRepository get _repo => _resolveRepo(context);

  bool _loading = true;
  List<PersonalArchiveFolder> _folders = const [];
  PersonalArchiveFolder? _selectedFolder;
  List<PersonalArchiveItem> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFolders());
  }

  Future<void> _loadFolders() async {
    setState(() => _loading = true);
    try {
      final f = await _repo.personalArchiveFolders();
      if (!mounted) return;
      setState(() {
        _folders = f;
        _selectedFolder = f.isNotEmpty ? f.first : null;
      });
      if (_selectedFolder != null) {
        await _loadItems(_selectedFolder!.id);
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadItems(int folderId) async {
    setState(() => _loading = true);
    try {
      final it = await _repo.personalArchiveItems(folderId);
      if (!mounted) return;
      setState(() {
        _items = it;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'ایجاد پوشهٔ بایگانی شخصی',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'نام پوشه',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
      ),
    );
    final t = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || t.isEmpty) return;
    try {
      await _repo.createPersonalArchiveFolder(t);
      await _loadFolders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfff4f6fb),
        appBar: _luxuryAppBar(
          context,
          title: 'بایگانی شخصی من',
          subtitle: 'پوشه‌بندی اختصاصی نامه‌ها و اسناد ارجاعی کاربر',
          icon: Icons.folder_special_rounded,
          actions: [
            IconButton(
              tooltip: 'پوشه جدید',
              onPressed: _createFolder,
              icon: const Icon(
                Icons.create_new_folder_outlined,
                color: Colors.white,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_folders.isNotEmpty)
              SizedBox(
                height: 54,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _folders.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _folders[i];
                    final active = _selectedFolder?.id == f.id;
                    return ChoiceChip(
                      selected: active,
                      avatar: const Icon(Icons.folder_outlined, size: 16),
                      label: Text(
                        f.itemCount > 0
                            ? '${f.title} (${Fa.digits(f.itemCount)})'
                            : f.title,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedFolder = f);
                        _loadItems(f.id);
                      },
                    );
                  },
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _folders.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.folder_copy_outlined,
                              size: 46,
                              color: Color(0xff94a3b8),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'هنوز پوشه‌ای در بایگانی شخصی ندارید.',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _createFolder,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('ساخت اولین پوشه'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'این پوشه خالی است.',
                        style: TextStyle(color: Color(0xff64748b)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final it = _items[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xffe2e8f0)),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.article_outlined,
                              color: Color(0xff4f46e5),
                            ),
                            title: Text(
                              it.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (it.refNumber.isNotEmpty)
                                  'شماره: ${Fa.digits(it.refNumber)}',
                                if (it.createdAt != null)
                                  jalaliShort(it.createdAt!),
                              ].join(' • '),
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: OfficeColors.danger,
                              ),
                              onPressed: () async {
                                try {
                                  await _repo.deletePersonalArchiveItem(it.id);
                                  if (_selectedFolder != null) {
                                    await _loadItems(_selectedFolder!.id);
                                  }
                                } catch (_) {}
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  ۵) راهنمای جامع اتوماسیون اداری و دبیرخانه توکا (`OfficeGuide.razor`)
// ============================================================

class OfficeGuidePage extends StatelessWidget {
  const OfficeGuidePage({super.key});

  static const _sections = [
    (
      title: '۱. کارتابل نامه‌های داخلی و چرخهٔ ارجاع',
      icon: Icons.mark_email_unread_rounded,
      color: Color(0xff2563eb),
      points: [
        'نامهٔ داخلی برای مکاتبهٔ رسمی درون‌سازمانی بین افراد، سمت‌ها و گروه‌های گیرندگان استفاده می‌شود.',
        'گیرندهٔ اصلی، رونوشت و ارجاع همراه با دستور ارجاع («جهت اقدام»، «جهت استحضار» و مهلت پاسخ) ثبت می‌شوند.',
        'تا پیش از رویت نامه توسط گیرندگان، فرستنده امکان ویرایش متن و گیرندگان را دارد.',
      ],
    ),
    (
      title: '۲. نامه‌های صادره و زنجیرهٔ امضای دیجیتال',
      icon: Icons.draw_rounded,
      color: Color(0xff059669),
      points: [
        'نامهٔ صادره با انتخاب شرکت (سربرگ رسمی)، سازمان مقصد و ترتیب امضاکنندگان ثبت می‌شود.',
        'امضاکنندگان به ترتیب اولویت، نامه را در صندوق «امضای من» بررسی و امضا می‌کنند.',
        'بلافاصله پس از آخرین امضا، شمارهٔ صادره به صورت خودکار صادر شده و نامه وارد صف «دبیرخانه یکپارچه» می‌شود.',
      ],
    ),
    (
      title: '۳. دبیرخانه یکپارچه و رزرو شماره اندیکاتور',
      icon: Icons.markunread_mailbox_rounded,
      color: Color(0xff4f46e5),
      points: [
        'در دبیرخانه صادره، روش ارسال (پست پیشتاز، پیک، ایمیل رسمی دبیرخانه، فکس، تحویل حضوری یا ECE) و کد رهگیری/تحویل‌گیرنده ثبت می‌شود.',
        'چاپ رسمی نامه روی سربرگ A4 یا A5 در دو نسخهٔ «با رونوشت» و «بدون رونوشت» انجام می‌گیرد.',
        'در دبیرخانه وارده، نامه‌های رسیده از سازمان‌های بیرونی با شماره ثبت اندیکاتور (یا شماره‌های از پیش رزروشده) ثبت و به واحدها ارجاع می‌شوند.',
      ],
    ),
    (
      title: '۴. بایگانی درختی شخصی و بایگانی رسمی دبیرخانه',
      icon: Icons.account_tree_rounded,
      color: Color(0xff7c3aed),
      points: [
        'هر کاربر می‌تواند درخت پوشه‌های بایگانی اختصاصی خود را بسازد و نامه‌ها را به شکل تکی یا گروهی بایگانی کند.',
        'بایگانی رسمی دبیرخانه مستقل از بایگانی شخصی است و مخصوص پرونده‌های رسمی نامه‌های صادره و واردهٔ سازمان است.',
      ],
    ),
    (
      title: '۵. پست الکترونیک سازمانی و شخصی',
      icon: Icons.alternate_email_rounded,
      color: Color(0xff0e7490),
      points: [
        'ایمیل سازمانی برای حساب‌های رسمی واحدها و دبیرخانه و ایمیل شخصی برای حساب اختصاصی کاربر (با مجوز Email.Personal) تفکیک شده است.',
        'امکان ذخیرهٔ پیش‌نویس، پیوست فایل و ارسال مستقیم PDF نامه‌های صادره از حساب دبیرخانه فراهم است.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xfff4f6fb),
        appBar: _luxuryAppBar(
          context,
          title: 'راهنمای جامع اتوماسیون اداری توکا',
          subtitle: 'فرآیندهای استاندارد مکاتبات، زنجیره امضا، دبیرخانه یکپارچه و بایگانی',
          icon: Icons.menu_book_rounded,
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            for (final s in _sections)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: s.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(s.icon, color: s.color, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final p in s.points)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff475569),
                                  height: 1.7,
                                ),
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
      ),
    );
  }
}
