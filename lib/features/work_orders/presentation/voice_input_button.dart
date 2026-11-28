import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vosk_flutter_service/vosk_flutter_service.dart';

import '../../../core/audio/local_vosk.dart';

/// دکمهٔ ورودی صوتی — تبدیل زندهٔ گفتار فارسی به متن با **تایپ هم‌زمان**.
///
/// مسیرها:
/// - اندروید: موتور کاملاً محلی و آفلاین **Vosk** (مدل small-fa-0.42 فارسی)
///   — بدون گوگل، اینترنت و سرور؛ متن **همان‌لحظهٔ صحبت** در کادر تایپ می‌شود.
/// - iOS: موتور اپل با نتایج زنده (SFSpeechRecognizer).
/// - وب/PWA: موتور مرورگر (webkitSpeechRecognition) با بافر نتایج.
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({
    super.key,
    required this.controller,
    this.onChanged,
    this.maxLength,
  });
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

/// موتور اندروید (کش مشترک بین دفعات): مدل و recognizer یک‌بار ساخته و reuse می‌شوند.
class _VoskEngine {
  static final VoskFlutterPlugin vosk = VoskFlutterPlugin.instance();
  static Model? model;
  static Recognizer? recognizer;
}

/// وضعیت موتور گفتار سیستم (iOS/وب)
class _SttSession {
  static final speech = stt.SpeechToText();
  static bool initialized = false;
  static _VoiceInputButtonState? owner;
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  bool _busy = false;
  bool _listening = false;

  // --- ماشین تایپ زنده (اندروید Vosk / iOS اپل) ---
  bool _liveActive = false;
  String _origBefore = ''; // متن کادر قبل از نقطه‌ای که دیکته شروع می‌شود
  String _prefixBase = ''; // متن قبل از دیکته +فاصلهٔ جداکننده در صورت نیاز
  String _segSuffix = ''; // متن بعد از نقطه‌ای که دیکته شروع می‌شود (دست‌نخورده می‌ماند)
  String _finalText = ''; // بخش‌های قطعی‌شدهٔ این نشست
  String _partial = ''; // فرضیهٔ جاری این‌لحظه

  // اندروید: سرویس/اشتراک‌های این نشست
  SpeechService? _voskService;
  StreamSubscription<String>? _partialSub;
  StreamSubscription<String>? _resultSub;

  // وب: بافر نتایج جزئی (موتور وب finalResult نمی‌دهد)
  String _webBuffer = '';
  bool _heardResult = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && kLocalVoskSupported;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  // ============================================================
  //  تایپ زندهٔ مشترک
  // ============================================================

  void _liveBegin() {
    final v = widget.controller.value;
    final sel = v.selection;
    final caret = sel.isValid ? sel.end : v.text.length;
    _origBefore = v.text.substring(0, caret);
    _segSuffix = v.text.substring(caret);
    final needsSpace =
        _origBefore.isNotEmpty && !RegExp(r'\s$').hasMatch(_origBefore);
    _prefixBase = _origBefore + (needsSpace ? ' ' : '');
    _finalText = '';
    _partial = '';
    _liveActive = true;
  }

  String get _composed =>
      [_finalText.trim(), _partial.trim()].where((e) => e.isNotEmpty).join(' ');

  void _liveApply() {
    if (!mounted || !_liveActive) return;
    var composed = _composed;
    if (widget.maxLength != null) {
      final budget = widget.maxLength! - _origBefore.length - _segSuffix.length;
      if (budget <= 0) composed = ''; else if (composed.length > budget) {
        composed = composed.substring(0, budget);
      }
    }
    final text = composed.isEmpty
        ? _origBefore + _segSuffix
        : _prefixBase + composed + _segSuffix;
    final caret = composed.isEmpty
        ? _origBefore.length
        : _prefixBase.length + composed.length;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
    widget.onChanged?.call(text);
  }

  void _liveSetPartial(String words) {
    _partial = words.trim();
    _liveApply();
  }

  void _liveAppendFinal(String words) {
    words = words.trim();
    if (words.isNotEmpty) {
      _finalText =
          _finalText.trim().isEmpty ? words : '${_finalText.trim()} $words';
    }
    _partial = '';
    _liveApply();
  }

  void _liveEnd() {
    _liveActive = false;
    _finalText = '';
    _partial = '';
  }

  // ============================================================
  //  دکمه
  // ============================================================

  Future<void> _toggle() async {
    if (_busy) return;
    if (_listening) {
      if (_isAndroid) {
        await _stopVosk();
      } else if (!kIsWeb) {
        await _SttSession.speech.stop();
      } else {
        await _SttSession.speech.stop(); // وب: flush در کالبک وضعیت انجام می‌شود
      }
      return;
    }
    if (_isAndroid) {
      return _startVosk();
    }
    return _startStt();
  }

  // ============================================================
  //  اندروید — Vosk کاملاً محلی با تایپ زنده
  // ============================================================

  Future<void> _startVosk() async {
    _busy = true;
    setState(() {});
    try {
      // آماده‌سازی مدل (باندل‌شده؛ در حالت عادی آنی است)
      final path = await LocalVosk.instance.ensureModelPath();
      if (path == null) {
        _message('مدل گفتار فارسی در این نصب پیدا نشد؛ لطفاً برنامه را مجدداً نصب کنید.');
        return;
      }
      if (_VoskEngine.model == null) {
        _VoskEngine.model = await _VoskEngine.vosk.createModel(path);
      }
      if (_VoskEngine.recognizer == null) {
        _VoskEngine.recognizer = await _VoskEngine.vosk.createRecognizer(
          model: _VoskEngine.model!,
          sampleRate: 16000,
        );
      }
      _liveBegin();
      _voskService = await _VoskEngine.vosk.initSpeechService(_VoskEngine.recognizer!);
      _partialSub = _voskService!.onPartial().listen((raw) {
        final j = _tryJson(raw);
        final words = (j?['partial'] ?? '').toString().trim();
        _heardResult = _heardResult || words.isNotEmpty;
        _liveSetPartial(words);
      });
      _resultSub = _voskService!.onResult().listen((raw) {
        final j = _tryJson(raw);
        final words = (j?['text'] ?? '').toString().trim();
        _heardResult = _heardResult || words.isNotEmpty;
        _liveAppendFinal(words);
      });
      _heardResult = false;
      await _voskService!.start();
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _listening = true);
    } catch (e) {
      await _teardownVosk();
      _liveEnd();
      _message('شروع تشخیص گفتار ناموفق بود؛ اجازهٔ میکروفن را بررسی کنید.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopVosk() async {
    _busy = true;
    setState(() {});
    try {
      final service = _voskService;
      await _partialSub?.cancel();
      await _resultSub?.cancel();
      _partialSub = null;
      _resultSub = null;
      if (service != null) {
        await service.stop();
        try {
          final tail = await _VoskEngine.recognizer?.getFinalResult();
          final words = ((_tryJson(tail)?['text']) ?? '').toString().trim();
          _liveAppendFinal(words);
        } catch (_) {}
        await service.dispose();
      }
      _voskService = null;
      if (!_heardResult && _composed.isEmpty) {
        // متن نهایی هم خالی بود
      }
      final anyHeard = _heardResult;
      _liveEnd();
      _heardResult = false;
      if (!anyHeard) {
        _message('متنی تشخیص داده نشد؛ نزدیک‌تر به میکروفن و شمرده صحبت کنید.');
      }
    } catch (_) {
      _message('پایان ضبط با خطا مواجه شد.');
    } finally {
      if (mounted) {
        setState(() {
          _listening = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _teardownVosk() async {
    await _partialSub?.cancel();
    await _resultSub?.cancel();
    _partialSub = null;
    _resultSub = null;
    try {
      await _voskService?.cancel();
    } catch (_) {}
    try {
      await _voskService?.dispose();
    } catch (_) {}
    _voskService = null;
    if (mounted) setState(() => _listening = false);
  }

  static Map<String, dynamic>? _tryJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  //  iOS / وب — موتور گفتار سیستم/مرورگر
  // ============================================================

  Future<void> _startStt() async {
    if (_SttSession.owner != null && _SttSession.owner != this) {
      _message('ابتدا ضبط کادر دیگر را متوقف کنید.');
      return;
    }
    _SttSession.owner = this;
    _busy = true;
    setState(() {});
    try {
      if (!_SttSession.initialized) {
        _SttSession.initialized = await _SttSession.speech.initialize(
          onStatus: (status) {
            final owner = _SttSession.owner;
            if (owner == null || !owner.mounted) return;
            if (status == 'done' || status == 'notListening') {
              owner._listening = false;
              if (kIsWeb) owner._flushWebBuffer();
              if (!owner._heardResult && owner._composed.isEmpty) {
                owner._message(
                  'متنی تشخیص داده نشد؛ نزدیک‌تر به میکروفن صحبت کنید.',
                );
              }
              owner._heardResult = false;
              owner._liveEnd();
              owner.setState(() {});
              _SttSession.owner = null;
            }
          },
          onError: (error) {
            final owner = _SttSession.owner;
            if (owner == null || !owner.mounted) return;
            owner._listening = false;
            owner._webBuffer = '';
            owner._liveEnd();
            _SttSession.owner = null;
            owner.setState(() {});
            final code = error.errorMsg;
            owner._message(
              'تشخیص گفتار انجام نشد${code.isNotEmpty ? ' ($code)' : ''}؛ مجوز میکروفن را بررسی کنید.',
            );
          },
        );
      }
      if (!_SttSession.initialized) {
        _SttSession.owner = null;
        _message(
          kIsWeb
              ? 'این مرورگر از تشخیص گفتار پشتیبانی نمی‌کند یا میکروفن مجاز نیست.'
              : 'دسترسی میکروفن یا سرویس تشخیص گفتار در دسترس نیست.',
        );
        return;
      }

      String? localeId;
      var partialResults = false;
      var mode = stt.ListenMode.dictation;
      if (kIsWeb) {
        localeId = 'fa-IR';
        partialResults = false; // وب finalResult ندارد؛ از بافر استفاده می‌کنیم
        mode = stt.ListenMode.dictation;
      } else {
        // iOS — نتایج زنده با تایپ هم‌زمان
        try {
          final locales = await _SttSession.speech.locales();
          final fa = locales
              .where((l) =>
                  l.localeId.toLowerCase().replaceAll('-', '_').startsWith('fa'))
              .toList();
          localeId = fa.isNotEmpty ? fa.first.localeId : 'fa-IR';
        } catch (_) {
          localeId = 'fa-IR';
        }
        partialResults = true;
        mode = stt.ListenMode.dictation;
      }

      if (!mounted || _SttSession.owner != this) return;
      _webBuffer = '';
      _heardResult = false;
      if (!kIsWeb) _liveBegin();
      setState(() => _listening = true);
      await _SttSession.speech.listen(
        localeId: localeId,
        listenOptions: stt.SpeechListenOptions(
          partialResults: partialResults,
          cancelOnError: kIsWeb,
          listenMode: mode,
        ),
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) _heardResult = true;
          if (kIsWeb) {
            _webBuffer = words;
            return;
          }
          if (result.finalResult) {
            _liveAppendFinal(words);
          } else {
            _liveSetPartial(words);
          }
        },
      );
    } catch (_) {
      if (_SttSession.owner == this) _SttSession.owner = null;
      if (mounted) setState(() => _listening = false);
      _liveEnd();
      _message('شروع تشخیص گفتار ناموفق بود.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// تزریق متن بافرشدهٔ وب؛ می‌تواند چندبار صدا زده شود بدون تداخل.
  void _flushWebBuffer() {
    final pending = _webBuffer.trim();
    _webBuffer = '';
    if (pending.isEmpty) return;
    _insertRecognized(pending);
  }

  /// درج قطعی متن (وب) داخل کادر با حفظ مکان‌نما.
  void _insertRecognized(String words) {
    if (!mounted) return;
    words = words.trim();
    if (words.isEmpty) return;
    final controller = widget.controller;
    final existing = controller.text;
    final selection = controller.selection;
    final start =
        selection.isValid ? selection.start.clamp(0, existing.length) : existing.length;
    final end =
        selection.isValid ? selection.end.clamp(0, existing.length) : existing.length;
    final prefix = start > 0 && !RegExp(r'\s').hasMatch(existing[start - 1]) ? ' ' : '';
    final suffix =
        end < existing.length && !RegExp(r'\s').hasMatch(existing[end]) ? ' ' : '';
    var text = existing.replaceRange(start, end, '$prefix$words$suffix');
    if (widget.maxLength != null) {
      text = LengthLimitingTextInputFormatter.truncate(
        TextEditingValue(text: text),
        widget.maxLength!,
      ).text;
    }
    final cursor = (start + prefix.length + words.length + suffix.length)
        .clamp(0, text.length);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
    widget.onChanged?.call(text);
  }

  @override
  void dispose() {
    if (_SttSession.owner == this) {
      _SttSession.owner = null;
      _SttSession.speech.cancel();
    }
    _teardownVosk();
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
      tooltip: _listening ? 'پایان دیکته' : 'دیکتهٔ زندهٔ فارسی (تایپ هم‌زمان)',
      onPressed: _toggle,
      icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded),
      color: _listening ? Colors.red : null,
    );
  }
}
