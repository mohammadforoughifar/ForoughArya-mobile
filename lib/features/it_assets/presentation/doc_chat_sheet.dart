// ============================================================
//  «گفتگو با سند» — آینهٔ `Pages/DocArchive/DocChatModal.razor`
//  POST api/doc-archive/documents/{id}/chat
//  body: {question, history:[{role,text}]}
//  response: {answer, mode: ai|retrieval|notext, hasText, sources[]}
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'system_style.dart';

class DocChatSheet extends StatefulWidget {
  const DocChatSheet({
    super.key,
    required this.documentId,
    this.documentTitle = '',
    this.suggestions = const [],
  });

  final int documentId;
  final String documentTitle;

  /// پرسش‌های آمادهٔ وب (چیپ‌ها)
  final List<String> suggestions;

  @override
  State<DocChatSheet> createState() => _DocChatSheetState();
}

class _DocChatSheetState extends State<DocChatSheet> {
  static const List<String> _defaultSuggestions = [
    'این سند دربارهٔ چیست؟',
    'تاریخ و طرفین قرارداد را بگو.',
    'مبالغ و مهلت‌ها چیست؟',
    'چه ریسک‌هایی در این سند می‌بینی؟',
  ];

  late final DocArchiveRepository _repo;
  final _q = TextEditingController();
  final _scroll = ScrollController();

  final List<DocChatTurn> _turns = [];
  DocChatAnswer? _last;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<String> get _chips =>
      widget.suggestions.isEmpty ? _defaultSuggestions : widget.suggestions;

  Future<void> _ask([String? preset]) async {
    final question = (preset ?? _q.text).trim();
    final err = validateDocChatQuestion(question);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _turns.add(DocChatTurn(role: 'user', text: question));
      _q.clear();
    });
    _jump();
    try {
      final res = await _repo.chatWithDocument(
        widget.documentId,
        DocChatRequest(
          question: question,
          history: _turns.length > 1
              ? _turns.sublist(0, _turns.length - 1)
              : const [],
        ),
      );
      if (!mounted) return;
      setState(() {
        _last = res;
        _turns.add(
          DocChatTurn(
            role: 'assistant',
            text: res.answer.trim().isEmpty ? res.modeHint : res.answer,
          ),
        );
        _busy = false;
      });
      _jump();
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

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.86,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.smart_toy_rounded,
                  size: 17,
                  color: ShopColors.seed,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'گفتگو با سند',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (widget.documentTitle.isNotEmpty)
                        Text(
                          widget.documentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_last != null)
                  ShopTag(
                    text: _last!.modeLabel,
                    color: switch (_last!.mode) {
                      'ai' => ShopColors.seed,
                      'notext' => ShopColors.danger,
                      _ => ShopColors.ok,
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              children: [
                if (_turns.isEmpty)
                  SystemNote(
                    text:
                        'پرسش شما فقط از متن همین سند پاسخ داده می‌شود؛ پاسخ بیرون از سند ساخته نمی‌شود.',
                    color: ShopColors.seed,
                    icon: Icons.info_outline_rounded,
                  ),
                for (final t in _turns) _bubble(t),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  SystemNote(
                    text: _error!,
                    color: ShopColors.danger,
                    icon: Icons.error_outline_rounded,
                  ),
                ],
                if (_last != null && _last!.sources.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'منابع پاسخ',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final s in _last!.sources)
                        ShopTag(text: s, color: ShopColors.inkFaint),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_turns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final s in _chips)
                    ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 9)),
                      visualDensity: VisualDensity.compact,
                      onPressed: _busy ? null : () => _ask(s),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    style: const TextStyle(fontSize: 11),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _busy ? null : _ask(),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'پرسش خود را بنویسید…',
                      hintStyle: TextStyle(fontSize: 9.5),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _busy ? null : () => _ask(),
                  icon: const Icon(Icons.send_rounded, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(DocChatTurn t) => Align(
    alignment: t.isUser ? Alignment.centerLeft : Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: t.isUser ? ShopColors.surface : const Color(0xfff4f7ff),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShopColors.line),
      ),
      child: Text(
        t.text,
        style: const TextStyle(fontSize: 10, height: 1.9),
      ),
    ),
  );
}
