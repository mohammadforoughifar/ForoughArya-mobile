// ============================================================
//  پیام‌رسان سازمانی — فهرست گفت‌وگوها
//  طراحی الگوگرفته از تلگرام/واتس‌اپ: ردیف‌های تمیز، آواتار حرفی،
//  نشان نخوانده، زمان شمسی و نوار جست‌وجوی چسبیده به بالا.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/chat_repository.dart';
import '../models/chat_models.dart';
import 'chat_page.dart';
import 'messenger_style.dart';

class MessengerPage extends StatefulWidget {
  const MessengerPage({super.key});

  @override
  State<MessengerPage> createState() => _MessengerPageState();
}

class _MessengerPageState extends State<MessengerPage> {
  late final ChatRepository _repo = ChatRepository(context.read<ApiClient>());
  List<ChatThread>? _threads;
  String? _error;
  String _q = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await _repo.threads();
      if (!mounted) return;
      setState(() {
        _threads = t;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _threads = const [];
        _error = e.toString();
      });
    }
  }

  Future<void> _open(ChatThread t) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatPage(thread: t)),
    );
    _load();
  }

  List<ChatThread> get _filtered {
    final all = _threads ?? const <ChatThread>[];
    if (_q.trim().isEmpty) return all;
    final q = _q.trim();
    return all
        .where(
          (t) =>
              t.title.contains(q) ||
              (t.lastMessage ?? '').contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MessengerColors.bg,
      appBar: AppBar(
        backgroundColor: MessengerColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: MessengerColors.brandGradient,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.forum_rounded,
                size: 19,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 9),
            const Text(
              'پیام‌رسان',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MessengerColors.ink,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'گفت‌وگوی تازه',
            onPressed: () => _newChat(),
            icon: const Icon(
              Icons.edit_square,
              color: MessengerColors.brand,
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _q = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'جست‌وجوی گفت‌وگو…',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: MessengerColors.inkFaint,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: MessengerColors.inkFaint,
                ),
                filled: true,
                fillColor: MessengerColors.bg,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (_threads == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return _Empty(
              icon: Icons.cloud_off_rounded,
              title: 'گفت‌وگوها دریافت نشد',
              text: '$_error\n\nسرور: ${context.read<ApiClient>().baseUrl}\n'
                  'اگر صندوق ایمیل سازمانی خالی است، ابتدا در ماژول ایمیل '
                  'حساب سازمانی را تنظیم کنید.',
              action: TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('تلاش دوباره'),
              ),
            );
          }
          final items = _filtered;
          if (items.isEmpty) {
            return _Empty(
              icon: Icons.forum_outlined,
              title: 'گفت‌وگویی نیست',
              text: 'صندوق ایمیل سازمانی خالی است. با دکمهٔ پایین یک گفت‌وگوی '
                  'تازه با همکاران شروع کنید (پیام‌ها از ایمیل سازمانی '
                  'خوانده و ارسال می‌شوند).',
              action: TextButton.icon(
                onPressed: () => _newChat(),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('گفت‌وگوی تازه'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 90),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, i) => _ThreadRow(
                thread: items[i],
                onTap: () => _open(items[i]),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newChat(),
        backgroundColor: MessengerColors.brand,
        foregroundColor: Colors.white,
        child: const Icon(Icons.chat_bubble_outline_rounded),
      ),
    );
  }

  Future<void> _newChat() async {
    List<ChatThread> contacts;
    try {
      contacts = await _repo.contacts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فهرست همکاران نیامد: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<ChatThread>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _ContactSheet(contacts: contacts),
    );
    if (picked == null) return;
    try {
      final id = await _repo.startThread(picked.userId ?? picked.id);
      if (!mounted) return;
      final thread = ChatThread(
        id: id > 0 ? id : picked.id,
        title: picked.title,
        userId: picked.userId,
      );
      await _open(thread);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('گفت‌وگو باز نشد: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread, required this.onTap});

  final ChatThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = thread.lastAt == null
        ? ''
        : Fa.date(thread.lastAt!.toIso8601String(), time: false);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: thread.unread > 0
                ? MessengerColors.unreadTint
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Avatar(
                text: thread.initials,
                color: thread.avatarColor,
                size: 48,
                online: thread.online,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (thread.isGroup) ...[
                          const Icon(
                            Icons.groups_rounded,
                            size: 14,
                            color: MessengerColors.inkSoft,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            thread.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: thread.unread > 0
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: MessengerColors.ink,
                            ),
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: thread.unread > 0
                                  ? MessengerColors.brand
                                  : MessengerColors.inkFaint,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.lastMessage ?? 'بدون پیام',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: MessengerColors.inkSoft,
                            ),
                          ),
                        ),
                        if (thread.unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: MessengerColors.brandGradient,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              Fa.digits(thread.unread),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _ContactSheet extends StatelessWidget {
  const _ContactSheet({required this.contacts});

  final List<ChatThread> contacts;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: MessengerColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: MessengerColors.line,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'گفت‌وگوی تازه',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: MessengerColors.ink,
                ),
              ),
            ),
          ),
          Flexible(
            child: contacts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'همکاری برای شروع گفت‌وگو پیدا نشد.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: MessengerColors.inkSoft,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: contacts.length,
                    itemBuilder: (context, i) {
                      final c = contacts[i];
                      return ListTile(
                        leading: Avatar(text: c.initials, size: 38),
                        title: Text(
                          c.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MessengerColors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 30, color: MessengerColors.brand),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: MessengerColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.9,
              color: MessengerColors.inkSoft,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 6), action!],
        ],
      ),
    ),
  );
}
