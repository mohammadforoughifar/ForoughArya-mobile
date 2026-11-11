// ============================================================
//  ارتباط مدرک با «اتوماسیون اداری» (نامه / ایمیل / صورتجلسه)
//  آینهٔ جریان وب میان DocArchive و OfficeAutomation — بر پایهٔ
//  اندپوینت‌های واقعی موجود:
//    نامه:   /api/letters, /api/outgoing-letters, /api/incoming-letters
//            → POST {root}/{id}/attachments
//    ایمیل:  فرم نگارش ایمیل اپ با پیوست آماده
//    صورتجلسه: POST /api/attachments/MeetingMinutes/{id}
// ============================================================

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../misc/data/minutes_repository.dart';
import '../../misc/models/minutes_models.dart';
import '../../office_automation/data/office_repository.dart';
import '../../office_automation/models/email_models.dart';
import '../../office_automation/models/letter_models.dart';
import '../../office_automation/presentation/email_compose_page.dart';
import '../../office_automation/presentation/email_page.dart' show EmailScope;
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'system_style.dart';

class DocAutomationSheet extends StatefulWidget {
  const DocAutomationSheet({
    super.key,
    required this.document,
    required this.attachments,
  });

  final DocRow document;
  final List<DocAttachment> attachments;

  @override
  State<DocAutomationSheet> createState() => _DocAutomationSheetState();
}

class _DocAutomationSheetState extends State<DocAutomationSheet> {
  late final DocArchiveRepository _docRepo;
  late final OfficeAutomationRepository _office;
  late final MinutesRepository _minutes;

  String _target = 'letter';
  LetterKind _kind = LetterKind.inner;

  bool _loading = false;
  bool _busy = false;
  String? _error;
  String? _ok;

  List<LetterListItem> _letters = const [];
  List<MinutesListItem> _minutesList = const [];

  int? _pickedLetterId;
  int? _pickedMinutesId;
  int? _attachmentId;

  Uint8List? _extraBytes;
  String _extraName = '';

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    _docRepo = DocArchiveRepository(api);
    _office = OfficeAutomationRepository(api);
    _minutes = MinutesRepository(api);
    _attachmentId = widget.attachments.isEmpty
        ? null
        : widget.attachments.first.id;
    _loadLetters();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  Future<void> _loadLetters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final paged = switch (_kind) {
        LetterKind.inner => await _office.innerInbox(pageSize: 50),
        LetterKind.outgoing => await _office.outgoingSent(pageSize: 50),
        LetterKind.incoming => await _office.incomingInbox(pageSize: 50),
      };
      if (!mounted) return;
      setState(() {
        _letters = paged.items;
        _pickedLetterId = _letters.isEmpty ? null : _letters.first.letterId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _letters = const [];
        _error = _clean(e);
      });
    }
  }

  Future<void> _loadMinutes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final paged = await _minutes.fetchList(take: 50);
      if (!mounted) return;
      setState(() {
        _minutesList = paged.items;
        _pickedMinutesId = _minutesList.isEmpty ? null : _minutesList.first.id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _minutesList = const [];
        _error = _clean(e);
      });
    }
  }

  Future<({Uint8List bytes, String name})?> _payload() async {
    if (_extraBytes != null) return (bytes: _extraBytes!, name: _extraName);
    final id = _attachmentId;
    if (id == null) return null;
    try {
      final bytes = await _docRepo.attachmentBytes(id);
      if (bytes.isEmpty) return null;
      var name = 'document-attachment';
      for (final a in widget.attachments) {
        if (a.id == id) {
          name = a.fileName;
          break;
        }
      }
      return (bytes: Uint8List.fromList(bytes), name: name);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickLocal() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final f = files.first;
    if (f.path == null) return;
    final bytes = await f.readAsBytes();
    setState(() {
      _extraBytes = bytes;
      _extraName = f.name;
    });
  }

  Future<void> _sendToLetter() async {
    final id = _pickedLetterId;
    if (id == null) {
      setState(() => _error = 'نامه مقصد را انتخاب کنید.');
      return;
    }
    final p = await _payload();
    if (p == null) {
      setState(() => _error = 'فایلی برای ارسال پیدا نشد.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      await _office.uploadAttachment(_kind, id, '', p.name, bytes: p.bytes);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _ok = 'فایل «${p.name}» به نامه پیوست شد.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _clean(e);
      });
    }
  }

  Future<void> _sendToMinutes() async {
    final id = _pickedMinutesId;
    if (id == null) {
      setState(() => _error = 'صورتجلسه مقصد را انتخاب کنید.');
      return;
    }
    final p = await _payload();
    if (p == null) {
      setState(() => _error = 'فایلی برای ارسال پیدا نشد.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      await _minutes.uploadAttachment(id, fileName: p.name, bytes: p.bytes);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _ok = 'فایل «${p.name}» به صورتجلسه پیوست شد.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _clean(e);
      });
    }
  }

  Future<void> _sendToEmail() async {
    final p = await _payload();
    if (p == null) {
      setState(() => _error = 'فایلی برای ارسال پیدا نشد.');
      return;
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop();
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => EmailComposePage(
          scope: EmailScope.corporate,
          accounts: const [],
          initialSubject: '${widget.document.code} — ${widget.document.title}',
          initialBody:
              'با سلام،\nمدرک «${widget.document.title}» (کد ${widget.document.code}) از آرشیو اسناد ارسال می‌شود.\n',
          initialFiles: [(name: p.name, bytes: p.bytes, mimeType: null)],
        ),
      ),
    );
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
                const Icon(Icons.hub_outlined, size: 17, color: ShopColors.seed),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'ارتباط با اتوماسیون اداری',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              'مدرک را به نامه، ایمیل یا صورتجلسه وصل کنید؛ فایل پیوست همان نسخهٔ جاری فرستاده می‌شود.',
              style: TextStyle(
                fontSize: 9,
                height: 1.8,
                color: ShopColors.inkFaint,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
              children: [
                _card(
                  title: '۱) فایل مدرک',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.attachments.isEmpty && _extraBytes == null)
                        const Text(
                          'این مدرک پیوستی ندارد.',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: ShopColors.danger,
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          isDense: true,
                          initialValue: _extraBytes != null
                              ? '__local'
                              : (_attachmentId == null
                                    ? null
                                    : '$_attachmentId'),
                          style: const TextStyle(
                            fontSize: 10,
                            color: ShopColors.ink,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'فایل ارسالی',
                            labelStyle: TextStyle(fontSize: 9),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final a in widget.attachments)
                              DropdownMenuItem(
                                value: '${a.id}',
                                child: Text(
                                  a.fileName,
                                  style: const TextStyle(fontSize: 9.5),
                                ),
                              ),
                            if (_extraBytes != null)
                              DropdownMenuItem(
                                value: '__local',
                                child: Text(
                                  _extraName,
                                  style: const TextStyle(fontSize: 9.5),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            if (v == null || v == '__local') return;
                            _extraBytes = null;
                            _attachmentId = int.tryParse(v);
                          }),
                        ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        onPressed: _pickLocal,
                        icon: const Icon(Icons.attach_file_rounded, size: 14),
                        label: const Text(
                          'افزودن فایل از گوشی',
                          style: TextStyle(fontSize: 9.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _card(
                  title: '۲) مقصد',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text(
                              'نامه',
                              style: TextStyle(fontSize: 9.5),
                            ),
                            visualDensity: VisualDensity.compact,
                            selected: _target == 'letter',
                            onSelected: (_) => setState(() {
                              _target = 'letter';
                              if (_letters.isEmpty) _loadLetters();
                            }),
                          ),
                          ChoiceChip(
                            label: const Text(
                              'ایمیل',
                              style: TextStyle(fontSize: 9.5),
                            ),
                            visualDensity: VisualDensity.compact,
                            selected: _target == 'email',
                            onSelected: (_) => setState(() => _target = 'email'),
                          ),
                          ChoiceChip(
                            label: const Text(
                              'صورتجلسه',
                              style: TextStyle(fontSize: 9.5),
                            ),
                            visualDensity: VisualDensity.compact,
                            selected: _target == 'minutes',
                            onSelected: (_) {
                              setState(() => _target = 'minutes');
                              if (_minutesList.isEmpty) _loadMinutes();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_target == 'letter') ...[
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final k in const [
                              (LetterKind.inner, 'داخلی'),
                              (LetterKind.outgoing, 'صادره'),
                              (LetterKind.incoming, 'وارده'),
                            ])
                              ChoiceChip(
                                label: Text(
                                  k.$2,
                                  style: const TextStyle(fontSize: 9),
                                ),
                                visualDensity: VisualDensity.compact,
                                selected: _kind == k.$1,
                                onSelected: (_) {
                                  setState(() => _kind = k.$1);
                                  _loadLetters();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_letters.isEmpty)
                          const Text(
                            'نامه‌ای برای انتخاب نیست.',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: ShopColors.inkFaint,
                            ),
                          )
                        else
                          DropdownButtonFormField<int>(
                            isDense: true,
                            initialValue: _pickedLetterId,
                            style: const TextStyle(
                              fontSize: 10,
                              color: ShopColors.ink,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'نامه مقصد',
                              labelStyle: TextStyle(fontSize: 9),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final l in _letters)
                                DropdownMenuItem(
                                  value: l.letterId,
                                  child: Text(
                                    '${l.letterNumber.isEmpty ? '' : '${l.letterNumber} — '}${l.title}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 9.5),
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _pickedLetterId = v),
                          ),
                      ],
                      if (_target == 'minutes')
                        _loading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _minutesList.isEmpty
                            ? const Text(
                                'صورتجلسه‌ای برای انتخاب نیست.',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: ShopColors.inkFaint,
                                ),
                              )
                            : DropdownButtonFormField<int>(
                                isDense: true,
                                initialValue: _pickedMinutesId,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: ShopColors.ink,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'صورتجلسه مقصد',
                                  labelStyle: TextStyle(fontSize: 9),
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (final m in _minutesList)
                                    DropdownMenuItem(
                                      value: m.id,
                                      child: Text(
                                        m.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 9.5),
                                      ),
                                    ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _pickedMinutesId = v),
                              ),
                      if (_target == 'email')
                        const Text(
                          'برای ایمیل، فایل مدرک به‌صورت پیوست در صفحهٔ نوشتن ایمیل قرار می‌گیرد.',
                          style: TextStyle(
                            fontSize: 9,
                            height: 1.8,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  SystemNote(
                    text: _error!,
                    color: ShopColors.danger,
                    icon: Icons.error_outline_rounded,
                  ),
                ],
                if (_ok != null) ...[
                  const SizedBox(height: 8),
                  SystemNote(
                    text: _ok!,
                    color: ShopColors.ok,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : switch (_target) {
                            'email' => _sendToEmail,
                            'minutes' => _sendToMinutes,
                            _ => _sendToLetter,
                          },
                    icon: const Icon(Icons.send_rounded, size: 15),
                    label: const Text(
                      'ارسال به اتوماسیون',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}
