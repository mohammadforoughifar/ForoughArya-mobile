import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// تعریف میکروفن دکمهٔ ورودی صوتی برای موبایل (Android/iOS) و وب/PWA.
///
/// نکتهٔ مهم وب: پلاگین وب (webkitSpeechRecognition) هرگز `finalResult`
/// نمی‌فرستد و `locales()` هم روی وب خالی برمی‌گرداند؛ به همین دلیل روی وب
/// نتایج جزئی را داخل بافر نگه می‌داریم و با پایان وضعیت (done / notListening)
/// یک‌بار به کادر تزریق می‌کنیم و زبان را مستقیماً `fa-IR` می‌گذاریم.
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

  /// آخرین متن تشخیص‌داده‌شده روی وب (که finalResult ندارد) — فقط در وب استفاده می‌شود.
  String _webBuffer = '';

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

  /// تزریق متن بافرشدهٔ وب؛ می‌تواند چندبار صدا زده شود بدون تداخل.
  void _flushWebBuffer() {
    final pending = _webBuffer.trim();
    _webBuffer = '';
    if (pending.isEmpty) return;
    _insertRecognized(pending);
  }

  Future<void> _toggle() async {
    if (_starting) return;
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
              owner.setState(() {});
              // نگه‌داشتن مالکیت تا رسیدن نتیجهٔ نهایی (یا پایان نشست)
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
      // - موبایل: بعضی گوشی‌ها/سرویس‌ها لیست زبان‌ها را خالی برمی‌گردانند یا
      //   فارسی را فهرست نمی‌کنند (اما خود سرویس آن را می‌شناسد)؛ بنابراین
      //   به‌جای خطای مرگبار، به fa-IR برمی‌گردیم و فقط اگر واقعاً پیدا شود از آن استفاده می‌کنیم.
      String? localeId;
      if (kIsWeb) {
        localeId = 'fa-IR';
      } else {
        try {
          final locales = await _VoiceSession.speech.locales();
          final fa = locales
              .where((l) => l.localeId.toLowerCase().replaceAll('-', '_').startsWith('fa'))
              .toList();
          if (fa.isNotEmpty) {
            localeId = fa.first.localeId;
          } else {
            localeId = 'fa-IR';
            _message('زبان فارسی در فهرست زبان‌های این دستگاه دیده نشد؛ با fa-IR اینترنت‌محور تلاش می‌شود.');
          }
        } catch (_) {
          localeId = 'fa-IR';
        }
      }

      if (!mounted || _VoiceSession.owner != this) return;
      _webBuffer = '';
      setState(() => _listening = true);
      await _VoiceSession.speech.listen(
        localeId: localeId,
        // روی وب: continuous=false بگذار؛ روی آیفون سافاری continuous=true
        // هرگز متن نهایی برنمی‌گرداند. با توقف خودکار پس از اولین مکث، متن
        // نهایی در onend برمی‌گردد و به کادر تزریق می‌شود.
        // روی موبایل: فقط نتیجهٔ نهایی (رفتار تأییدشدهٔ قبلی)
        listenOptions: stt.SpeechListenOptions(
          partialResults: false,
          cancelOnError: kIsWeb,
          listenMode: kIsWeb ? stt.ListenMode.dictation : stt.ListenMode.confirmation,
        ),
        onResult: (result) {
          if (!mounted || _VoiceSession.owner != this) return;
          final words = result.recognizedWords.trim();
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

  @override
  void dispose() {
    if (_VoiceSession.owner == this) {
      _VoiceSession.owner = null;
      _VoiceSession.speech.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _listening ? 'پایان گفتار' : 'تبدیل گفتار فارسی به متن',
    onPressed: _starting ? null : _toggle,
    icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded),
    color: _listening ? Colors.red : null,
  );
}
