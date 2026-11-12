// ============================================================
//  مدیریت اتصال‌ها: چند سرور (سازمان) و چند آدرس برای هر سرور
//  — از صفحهٔ ورود و از منوی تنظیمات خانه باز می‌شود.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/connection_manager.dart';

const _seed = Color(0xff2547a8);
const _ink = Color(0xff1e293b);
const _inkSoft = Color(0xff5b6b85);
const _line = Color(0xffe4eaf3);
const _ok = Color(0xff1a7f37);
const _danger = Color(0xffc62828);

/// باز کردن شیت مدیریت اتصال‌ها
Future<void> showConnectionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ConnectionsSheet(),
  );
}

/// باز کردن فرم تعریف/ویرایش سرور
Future<void> openProfileEditor(
  BuildContext context, {
  ConnectionProfile? profile,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProfileEditorPage(profile: profile),
    ),
  );
}

class ConnectionsSheet extends StatefulWidget {
  const ConnectionsSheet({super.key});

  @override
  State<ConnectionsSheet> createState() => _ConnectionsSheetState();
}

class _ConnectionsSheetState extends State<ConnectionsSheet> {
  @override
  void initState() {
    super.initState();
    // وضعیت آدرس‌های سرور فعال بلافاصله تست شود
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ConnectionManager>().probeAll();
    });
  }

  Future<void> _switchTo(ConnectionProfile p) async {
    final auth = context.read<AuthController>();
    if (auth.isLoggedIn) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('سوییچ به «${p.displayName}»'),
          content: const Text(
            'نشست فعلی شما نگه داشته می‌شود و با برگشت به این سرور نیازی به '
            'ورود دوباره نیست. اگر قبلاً در سرور مقصد وارد نشده باشید، '
            'صفحهٔ ورود نمایش داده می‌شود.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('سوییچ'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    HapticFeedback.selectionClick();
    await auth.switchProfile(p.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete(ConnectionProfile p) async {
    final cm = context.read<ConnectionManager>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف سرور'),
        content: Text('«${p.displayName}» و نشست ذخیره‌شدهٔ آن حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await cm.deleteProfile(p.id);
    if (!done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سرور فعال را نمی‌توان حذف کرد؛ اول به سرور دیگری سوییچ کنید.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cm = context.watch<ConnectionManager>();
    final auth = context.watch<AuthController>();
    final profiles = cm.profiles;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xfff4f7fb),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
              child: Row(
                children: [
                  const Icon(Icons.hub_outlined, color: _seed),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'اتصال‌ها و سرورها',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => openProfileEditor(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('سرور جدید'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text(
                'برای هر شرکت یک سرور بسازید و آدرس‌های مختلف آن (شبکهٔ داخلی، '
                'اینترنت، VPN) را اضافه کنید. با قطع آدرس فعلی، اپ خودکار '
                'آدرس بعدی را امتحان می‌کند.',
                style: TextStyle(fontSize: 11.5, height: 1.7, color: _inkSoft),
              ),
            ),
            if (auth.busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: profiles.isEmpty
                  ? _Empty(onAdd: () => openProfileEditor(context))
                  : ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                      children: [
                        for (final p in profiles)
                          _ProfileCard(
                            profile: p,
                            active: p.id == cm.activeProfileId,
                            activeEndpointId: p.id == cm.activeProfileId
                                ? cm.activeEndpoint?.id
                                : null,
                            onSwitch: () => _switchTo(p),
                            onEdit: () =>
                                openProfileEditor(context, profile: p),
                            onDelete: () => _delete(p),
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

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dns_outlined, size: 48, color: Colors.blueGrey.shade300),
          const SizedBox(height: 10),
          const Text(
            'هنوز سروری تعریف نشده است.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('تعریف سرور'),
          ),
        ],
      ),
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.active,
    required this.activeEndpointId,
    required this.onSwitch,
    required this.onEdit,
    required this.onDelete,
  });

  final ConnectionProfile profile;
  final bool active;
  final String? activeEndpointId;
  final VoidCallback onSwitch, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final cm = context.watch<ConnectionManager>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? _seed.withValues(alpha: .55) : _line,
          width: active ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 0),
            leading: CircleAvatar(
              backgroundColor: active ? _seed : const Color(0xffe9efff),
              child: Icon(
                Icons.apartment_rounded,
                color: active ? Colors.white : _seed,
                size: 20,
              ),
            ),
            title: Text(
              profile.displayName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
            ),
            subtitle: Text(
              active
                  ? 'فعال • ${toFaDigits(profile.endpoints.length)} آدرس'
                  : '${toFaDigits(profile.endpoints.length)} آدرس',
              style: TextStyle(
                fontSize: 11.5,
                color: active ? _seed : _inkSoft,
                fontWeight: active ? FontWeight.w700 : null,
              ),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                PopupMenuItem(value: 'delete', child: Text('حذف')),
              ],
            ),
          ),
          if (active) ...[
            for (final e in profile.endpoints)
              _EndpointTile(
                endpoint: e,
                selected: e.id == activeEndpointId,
                index: profile.endpoints.indexOf(e),
                onTap: () {
                  HapticFeedback.selectionClick();
                  cm.selectEndpoint(e.id);
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      value: profile.autoSwitch,
                      onChanged: (v) {
                        final copy = profile.copy()..autoSwitch = v;
                        cm.upsertProfile(copy);
                      },
                      title: const Text(
                        'سوییچ خودکار با تغییر شبکه',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => cm.probeAll(profile),
                    icon: const Icon(Icons.network_check_rounded, size: 18),
                    label: const Text('تست'),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: OutlinedButton.icon(
                onPressed: profile.endpoints.isEmpty ? null : onSwitch,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('سوییچ به این سرور'),
              ),
            ),
        ],
      ),
    );
  }
}

class _EndpointTile extends StatelessWidget {
  const _EndpointTile({
    required this.endpoint,
    required this.selected,
    required this.index,
    required this.onTap,
  });

  final ServerEndpoint endpoint;
  final bool selected;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final probe = context.watch<ConnectionManager>().probeOf(endpoint.url);
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: selected ? _seed.withValues(alpha: .07) : const Color(0xfff8fafc),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _seed.withValues(alpha: .35) : _line,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? _seed : Colors.blueGrey.shade300,
            ),
            const SizedBox(width: 8),
            Icon(endpointIcon(endpoint.label), size: 18, color: _inkSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    endpoint.displayLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    endpoint.url,
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _inkSoft),
                  ),
                ],
              ),
            ),
            ProbeBadge(result: probe),
          ],
        ),
      ),
    );
  }
}

/// نشان وضعیت دسترسی یک آدرس
class ProbeBadge extends StatelessWidget {
  const ProbeBadge({super.key, required this.result});
  final ProbeResult result;

  @override
  Widget build(BuildContext context) {
    switch (result.state) {
      case ProbeState.checking:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ProbeState.ok:
        return _pill('${toFaDigits(result.ms ?? 0)} ms', _ok);
      case ProbeState.fail:
        return _pill('قطع', _danger);
      case ProbeState.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _pill(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

String toFaDigits(Object v) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  return v.toString().replaceAllMapped(
    RegExp(r'\d'),
    (m) => fa[int.parse(m.group(0)!)],
  );
}

IconData endpointIcon(String label) {
  final l = label.toLowerCase();
  if (l.contains('vpn')) return Icons.vpn_lock_outlined;
  if (l.contains('داخل') || l.contains('lan') || l.contains('wifi') ||
      l.contains('وای')) {
    return Icons.wifi_rounded;
  }
  if (l.contains('اینترنت') || l.contains('خارج') || l.contains('internet')) {
    return Icons.public_rounded;
  }
  return Icons.link_rounded;
}

// ============================================================
//  فرم تعریف / ویرایش سرور
// ============================================================

class ProfileEditorPage extends StatefulWidget {
  const ProfileEditorPage({super.key, this.profile});
  final ConnectionProfile? profile;

  @override
  State<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _EndpointDraft {
  _EndpointDraft(this.id, String label, String url)
    : label = TextEditingController(text: label),
      url = TextEditingController(text: url);
  final String id;
  final TextEditingController label, url;
  ProbeResult probe = const ProbeResult(ProbeState.unknown);

  void dispose() {
    label.dispose();
    url.dispose();
  }
}

class _ProfileEditorPageState extends State<ProfileEditorPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late bool _autoSwitch;
  final List<_EndpointDraft> _endpoints = [];

  bool get _isNew => widget.profile == null;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _autoSwitch = p?.autoSwitch ?? true;
    if (p != null && p.endpoints.isNotEmpty) {
      for (final e in p.endpoints) {
        _endpoints.add(_EndpointDraft(e.id, e.label, e.url));
      }
    } else {
      _endpoints
        ..add(_EndpointDraft(newConnectionId(), 'شبکهٔ داخلی', ''))
        ..add(_EndpointDraft(newConnectionId(), 'اینترنت', ''));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final e in _endpoints) {
      e.dispose();
    }
    super.dispose();
  }

  void _add() => setState(
    () => _endpoints.add(_EndpointDraft(newConnectionId(), '', '')),
  );

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _endpoints.length) return;
    setState(() {
      final e = _endpoints.removeAt(i);
      _endpoints.insert(j, e);
    });
  }

  Future<void> _test(_EndpointDraft d) async {
    if (validateServerUrl(d.url.text) != null) return;
    setState(() => d.probe = const ProbeResult(ProbeState.checking));
    final ms = await context.read<ConnectionManager>().probe(
      normalizeServerUrl(d.url.text),
    );
    if (!mounted) return;
    setState(
      () => d.probe = ms == null
          ? const ProbeResult(ProbeState.fail)
          : ProbeResult(ProbeState.ok, ms),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    // ردیف‌های کاملاً خالی نادیده گرفته می‌شوند
    final filled = _endpoints.where((e) => e.url.text.trim().isNotEmpty).toList();
    if (filled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداقل یک آدرس وارد کنید.')),
      );
      return;
    }
    if (!_form.currentState!.validate()) return;
    final cm = context.read<ConnectionManager>();
    final seen = <String>{};
    final endpoints = <ServerEndpoint>[];
    for (final d in filled) {
      final url = normalizeServerUrl(d.url.text);
      if (!seen.add(url)) continue;
      endpoints.add(
        ServerEndpoint(id: d.id, label: d.label.text.trim(), url: url),
      );
    }
    final profile = ConnectionProfile(
      id: widget.profile?.id ?? newConnectionId(),
      name: _name.text.trim(),
      autoSwitch: _autoSwitch,
      endpoints: endpoints,
    );
    await cm.upsertProfile(profile);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'سرور جدید' : 'ویرایش سرور'),
        actions: [
          TextButton(onPressed: _save, child: const Text('ذخیره')),
          const SizedBox(width: 6),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'نام سرور / شرکت',
                hintText: 'مثلاً: دفتر مرکزی',
                prefixIcon: Icon(Icons.apartment_rounded),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'یک نام وارد کنید.' : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoSwitch,
              onChanged: (v) => setState(() => _autoSwitch = v),
              title: const Text('سوییچ خودکار بین آدرس‌ها'),
              subtitle: const Text(
                'اگر آدرس فعلی در دسترس نبود (مثلاً از وای‌فای شرکت خارج شدید)، '
                'آدرس بعدی به ترتیب اولویت امتحان می‌شود.',
                style: TextStyle(fontSize: 11.5, height: 1.6),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'آدرس‌ها',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(width: 6),
                Text(
                  '(بالاتر = اولویت بیشتر)',
                  style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _endpoints.length; i++) _endpointCard(i),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('افزودن آدرس'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('ذخیرهٔ سرور'),
          ),
        ),
      ),
    );
  }

  Widget _endpointCard(int i) {
    final d = _endpoints[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: const Color(0xffe9efff),
                      child: Text(
                        toFaDigits(i + 1),
                        style: const TextStyle(
                          fontSize: 11,
                          color: _seed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: [
                          for (final s in const ['شبکهٔ داخلی', 'اینترنت', 'VPN'])
                            ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(s, style: const TextStyle(fontSize: 11)),
                              selected: d.label.text == s,
                              onSelected: (_) => setState(() => d.label.text = s),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: d.label,
                  decoration: const InputDecoration(
                    labelText: 'عنوان (اختیاری)',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: d.url,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'آدرس سرور',
                    hintText: i == 0
                        ? 'http://192.168.1.10:5100'
                        : 'https://office.example.com',
                    isDense: true,
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(10),
                      child: ProbeBadge(result: d.probe),
                    ),
                    suffixIconConstraints: const BoxConstraints(minWidth: 0),
                  ),
                  onChanged: (_) {
                    if (d.probe.state != ProbeState.unknown) {
                      setState(
                        () => d.probe = const ProbeResult(ProbeState.unknown),
                      );
                    }
                  },
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? null : validateServerUrl(v),
                ),
                // نسخهٔ وب روی https: مرورگر اتصال به آدرس http را مسدود می‌کند
                if (kIsWeb &&
                    Uri.base.scheme == 'https' &&
                    normalizeServerUrl(d.url.text).startsWith('http://'))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'در نسخهٔ وب، مرورگر به آدرس http (بدون s) از صفحهٔ https '
                      'وصل نمی‌شود؛ از آدرس https استفاده کنید.',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _test(d),
                    icon: const Icon(Icons.network_check_rounded, size: 18),
                    label: const Text('تست اتصال'),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                tooltip: 'اولویت بالاتر',
                visualDensity: VisualDensity.compact,
                onPressed: i == 0 ? null : () => _move(i, -1),
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: 'اولویت پایین‌تر',
                visualDensity: VisualDensity.compact,
                onPressed: i == _endpoints.length - 1 ? null : () => _move(i, 1),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              IconButton(
                tooltip: 'حذف',
                visualDensity: VisualDensity.compact,
                onPressed: _endpoints.length == 1
                    ? null
                    : () => setState(() => _endpoints.removeAt(i).dispose()),
                icon: const Icon(Icons.delete_outline_rounded, color: _danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
