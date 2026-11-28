import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/audio/local_whisper.dart';

/// دکمهٔ ورودی صوتی برای تبدیل گفتار فارسی به متن.
///
/// مسیرها:
/// - اندروید: **کاملاً محلی** با whisper.cpp (مدلِ فشردهٔ q5_1) روی خود دستگاه؛
///   مدل داخل خود APK است و هنگام اولین اجرا کپی می‌شود — هیچ دانلود و تأخیری
///   وجود ندارد (بدون گوگل/اینترنت/سرور).
/// - وب/PWA و iOS: از موتور گفتار مرورگر/سیستم (webkitSpeechRecognition / SFSpeechRecognizer) استفاده می‌شود.
///   نکتهٔ وب: پلاگین وب هرگز `finalResult` نمی‌فرستد و `locales()` هم خالی برمی‌گرداند؛
///   به همین دلیل روی وب نتایج را داخل بافر نگه می‌داریم و با پایان وضعیت تزریق می‌کنیم.
class _VoiceSession {
  static final speech = stt.SpeechToText();
  static _VoiceInputButtonState? owner;
  static bool initialized = false;
}

class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({super.key, required this.controller, this.onChanged, this.maxLength});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  bool _starting = false;
  bool _listening = false;
  bool _busy = false;
  AudioRecorder? _recorder;
  String? _activePath;

  /// آخرین متن تشخیص‌داده‌شده روی وب (که finalResult ندارد) — فقط در وب استفاده می‌شود.
  String _webBuffer = '';

  /// آیا در این نشست حداقل یک نتیجه (حتی جزئی) از موتور گرفتیم؟
  bool _heardResult = false;

  bool get _useLocalWhisper =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && kLocalWhisperSupported;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
  }

  /// متن تشخیص‌داده‌شده را داخل کادر فعال می‌نشاند و مکان‌نما را می‌سازد.
  void _insertRecognized(String words) {
    if (!mounted) return;
    words = words.trim();
    if (words.isEmpty) return;
    final controller = widget.controller;
    final existing = controller.text;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start.clamp(0, existing.length) : existing.length;
    final end = selection.isValid ? selection.end.clamp(0, existing.length) : existing.length;
    final prefix = start > 0 && !RegExp(r'\s').hasMatch(existing[start - 1]) ? ' ' : '';
    final suffix = end < existing.length && !RegExp(r'\s').hasMatch(existing[end]) ? ' ' : '';
    var text = existing.replaceRange(start, end, '$prefix$words$suffix');
    if (widget.maxLength != null) {
      text = LengthLimitingTextInputFormatter.truncate(
        TextEditingValue(text: text),
        widget.maxLength!,
      ).text;
    }
    final cursor = (start + prefix.length + words.length + suffix.length).clamp(0, text.length);
    controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor));
    widget.onChanged?.call(text);
  }

  Future<void> _toggle() async {
    if (_starting || _busy) return;
    if (_useLocalWhisper) {
      return _toggleLocalWhisper();
    }
    return _toggleStt();
  }

  // ============================================================
  //  مسیر محلی اندروید (whisper.cpp روی خود گوشی)
  // ============================================================

  Future<void> _toggleLocalWhisper() async {
    final recorder = _recorder ??= AudioRecorder();

    if (_listening) {
      // پایان ضبط و تبدیل روی خود دستگاه
      setState(() => _starting = true);
      try {
        final path = await recorder.stop();
        _activePath = null;
        if (mounted) setState(() => _listening = false);
        if (path == null) {
          _message('ضبط صدا متوقف نشد؛ دوباره تلاش کنید.');
          return;
        }
        final text = await _transcribeWithProgressDialog(path);
        if (text != null && text.trim().isNotEmpty) {
          _insertRecognized(text.trim());
        } else {
          _message('متنی تشخیص داده نشد؛ آرام‌تر و نزدیک‌تر به میکروفون صحبت کنید.');
        }
        await LocalWhisper.instance.discard(path);
      } catch (_) {
        _message('تبدیل صدا به متن ناموفق بود؛ حافظهٔ گوشی را بررسی کنید.');
      } finally {
        if (mounted) setState(() {
          _starting = false;
          _busy = false;
        });
      }
      return;
    }

    // شروع ضبط (در صورت نیاز، مدل فارسی اول یک‌بار آماده می‌شود)
    if (!await recorder.hasPermission()) {
      _message('برای ضبط صدا، مجوز میکروفن لازم است.');
      return;
    }
    if (!await LocalWhisper.instance.isModelReady()) {
      final ok = await _askDownloadModel();
      if (ok != true) return;
      _busy = true;
      if (mounted) setState(() {});
      final ready = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ModelDownloadDialog(),
      );
      _busy = false;
      if (mounted) setState(() {});
      if (ready != true) {
        _message('دانلود مدل گفتار فارسی ناموفق بود؛ اتصال اینترنت و حافظهٔ آزاد گوشی را بررسی کنید.');
        return;
      }
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/fa_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    try {
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: path,
      );
      _activePath = path;
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _listening = true);
    } catch (_) {
      _message('شروع ضبط ممکن نشد.');
    }
  }

  Future<bool?> _askDownloadModel() => showDialog<bool>(
    context: context,
    builder: (c) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'مدل گفتار فارسی آماده نیست',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        content: const Text(
          'مدل گفتار فارسی در این نصب پیدا نشد.\n\nبا تأیید شما، مدل فشرده (حدود ۵۷ مگابایت) یک‌بار از اینترنت دریافت و ذخیره می‌شود؛ بعد از آن تبدیل صدا به متن کاملاً روی خود گوشی و آفلاین انجام می‌شود.',
          style: TextStyle(height: 1.7, fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('بعداً'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('دانلود و ادامه'),
          ),
        ],
      ),
    ),
  );

  Future<String?> _transcribeWithProgressDialog(String path) {
    _busy = true;
    if (mounted) setState(() {});
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TranscribeProgressDialog(
        task: () async {
          try {
            return await LocalWhisper.instance.transcribe(path, language: 'fa');
          } catch (_) {
            return null;
          }
        },
      ),
    );
  }

  // ============================================================
  //  مسیر موتور سیستم (اندروید بسیار قدیمی/iOS/PWA)
  // ============================================================

  Future<void> _toggleStt() async {
    if (_VoiceSession.owner == this && _listening) {
      // روی وب برای تزریق متن بافرشده باید به‌جای cancel از stop استفاده شود
      await _VoiceSession.speech.stop();
      return;
    }
    if (_VoiceSession.owner != null) {
      _message('ابتدا ضبط کادر دیگر را متوقف کنید.');
      return;
    }
    _VoiceSession.owner = this;
    setState(() => _starting = true);
    try {
      if (!_VoiceSession.initialized) {
        _VoiceSession.initialized = await _VoiceSession.speech.initialize(
          onStatus: (status) {
            final owner = _VoiceSession.owner;
            if (owner == null || !owner.mounted) return;
            if (status == 'done' || status == 'notListening') {
              owner._listening = false;
              // روی وب، finalResult هرگز نمی‌آید؛ متن بافرشده را همین‌جا تزریق کن
              if (kIsWeb) owner._flushWebBuffer();
              if (!owner._heardResult) {
                owner._message(
                  'متنی تشخیص داده نشد؛ فارسی احتمالاً روی این سرویس پشتیبانی نمی‌شود. '
                  'از میکروفن کیبورد Gboard داخل همین کادر استفاده کنید.',
                );
              }
              owner._heardResult = false;
              owner.setState(() {});
              // مالکیت فقط برای توقف/شروع بعدی نگه‌داشته می‌شود، نه برای مسیر متن
              if (status == 'done' || status == 'notListening') {
                _VoiceSession.owner = null;
              }
            }
          },
          onError: (error) {
            final owner = _VoiceSession.owner;
            if (owner == null || !owner.mounted) return;
            owner._listening = false;
            owner._webBuffer = '';
            _VoiceSession.owner = null;
            owner.setState(() {});
            final code = error.errorMsg;
            owner._message(kIsWeb
                ? 'تشخیص گفتار انجام نشد${code.isNotEmpty ? ' ($code)' : ''}؛ مجوز میکروفن، اینترنت و HTTPS را بررسی کنید.'
                : 'تشخیص گفتار انجام نشد${code.isNotEmpty ? ' ($code)' : ''}؛ مجوز میکروفن، اینترنت و سرویس گوگل گوشی را بررسی کنید.');
          },
        );
      }
      if (!_VoiceSession.initialized) {
        _VoiceSession.owner = null;
        _message(kIsWeb
            ? 'این مرورگر از تشخیص گفتار پشتیبانی نمی‌کند یا میکروفن مجاز نیست.'
            : 'دسترسی میکروفن یا سرویس تشخیص گفتار در دسترس نیست.');
        return;
      }

      // انتخاب زبان:
      // - وب: locales() خالی است و باید مستقیماً fa-IR ست شود
      // - iOS: فارسی در فهرست SFSpeechRecognizer هست؛ fa-IR استفاده می‌شود
      String? localeId;
      if (kIsWeb) {
        localeId = 'fa-IR';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          final locales = await _VoiceSession.speech.locales();
          final fa = locales
              .where((l) => l.localeId.toLowerCase().replaceAll('-', '_').startsWith('fa'))
              .toList();
          localeId = fa.isNotEmpty ? fa.first.localeId : 'fa-IR';
        } catch (_) {
          localeId = 'fa-IR';
        }
      } else {
        localeId = 'fa-IR';
      }

      if (!mounted || _VoiceSession.owner != this) return;
      _webBuffer = '';
      _heardResult = false;
      setState(() => _listening = true);
      await _VoiceSession.speech.listen(
        localeId: localeId,
        // روی وب: continuous=false بگذار؛ روی آیفون سافاری continuous=true
        // هرگز متن نهایی برنمی‌گرداند. با توقف خودکار پس از اولین مکث، متن
        // نهایی در onend برمی‌گردد و به کادر تزریق می‌شود.
        listenOptions: stt.SpeechListenOptions(
          partialResults: false,
          cancelOnError: kIsWeb,
          listenMode: kIsWeb ? stt.ListenMode.dictation : stt.ListenMode.confirmation,
        ),
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) _heardResult = true;
          if (words.isEmpty) return;
          if (kIsWeb) {
            // وب finalResult ندارد؛ آخرین متن را برای زمان توقف نگه می‌داریم
            _webBuffer = words;
            return;
          }
          if (!result.finalResult) return;
          _insertRecognized(words);
        },
      );
    } catch (_) {
      if (_VoiceSession.owner == this) _VoiceSession.owner = null;
      if (mounted) setState(() => _listening = false);
      _message('شروع تشخیص گفتار ناموفق بود.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// تزریق متن بافرشدهٔ وب؛ می‌تواند چندبار صدا زده شود بدون تداخل.
  void _flushWebBuffer() {
    final pending = _webBuffer.trim();
    _webBuffer = '';
    if (pending.isEmpty) return;
    _insertRecognized(pending);
  }

  @override
  void dispose() {
    if (_VoiceSession.owner == this) {
      _VoiceSession.owner = null;
      _VoiceSession.speech.cancel();
    }
    if (_activePath != null) {
      LocalWhisper.instance.discard(_activePath!);
      _activePath = null;
    }
    unawaited(_recorder?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
        width: 44,
        height: 44,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: _listening ? 'پایان ضبط و تبدیل به متن' : 'تبدیل گفتار فارسی به متن',
      onPressed: _starting ? null : _toggle,
      icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded),
      color: _listening ? Colors.red : null,
    );
  }
}

// ============================================================
//  دیالوگ دانلود/نمایش پیشرفت مدل گفتار فارسی
// ============================================================

class _ModelDownloadDialog extends StatefulWidget {
  const _ModelDownloadDialog();

  @override
  State<_ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<_ModelDownloadDialog> {
  double? _progress;

  @override
  void initState() {
    super.initState();
    LocalWhisper.instance
        .prepareModel(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        )
        .then((ok) {
          if (mounted) Navigator.of(context).pop(ok);
        })
        .catchError((_) {
          if (mounted) Navigator.of(context).pop(false);
        });
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'در حال دریافت مدل گفتار فارسی',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          if (_progress == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('در حال آماده‌سازی…'),
            )
          else ...[
            LinearProgressIndicator(value: _progress!.clamp(0.0, 1.0)),
            const SizedBox(height: 10),
            Text(
              '${(_progress! * 100).toStringAsFixed(0)}٪',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'معمولاً به این مرحله نمی‌رسید چون مدل داخل اپ است.',
            style: TextStyle(fontSize: 11.5, color: Color(0xff64748b)),
          ),
        ],
      ),
    ),
  );
}

class _TranscribeProgressDialog extends StatefulWidget {
  const _TranscribeProgressDialog({required this.task});
  final Future<String?> Function() task;

  @override
  State<_TranscribeProgressDialog> createState() => _TranscribeProgressDialogState();
}

class _TranscribeProgressDialogState extends State<_TranscribeProgressDialog> {
  @override
  void initState() {
    super.initState();
    widget.task().then((text) {
      if (mounted) Navigator.of(context).pop(text);
    }).catchError((_) {
      if (mounted) Navigator.of(context).pop(null);
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'در حال تبدیل صدا به متن…',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 4),
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 12),
          Text(
            'روی خود گوشی پردازش می‌شود؛\nمعمولاً در کمتر از یک تا دو ثانیه آماده می‌شود.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.7, color: Color(0xff475569)),
          ),
        ],
      ),
    ),
  );
}
