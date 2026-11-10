// ============================================================
//  تنظیمات اتصال پیام‌رسان
//  مدیر/کاربر می‌تواند مسیر واقعی چت سرور را وارد کند و وضعیت را ببیند.
// ============================================================

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../data/chat_endpoints.dart';
import '../data/chat_repository.dart';
import '../data/chat_source_probe.dart';
import 'messenger_style.dart';

class ChatSettingsSheet extends StatefulWidget {
  const ChatSettingsSheet({super.key, required this.repo});

  final ChatRepository repo;

  @override
  State<ChatSettingsSheet> createState() => _ChatSettingsSheetState();
}

class _ChatSettingsSheetState extends State<ChatSettingsSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.repo.resolvedBase ?? ChatEndpoints.erpBase,
  );
  final _hub = TextEditingController(text: ChatEndpoints.erpHub);
  final _server = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _ok = false;
  List<ProbeResult> _probes = const [];
  List<SourceProbe> _sources = const [];

  @override
  void initState() {
    super.initState();
    widget.repo.endpoints.savedHubPath().then((v) {
      if (mounted && v != null) _hub.text = v;
    });
    widget.repo.endpoints.savedServer().then((v) {
      // پیش‌فرض = همان سرور اصلی اپ (اتوماسیون) که ChatController روی آن است
      if (mounted) {
        setState(() {
          _server.text = v == ChatEndpoints.defaultServer
              ? widget.repo.api.baseUrl
              : v;
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _hub.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    await widget.repo.endpoints.saveServer(_server.text);
    final base = ChatEndpoints.normalizeBase(_ctrl.text, '');
    if (base.isEmpty) {
      setState(() {
        _busy = false;
        _ok = false;
        _msg = 'مسیر را وارد کنید. مثل: /api/chatmessage';
      });
      return;
    }
    await widget.repo.setChatBase(base);
    await widget.repo.endpoints.discover(force: true);
    if (_hub.text.trim().isNotEmpty) {
      await widget.repo.endpoints.saveHubPath(
        ChatEndpoints.normalizeBase(_hub.text, ''),
      );
    }
    // بررسی واقعی: آیا این مسیر «دادهٔ چت» می‌دهد یا فقط صفحهٔ وب است؟
    final probe = await ChatSourceProbe(
      widget.repo.api,
    ).probeUrl(widget.repo.api.resolveUrl(base));
    if (!mounted) return;
    final path = widget.repo.api.resolveUrl(base);
    setState(() {
      _busy = false;
      _sources = [probe];
      _ok = probe.usable;
      if (probe.usable) {
        _msg = 'اتصال برقرار شد ✅  ${probe.count} رکورد از $path خوانده شد.';
      } else if (probe.kind == SourceKind.html) {
        _msg = 'این آدرس باز است ولی صفحهٔ وب (HTML) برمی‌گرداند، نه دادهٔ چت. '
            'مسیر API چت را وارد کنید (مثلاً /chat/api/chatmessage) یا '
            '«شناسایی خودکار» را بزنید.';
      } else {
        _msg = 'این مسیر دادهٔ چت نداد (${probe.status ?? "بدون پاسخ"}). '
            'مسیر دیگری را امتحان کنید.';
      }
    });
  }

  Future<void> _autoDetect() async {
    setState(() {
      _busy = true;
      _msg = null;
      _probes = const [];
    });
    final found = await widget.repo.endpoints.discover(force: true);
    final probes = List<ProbeResult>.from(widget.repo.endpoints.probes);
    final sources = List<SourceProbe>.from(widget.repo.endpoints.lastSources);
    if (!mounted) return;
    final realData = sources.where((s) => s.usable).toList();
    setState(() {
      _busy = false;
      _probes = probes;
      _sources = sources;
      _ok = realData.isNotEmpty;
      if (realData.isNotEmpty) {
        _ctrl.text = realData.first.url;
        _msg = 'مسیر دادهٔ چت پیدا شد:\n${realData.first.url}\n'
            '(${realData.first.count} رکورد) — از این به بعد از همین خوانده می‌شود.';
      } else if (sources.any((s) => s.kind == SourceKind.html)) {
        _msg = 'این سرور بالاست، ولی مسیرهای امتحان‌شده صفحهٔ وب (HTML) '
            'برگرداندند، نه دادهٔ چت. یعنی آدرس API چت چیز دیگری است.\n'
            'گزارش بالا را بفرستید (دکمهٔ «کپی گزارش») تا مسیر دقیق را '
            'اضافه کنم.';
      } else {
        _msg = 'هیچ دادهٔ چتی روی این سرور پیدا نشد. گزارش را کپی و بفرستید.';
      }
    });
  }

  /// کپی کل گزارش (برای ارسال به پشتیبانی) — شامل نوع واقعی پاسخ هر مسیر
  Future<void> _copyReport() async {
    final b = StringBuffer()
      ..writeln('گزارش اتصال پیام‌رسان')
      ..writeln('سرور: ${_server.text.trim()}')
      ..writeln('نسخهٔ اپ: 1.29.0')
      ..writeln('--- منابع داده ---');
    for (final s in _sources) {
      b.writeln('${s.label}${s.note != null ? " | ${s.note}" : ""}');
      if (s.sample.isNotEmpty) b.writeln('    نمونه: ${s.sample}');
    }
    if (_sources.isEmpty) {
      for (final p in _probes) {
        b.writeln(p.label);
      }
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('گزارش کپی شد — می‌توانید در چت بفرستید.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: const BoxDecoration(
        color: MessengerColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: MessengerColors.line,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'تنظیمات اتصال پیام‌رسان',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: MessengerColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'چت سازمانی روی مسیر api/chat سرو می‌شود (کنترلر Chat و '
            'Hub روی /hubs/chat). اگر سرور چت جدا از اتوماسیون است، '
            'آدرس سرور را عوض کنید.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.9,
              color: MessengerColors.inkSoft,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('auto-detect-chat'),
              onPressed: _busy ? null : _autoDetect,
              icon: _busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.travel_explore_rounded, size: 18),
              label: const Text('شناسایی خودکار مسیر چت'),
              style: FilledButton.styleFrom(
                backgroundColor: MessengerColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _server,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'آدرس سرور پیام‌رسان',
              hintText: 'https://server:port',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'مسیر API چت',
              hintText: '/api/chat',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hub,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'مسیر Hub (SignalR)',
              hintText: '/hubs/chat',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final p in const [
                '/api/chat',
                '/chat/api/chat',
                '/api/chatmessage',
                '/api/messages',
              ])
                ActionChip(
                  label: Text(p, style: const TextStyle(fontSize: 10.5)),
                  onPressed: () => setState(() => _ctrl.text = p),
                ),
            ],
          ),
          if (_probes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MessengerColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MessengerColors.line),
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (_sources.isEmpty)
                    const Text(
                      'گزارش شناسایی (روی همین سرور):',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: MessengerColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final p in _sources)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.label,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 10,
                              color: p.usable
                                  ? const Color(0xff15803d)
                                  : MessengerColors.inkFaint,
                            ),
                          ),
                          if ((p.note ?? '').isNotEmpty)
                            Text(
                              p.note!,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: MessengerColors.inkFaint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_sources.isEmpty)
                    for (final p in _probes.take(30))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          p.label,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 10,
                            color: p.ok
                                ? const Color(0xff15803d)
                                : MessengerColors.inkFaint,
                          ),
                        ),
                      ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _copyReport,
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text(
                        'کپی گزارش',
                        style: TextStyle(fontSize: 10.5),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_ok ? Colors.green : MessengerColors.danger)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _msg!,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.8,
                  color: _ok ? const Color(0xff15803d) : MessengerColors.danger,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _test,
              icon: _busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.wifi_tethering_rounded, size: 18),
              label: const Text('ذخیره و آزمایش اتصال'),
              style: FilledButton.styleFrom(
                backgroundColor: MessengerColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
      ),
    ),
  );
}
