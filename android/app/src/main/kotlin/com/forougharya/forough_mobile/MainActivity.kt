package com.forougharya.forough_mobile

import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * پل بومی برای ضبط و پخش پیام صوتی پیام‌رسان.
 *
 *   record : start(path) / stop() / cancel() / available() / requestPermission()
 *   audio  : play(path) / stop() / duration(path)
 */
class MainActivity : FlutterActivity() {

    private var recorder: MediaRecorder? = null
    private var recorderPath: String? = null
    private var player: MediaPlayer? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "forough/voice")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(true)
                    "requestPermission" -> result.success(true)
                    "start" -> {
                        val path = call.argument<String>("path")
                        try {
                            recorder?.release()
                            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                MediaRecorder(this)
                            } else {
                                @Suppress("DEPRECATION")
                                MediaRecorder()
                            }.apply {
                                setAudioSource(MediaRecorder.AudioSource.MIC)
                                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                                setAudioEncodingBitRate(64000)
                                setAudioSamplingRate(44100)
                                setOutputFile(path)
                                prepare()
                                start()
                            }
                            recorderPath = path
                            result.success(true)
                        } catch (e: Exception) {
                            recorder?.release()
                            recorder = null
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        val path = recorderPath
                        try {
                            recorder?.stop()
                            recorder?.release()
                        } catch (e: Exception) {
                            // فایل ناقص — پاک می‌شود
                            if (path != null) File(path).delete()
                            recorder = null
                            recorderPath = null
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        recorder = null
                        recorderPath = null
                        result.success(path)
                    }
                    "cancel" -> {
                        val path = recorderPath
                        try {
                            recorder?.stop()
                        } catch (_: Exception) {
                        }
                        recorder?.release()
                        recorder = null
                        recorderPath = null
                        if (path != null) File(path).delete()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "forough/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        val path = call.argument<String>("path")
                        try {
                            player?.release()
                            player = MediaPlayer().apply {
                                setDataSource(path)
                                prepare()
                                start()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        try {
                            player?.stop()
                        } catch (_: Exception) {
                        }
                        player?.release()
                        player = null
                        result.success(true)
                    }
                    "duration" -> {
                        val path = call.argument<String>("path")
                        val d = try {
                            val p = MediaPlayer().apply {
                                setDataSource(path)
                                prepare()
                            }
                            val ms = p.duration
                            p.release()
                            ms
                        } catch (e: Exception) {
                            -1
                        }
                        result.success(d)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        try {
            recorder?.release()
        } catch (_: Exception) {
        }
        try {
            player?.release()
        } catch (_: Exception) {
        }
        super.onDestroy()
    }
}
