// ============================================================
//  تنظیمات اتصال پیام‌رسان
//  مدیر/کاربر می‌تواند مسیر واقعی چت سرور را وارد کند و وضعیت را ببیند.
// ============================================================

import 'package:flutter/material.dart';

import '../data/chat_endpoints.dart';
import '../data/chat_repository.dart';
import 'messenger_style.dart';

class ChatSettingsSheet extends StatefulWidget {
  const ChatSettingsSheet({super.key, required this.repo});

  final ChatRepository repo;

  @override
  State<ChatSettingsSheet> createState() => _ChatSettingsSheetState();
}

class _ChatSettingsSheetState extends State<ChatSettingsSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.repo.resolvedBase ?? '');
  final _hub = TextEditingController();
  final _server = TextEditingController(text: ChatEndpoints.defaultServer);
  bool _busy = false;
  String? _msg;
  bool _ok = false;
  List<ProbeResult> _probes = const [];

  @override
  void initState() {
    super.initState();
    widget.repo.endpoints.savedHubPath().then((v) {
      if (mounted && v != null) _hub.text = v;
    });
    widget.repo.endpoints.savedServer().then((v) {
      if (mounted) setState(() => _server.text = v);
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
    final alive = await widget.repo.ping();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = alive;
      _msg = alive
          ? 'اتصال برقرار شد ✅  درخواست به $base جواب داد.'
          : 'این مسیر جواب نداد. مسیر دیگری را امتحان کنید '
                '(مثلاً /api/chat یا /api/messages).';
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
    if (!mounted) return;
    setState(() {
      _busy = false;
      _probes = probes;
      _ok = found != null;
      if (found != null) {
        _ctrl.text = found.base;
        _msg = 'مسیر پیدا شد: ${found.probePath ?? found.base}\n'
            'از این به بعد پیام‌رسان از همین مسیر داده می‌خواند.';
      } else {
        _msg = 'هیچ مسیر چتی روی این سرور پیدا نشد. گزارش بالا را بفرستید '
            'تا مسیر دقیق اضافه شود، یا مسیر را دستی وارد کنید.';
      }
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: const BoxDecoration(
        color: MessengerColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
            'مسیر API چتِ همان پیام‌رسان وب را وارد کنید. اگر نمی‌دانید، '
            'در مرورگر یکی از پیام‌ها را باز کنید و آدرس درخواست را از '
            'DevTools (تب Network) بردارید.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.9,
              color: MessengerColors.inkSoft,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _server,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'آدرس سرور پیام‌رسان',
              hintText: 'https://94.183.59.57:4457',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'مسیر API چت',
              hintText: '/api/chatmessage',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hub,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'مسیر Hub (اختیاری — SignalR)',
              hintText: '/chatHub',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final p in ChatEndpoints.apiCandidates.take(6))
                ActionChip(
                  label: Text(p, style: const TextStyle(fontSize: 10.5)),
                  onPressed: () => setState(() => _ctrl.text = p),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _autoDetect,
              icon: const Icon(Icons.travel_explore_rounded, size: 18),
              label: const Text('شناسایی خودکار مسیر چت'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MessengerColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: MessengerColors.brand.withValues(alpha: 0.4),
                ),
              ),
            ),
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
                  const Text(
                    'گزارش شناسایی (روی همین سرور):',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: MessengerColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
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
  );
}
