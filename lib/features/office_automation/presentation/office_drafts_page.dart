// ============================================================
//  پیش‌نویس‌ها — GET/POST/DELETE /pishnevis
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/office_repository.dart';
import '../models/letter_models.dart';
import 'letter_editor_page.dart';
import 'office_style.dart';

class OfficeDraftsPage extends StatefulWidget {
  const OfficeDraftsPage({super.key});

  @override
  State<OfficeDraftsPage> createState() => _OfficeDraftsPageState();
}

class _OfficeDraftsPageState extends State<OfficeDraftsPage> {
  OfficeAutomationRepository get _repo => context.read<OfficeAutomationRepository>();

  LetterKind _kind = LetterKind.inner;
  bool _loading = true;
  String? _error;
  List<DraftLetter> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _repo.drafts(_kind);
      if (mounted) {
        setState(() {
          _items = r.items;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'خطا در دریافت پیش‌نویس‌ها: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _delete(DraftLetter d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف پیش‌نویس'),
        content: Text('پیش‌نویس «${d.title}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteDraft(_kind, d.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _newDraft() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LetterEditorPage(kind: _kind)),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: OfficeSlidingTabs(
                  items: const [
                    (label: 'داخلی', icon: Icons.edit_note, key: 'in'),
                    (label: 'صادره', icon: Icons.north_east, key: 'out'),
                    (label: 'وارده', icon: Icons.south_west, key: 'inc'),
                  ],
                  index: _kind.index,
                  onChanged: (i) {
                    setState(() => _kind = LetterKind.values[i]);
                    _load();
                  },
                  pillColor: OfficeColors.accent,
                  accentFor: (i) => switch (i) {
                    1 => OfficeColors.outgoing,
                    2 => OfficeColors.incoming,
                    _ => OfficeColors.inner,
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _newDraft,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      OfficeColors.accent.withValues(alpha: .20),
                      OfficeColors.accent.withValues(alpha: .07),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: OfficeColors.accent.withValues(alpha: .30)),
                ),
                child: const Icon(Icons.note_add_outlined,
                    size: 19, color: OfficeColors.accent),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: _loading
            ? const OfficeShimmer(count: 5, height: 74)
            : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: MediaQuery.sizeOf(context).height * .16),
                          const EmptyView(
                            message: 'پیش‌نویسی ذخیره نکرده‌اید.',
                            icon: Icons.drafts_outlined,
                          ),
                        ],
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final d = _items[i];
                            return OFadeSlideIn(
                              index: i,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 9),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: OfficeColors.line),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueGrey.withValues(alpha: .05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            OfficeColors.accent.withValues(alpha: .18),
                                            OfficeColors.accent.withValues(alpha: .06),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: const Icon(Icons.drafts_outlined,
                                          size: 17, color: OfficeColors.accent),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              if (d.receiverOrganization != null)
                                                d.receiverOrganization!,
                                              if (d.createdAt != null)
                                                Fa.date(d.createdAt!.toIso8601String()),
                                            ].join(' • '),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: Colors.blueGrey.shade500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: OfficeColors.danger.withValues(alpha: .08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        onPressed: () => _delete(d),
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18, color: OfficeColors.danger),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    ],
  );
}
