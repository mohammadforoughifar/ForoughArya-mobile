import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// The plugin is a singleton: route its callbacks to the currently active field.
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

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle() async {
    if (_starting) return;
    if (_VoiceSession.owner == this && _listening) {
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
              owner.setState(() => owner._listening = false);
              // Keep the owner until the final result arrives (or done).
              if (status == 'done') _VoiceSession.owner = null;
            }
          },
          onError: (error) {
            final owner = _VoiceSession.owner;
            if (owner == null || !owner.mounted) return;
            owner.setState(() => owner._listening = false);
            _VoiceSession.owner = null;
            owner._message('تشخیص گفتار انجام نشد؛ مجوز، اتصال اینترنت و تنظیمات زبان گوشی را بررسی کنید.');
          },
        );
      }
      if (!_VoiceSession.initialized) {
        _VoiceSession.owner = null;
        _message('دسترسی میکروفن یا سرویس تشخیص گفتار در دسترس نیست.');
        return;
      }
      final locales = await _VoiceSession.speech.locales();
      final fa = locales.where((l) => l.localeId.toLowerCase().replaceAll('-', '_').startsWith('fa')).toList();
      if (fa.isEmpty) {
        _VoiceSession.owner = null;
        _message('زبان فارسی در سرویس تشخیص گفتار این دستگاه در دسترس نیست.');
        return;
      }
      if (!mounted || _VoiceSession.owner != this) return;
      setState(() => _listening = true);
      await _VoiceSession.speech.listen(
        localeId: fa.first.localeId,
        listenOptions: stt.SpeechListenOptions(partialResults: false),
        onResult: (result) {
          if (!mounted || _VoiceSession.owner != this || !result.finalResult) return;
          final words = result.recognizedWords.trim();
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
            text = LengthLimitingTextInputFormatter.truncate(text, widget.maxLength!);
          }
          final cursor = (start + prefix.length + words.length + suffix.length).clamp(0, text.length);
          controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor));
          widget.onChanged?.call(text);
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
