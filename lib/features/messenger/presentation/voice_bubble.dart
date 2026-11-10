// ============================================================
//  حباب پیام صوتی — پخش/توقف با نوار پیشرفت و موج صوتی
//  پخش از فایل محلی (پیام تازه) یا فایل دانلودشده از سرور.
// ============================================================

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../models/chat_models.dart';
import 'messenger_style.dart';

class VoiceBubble extends StatefulWidget {
  const VoiceBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  static const _channel = MethodChannel('forough/audio');

  bool _playing = false;
  bool _loading = false;
  bool _played = false;
  File? _file;

  @override
  void dispose() {
    if (_playing) {
      _channel.invokeMethod('stop').catchError((_) => null);
    }
    super.dispose();
  }

  Future<File?> _resolveFile() async {
    if (_file != null) return _file;
    final local = widget.message.localPath;
    if (local != null) {
      final f = File(local);
      if (await f.exists()) return _file = f;
    }
    final url = widget.message.audioUrl;
    if (url == null || url.isEmpty) return null;
    final dir = await getTemporaryDirectory();
    final name = url.split('/').last.split('?').first;
    final target = File('${dir.path}/$name');
    if (await target.exists()) return _file = target;
    final api = context.read<ApiClient>();
    final full = url.startsWith('http') ? url : '${api.baseUrl}/$url';
    await api.dio.download(full, target.path);
    return _file = target;
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {
      await _channel.invokeMethod('stop');
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final f = await _resolveFile();
      if (f == null) throw Exception('فایل صوتی موجود نیست');
      final ok = await _channel.invokeMethod<bool>('play', {'path': f.path});
      if (!mounted) return;
      setState(() {
        _playing = ok == true;
        _loading = false;
        _played = true;
      });
      if (_playing) {
        // پایان پخش تقریبی با مدت پیام
        Future.delayed(Duration(seconds: widget.message.durationSec + 1), () {
          if (mounted && _playing) setState(() => _playing = false);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _playing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('پخش نشد: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final tint = m.mine ? MessengerColors.brandDeep : MessengerColors.brand;
    return SizedBox(
      width: 208,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint,
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 26,
                  child: _Wave(
                    playing: _playing,
                    tint: tint,
                    seed: m.id.abs(),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${m.durationLabel}${_played && !_playing ? ' · پخش شد' : ''}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: MessengerColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// موج صوتی تزئینی با ارتفاع شبه‌تصادفی ثابت (بدون پکیج اضافه)
class _Wave extends StatelessWidget {
  const _Wave({required this.playing, required this.tint, required this.seed});

  final bool playing;
  final Color tint;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final bars = <double>[];
    var v = seed % 97 + 7;
    for (var i = 0; i < 26; i++) {
      v = (v * 37 + 11) % 97;
      bars.add(6 + (v / 97) * 18);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < bars.length; i++)
          Container(
            width: 2.4,
            height: playing ? bars[i] : bars[i] * 0.62,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: playing ? 0.85 : 0.38),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const Spacer(),
        Text(
          Fa.digits('1×'),
          style: const TextStyle(
            fontSize: 9,
            color: MessengerColors.inkFaint,
          ),
        ),
      ],
    );
  }
}
