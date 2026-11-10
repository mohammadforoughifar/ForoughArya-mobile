// ============================================================
//  صفحهٔ گفت‌وگو — ارسال متن و «پیام صوتی»
//
//  تجربهٔ کاربری الگوگرفته از واتس‌اپ/تلگرام:
//    • دکمهٔ میکروفن سمت چپ کادر متن؛ نگه‌داشتن = ضبط، رهاشدن = ارسال
//    • کشیدن به چپ = لغو ضبط
//    • نوار ضبط شناور با زمان‌شمار و موج صوتی متحرک
//    • حباب ویس با دکمهٔ پخش، نوار پیشرفت و زمان
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/chat_repository.dart';
import '../data/voice_recorder.dart';
import '../models/chat_models.dart';
import 'messenger_style.dart';
import 'voice_bubble.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.thread});

  final ChatThread thread;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatRepository _repo = ChatRepository(context.read<ApiClient>());
  final _text = TextEditingController();
  final _scroll = ScrollController();

  List<ChatMessage> _items = const [];
  bool _loading = true;
  String? _error;
  bool _sending = false;

  // --- وضعیت ضبط ویس ---
  bool _recording = false;
  bool _cancelled = false;
  int _seconds = 0;
  double _dragX = 0;
  Timer? _ticker;
  File? _pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = context.read<AuthController>().session?.userId;
      final list = await _repo.messages(
        widget.thread.id,
        myUserId: me,
        peerName: widget.thread.title,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
      _toBottom();
      // علامت «خوانده شد» روی سرور (برای شمارندهٔ گفت‌وگو)
      if (list.isNotEmpty) {
        unawaited(_repo.markRead(widget.thread.id, lastReadMessageId: list.last.id));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  // ---------------- متن ----------------

  Future<void> _sendText() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _items = [
        ..._items,
        ChatMessage(
          id: -DateTime.now().millisecondsSinceEpoch,
          kind: ChatKind.text,
          text: t,
          mine: true,
          at: DateTime.now(),
          status: ChatStatus.sending,
        ),
      ];
    });
    _text.clear();
    _toBottom();
    try {
      await _repo.sendText(widget.thread.id, t, to: widget.thread.title);
      if (!mounted) return;
      setState(() => _sending = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _items = _items
            .map(
              (m) => m.mine && m.status == ChatStatus.sending
                  ? m.copyWith(status: ChatStatus.failed)
                  : m,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ارسال نشد: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------- ویس ----------------

  /// پیام راهنما وقتی اجازهٔ میکروفن نیست — با دکمهٔ رفتن به تنظیمات
  void _micDeniedHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: const Text(
          'اجازهٔ میکروفن داده نشده. برای ضبط صدا اجازه بدهید.',
        ),
        action: SnackBarAction(
          label: 'تنظیمات',
          onPressed: () => VoiceRecorder.openSettings(),
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    HapticFeedback.mediumImpact();

    // ۱) اجازه: اگر از قبل داده شده، پنجره باز نمی‌شود
    var ok = await VoiceRecorder.hasPermission();
    if (!ok) ok = await VoiceRecorder.requestPermission();
    if (!ok) {
      _micDeniedHint();
      return;
    }

    // ۲) شروع ضبط (خطای بومی با پیام فارسی برمی‌گردد)
    final f = await VoiceRecorder.start();
    if (f == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            VoiceRecorder.lastError ?? 'ضبط صدا آغاز نشد.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _pending = f;
      _recording = true;
      _cancelled = false;
      _seconds = 0;
      _dragX = 0;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= 120) _finishRecording(send: true); // سقف ۲ دقیقه
    });
  }

  Future<void> _finishRecording({required bool send}) async {
    if (!_recording) return;
    _ticker?.cancel();
    final secs = _seconds < 1 ? 1 : _seconds;
    setState(() => _recording = false);
    if (!send || _cancelled) {
      await VoiceRecorder.cancel();
      setState(() {
        _pending = null;
        _seconds = 0;
      });
      return;
    }
    final file = await VoiceRecorder.stop();
    final target = file ?? _pending;
    if (target == null) {
      setState(() => _seconds = 0);
      return;
    }
    HapticFeedback.lightImpact();
    final temp = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch,
      kind: ChatKind.voice,
      mine: true,
      at: DateTime.now(),
      durationSec: secs,
      localPath: target.path,
      status: ChatStatus.sending,
    );
    setState(() {
      _items = [..._items, temp];
      _seconds = 0;
      _pending = null;
    });
    _toBottom();
    try {
      await _repo.sendVoice(
        widget.thread.id,
        target,
        durationSec: secs,
        to: widget.thread.title,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (m) => m.id == temp.id
                  ? m.copyWith(status: ChatStatus.failed)
                  : m,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ویس ارسال نشد: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    return Scaffold(
      backgroundColor: MessengerColors.bg,
      appBar: AppBar(
        backgroundColor: MessengerColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        titleSpacing: 0,
        title: Row(
          children: [
            Avatar(text: t.initials, size: 38, color: t.avatarColor),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: MessengerColors.ink,
                    ),
                  ),
                  Text(
                    t.online ? 'آنلاین' : 'پیام‌رسان سازمانی',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: t.online
                          ? const Color(0xff15803d)
                          : MessengerColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(
              Icons.refresh_rounded,
              color: MessengerColors.inkSoft,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          if (_recording)
            _RecordingBar(
              seconds: _seconds,
              dragX: _dragX,
              willCancel: _dragX < -80,
            ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 34,
                color: MessengerColors.inkFaint,
              ),
              const SizedBox(height: 10),
              Text(
                'پیام‌ها دریافت نشد\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.9,
                  color: MessengerColors.inkSoft,
                ),
              ),
              TextButton(onPressed: _load, child: const Text('تلاش دوباره')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'اولین پیام را بفرستید 👋',
          style: TextStyle(fontSize: 12.5, color: MessengerColors.inkSoft),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final m = _items[i];
        final next = i + 1 < _items.length ? _items[i + 1] : null;
        final sameNext = next != null && next.mine == m.mine;
        return _Bubble(message: m, tail: !sameNext);
      },
    );
  }

  // ---------------- پیوست ----------------

  /// انتخاب نوع پیوست و ارسال
  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: MessengerColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AttachTile(
              icon: Icons.insert_drive_file_rounded,
              label: 'فایل (PDF، Word، Excel و…)',
              onTap: () => Navigator.pop(c, 'file'),
            ),
            _AttachTile(
              icon: Icons.photo_library_rounded,
              label: 'تصویر از گالری',
              onTap: () => Navigator.pop(c, 'image'),
            ),
            _AttachTile(
              icon: Icons.photo_camera_rounded,
              label: 'عکس با دوربین',
              onTap: () => Navigator.pop(c, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    File? file;
    try {
      if (choice == 'file') {
        final picked = await FilePicker.pickFiles();
        final path = picked.isEmpty ? null : picked.first.path;
        if (path != null) file = File(path);
      } else {
        final picker = ImagePicker();
        final x = await picker.pickImage(
          source: choice == 'camera'
              ? ImageSource.camera
              : ImageSource.gallery,
          imageQuality: 88,
          maxWidth: 2200,
        );
        if (x != null) file = File(x.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('انتخاب فایل انجام نشد: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (file == null || !mounted) return;

    // نمایش فوری در فهرست (در حال ارسال)
    final size = await file.length();
    if (size > 50 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حجم فایل بیشتر از ۵۰ مگابایت است.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final temp = ChatMessage(
      id: -DateTime.now().millisecondsSinceEpoch,
      kind: choice == 'file' ? ChatKind.file : ChatKind.image,
      mine: true,
      at: DateTime.now(),
      attachmentName: file.uri.pathSegments.last,
      localPath: file.path,
      status: ChatStatus.sending,
    );
    setState(() => _items = [..._items, temp]);
    _toBottom();

    try {
      await _repo.sendFile(widget.thread.id, file);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (m) =>
                  m.id == temp.id ? m.copyWith(status: ChatStatus.failed) : m,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فایل ارسال نشد: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: const BoxDecoration(
        color: MessengerColors.surface,
        border: Border(top: BorderSide(color: MessengerColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // پیوست: فایل / گالری / دوربین
            GestureDetector(
              onTap: _pickAttachment,
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsetsDirectional.only(end: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MessengerColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MessengerColors.line),
                ),
                child: const Icon(
                  Icons.attach_file_rounded,
                  size: 20,
                  color: MessengerColors.inkSoft,
                ),
              ),
            ),
            // میکروفن: نگه‌داشتن = ضبط
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressMoveUpdate: (d) {
                setState(() => _dragX = d.localOffsetFromOrigin.dx);
                if (_dragX < -80 && !_cancelled) {
                  setState(() => _cancelled = true);
                } else if (_dragX >= -80 && _cancelled) {
                  setState(() => _cancelled = false);
                }
              },
              onLongPressEnd: (_) {
                final cancel = _cancelled;
                setState(() {
                  _dragX = 0;
                  _cancelled = false;
                });
                _finishRecording(send: !cancel);
              },
              // یک ضربه = شروع/پایان ضبط (برای گوشی‌هایی که نگه‌داشتن
              // در آن‌ها با اسکرول/ژست سیستم قاطی می‌شود)
              onTap: () async {
                if (_recording) {
                  await _finishRecording(send: !_cancelled);
                } else {
                  await _startRecording();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                margin: const EdgeInsetsDirectional.only(end: 4),
                decoration: BoxDecoration(
                  gradient: _recording
                      ? const LinearGradient(
                          colors: [
                            MessengerColors.record,
                            Color(0xffb91c3c),
                          ],
                        )
                      : MessengerColors.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (_recording
                              ? MessengerColors.record
                              : MessengerColors.brand)
                          .withValues(alpha: 0.32),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MessengerColors.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendText(),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: MessengerColors.ink,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'پیام…',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: MessengerColors.inkFaint,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _sendText,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: MessengerColors.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حباب پیام (متن/ویس/سیستمی)
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.tail = true});

  final ChatMessage message;
  final bool tail;

  @override
  Widget build(BuildContext context) {
    if (message.kind == ChatKind.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: MessengerColors.ink.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              message.text ?? '',
              style: const TextStyle(
                fontSize: 10.5,
                color: MessengerColors.inkSoft,
              ),
            ),
          ),
        ),
      );
    }
    final mine = message.mine;
    final time = message.at == null
        ? ''
        : Fa.date(message.at!.toIso8601String());
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: EdgeInsets.only(top: 3, bottom: tail ? 6 : 2),
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 7),
        decoration: BoxDecoration(
          color: mine ? MessengerColors.bubbleMine : MessengerColors.bubbleOther,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(16),
            topEnd: const Radius.circular(16),
            bottomStart: Radius.circular(mine ? 16 : (tail ? 4 : 16)),
            bottomEnd: Radius.circular(mine ? (tail ? 4 : 16) : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: MessengerColors.ink.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && (message.senderName ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.senderName!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: MessengerColors.brandDeep,
                  ),
                ),
              ),
            if (message.kind == ChatKind.voice)
              VoiceBubble(message: message)
            else if (message.kind == ChatKind.image)
              _ImageAttachment(message: message)
            else if (message.kind == ChatKind.file)
              _FileAttachment(message: message)
            else
              Text(
                message.text ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.75,
                  color: MessengerColors.ink,
                ),
              ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 9,
                    color: MessengerColors.inkFaint,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == ChatStatus.failed
                        ? Icons.error_outline_rounded
                        : message.status == ChatStatus.sending
                        ? Icons.schedule_rounded
                        : Icons.done_all_rounded,
                    size: 12,
                    color: message.status == ChatStatus.failed
                        ? MessengerColors.danger
                        : MessengerColors.inkFaint,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// نوار شناور هنگام ضبط
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.seconds,
    required this.dragX,
    required this.willCancel,
  });

  final int seconds;
  final double dragX;
  final bool willCancel;

  @override
  Widget build(BuildContext context) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: willCancel
            ? MessengerColors.danger.withValues(alpha: 0.10)
            : MessengerColors.record.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: willCancel
              ? MessengerColors.danger.withValues(alpha: 0.4)
              : MessengerColors.record.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          _PulseDot(color: willCancel ? MessengerColors.danger : MessengerColors.record),
          const SizedBox(width: 9),
          Text(
            '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: willCancel ? MessengerColors.danger : MessengerColors.ink,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'برای ارسال رها کنید · برای لغو به چپ بکشید',
              style: TextStyle(fontSize: 10.5, color: MessengerColors.inkSoft),
            ),
          ),
          Icon(
            willCancel ? Icons.delete_outline_rounded : Icons.mic_rounded,
            size: 18,
            color: willCancel ? MessengerColors.danger : MessengerColors.record,
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}

/// ردیف انتخاب نوع پیوست در شیت پایین
class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MessengerColors.brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: MessengerColors.brand),
    ),
    title: Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: MessengerColors.ink,
      ),
    ),
  );
}

/// تصویر پیام: پیش‌نمایش + باز شدن تمام‌صفحه
class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final url = message.fileUrl ?? message.localPath;
    if (url == null) return const SizedBox.shrink();
    final image = url.startsWith('http')
        ? Image.network(
            url,
            width: 210,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _broken('تصویر دریافت نشد'),
          )
        : Image.file(
            File(url),
            width: 210,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _broken('تصویر باز نشد'),
          );
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(8),
          child: InteractiveViewer(
            child: url.startsWith('http')
                ? Image.network(url, fit: BoxFit.contain)
                : Image.file(File(url), fit: BoxFit.contain),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: image,
      ),
    );
  }

  Widget _broken(String text) => Container(
    padding: const EdgeInsets.all(12),
    color: MessengerColors.bg,
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, color: MessengerColors.inkFaint),
    ),
  );
}

/// فایل پیام: نام + حجم + دانلود/باز کردن
class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.message});
  final ChatMessage message;

  String _sizeLabel() {
    // اگر سرور حجم داده باشد در متن نیست؛ همان نام کافی است
    return message.attachmentName ?? 'فایل';
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MessengerColors.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.description_rounded,
          size: 19,
          color: MessengerColors.brand,
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sizeLabel(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MessengerColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.fileUrl == null ? 'در حال ارسال…' : 'برای باز کردن بزنید',
              style: const TextStyle(
                fontSize: 9.5,
                color: MessengerColors.inkFaint,
              ),
            ),
          ],
        ),
      ),
      if (message.fileUrl != null)
        IconButton(
          onPressed: () async {
            final url = message.fileUrl!;
            try {
              final dir = await getTemporaryDirectory();
              final name = message.attachmentName ?? 'file';
              final target = File('${dir.path}/$name');
              final api = context.read<ApiClient>();
              final res = await api.dio.get<List<int>>(
                url,
                options: Options(responseType: ResponseType.bytes),
              );
              await target.writeAsBytes(res.data ?? const []);
              await OpenFilex.open(target.path);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('باز کردن فایل ممکن نشد: $e'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          icon: const Icon(
            Icons.download_rounded,
            size: 19,
            color: MessengerColors.brand,
          ),
        ),
    ],
  );
}
