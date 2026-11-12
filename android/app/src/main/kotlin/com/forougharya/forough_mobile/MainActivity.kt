package com.forougharya.forough_mobile

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
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

    /** نتایج در انتظارِ پاسخ کاربر به پنجرهٔ اجازهٔ میکروفن */
    private var pendingResult: MethodChannel.Result? = null
    private val micRequestCode = 4711

    private fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    /** درخواست واقعی اجازهٔ میکروفن (قبلاً همیشه true برمی‌گرداند و همین علت خرابی بود) */
    private fun askMic(result: MethodChannel.Result) {
        if (hasMicPermission()) {
            result.success(true)
            return
        }
        if (pendingResult != null) {
            result.success(false)
            return
        }
        pendingResult = result
        try {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                micRequestCode,
            )
        } catch (e: Exception) {
            pendingResult = null
            result.success(false)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == micRequestCode) {
            val ok = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(ok)
            pendingResult = null
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "forough/voice")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(true)
                    "hasPermission" -> result.success(hasMicPermission())
                    "requestPermission" -> askMic(result)
                    // باز کردن تنظیمات برنامه برای وقتی کاربر «هرگز اجازه نده» زده است
                    "openSettings" -> {
                        try {
                            startActivity(
                                android.content.Intent(
                                    android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    android.net.Uri.parse("package:$packageName"),
                                ),
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "start" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        if (!hasMicPermission()) {
                            // بدون مجوز، ضبط بی‌صدا/خراب می‌شود
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            releaseRecorder()
                            val rec = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                MediaRecorder(this)
                            } else {
                                @Suppress("DEPRECATION")
                                MediaRecorder()
                            }
                            rec.setAudioSource(MediaRecorder.AudioSource.MIC)
                            rec.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                            rec.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                            rec.setAudioEncodingBitRate(64000)
                            rec.setAudioSamplingRate(44100)
                            rec.setOutputFile(path)
                            rec.prepare()
                            rec.start()
                            recorder = rec
                            recorderPath = path
                            result.success(true)
                        } catch (e: Exception) {
                            releaseRecorder()
                            result.error(
                                "RECORD_FAILED",
                                "شروع ضبط صدا ناموفق بود: ${e.message}",
                                null,
                            )
                        }
                    }
                    "stop" -> {
                        val path = recorderPath
                        val rec = recorder
                        recorder = null
                        recorderPath = null
                        if (rec == null || path == null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        try {
                            rec.stop()
                        } catch (e: Exception) {
                            // خیلی کوتاه بود (کمتر از نیم‌ثانیه) → فایل معتبر نیست
                            try { rec.release() } catch (_: Exception) {}
                            File(path).delete()
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        try { rec.release() } catch (_: Exception) {}
                        val f = File(path)
                        if (!f.exists() || f.length() < 512) {
                            f.delete()
                            result.success(null)
                        } else {
                            result.success(path)
                        }
                    }
                    "cancel" -> {
                        val path = recorderPath
                        val rec = recorder
                        recorder = null
                        recorderPath = null
                        try { rec?.stop() } catch (_: Exception) {}
                        try { rec?.release() } catch (_: Exception) {}
                        if (path != null) File(path).delete()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ---- سرویس پیش‌زمینهٔ اعلان (پاپ‌آپ حتی با اپ بسته) ----
        val pushPrefs = getSharedPreferences("forough_push", android.content.Context.MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "forough/push")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        try {
                            val e = pushPrefs.edit()
                            call.argument<String>("baseUrl")?.let { e.putString("api_base_url", it) }
                            call.argument<String>("token")?.let { e.putString("auth_token", it) }
                            call.argument<String>("companyId")?.let { e.putString("company_id", it) }
                            val seen = call.argument<Int>("lastSeenId")
                            if (seen != null && seen >= 0) e.putInt("push_last_seen_id", seen)
                            e.apply()
                            result.success(true)
                        } catch (ex: Exception) {
                            result.success(false)
                        }
                    }
                    "lastSeenId" -> result.success(pushPrefs.getInt("push_last_seen_id", 0))
                    "start" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val granted = ContextCompat.checkSelfPermission(
                                this, Manifest.permission.POST_NOTIFICATIONS,
                            ) == PackageManager.PERMISSION_GRANTED
                            if (!granted) {
                                ActivityCompat.requestPermissions(
                                    this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4712,
                                )
                            }
                        }
                        PushPollingService.start(this)
                        result.success(true)
                    }
                    "stop" -> {
                        PushPollingService.stop(this)
                        result.success(true)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val pm = getSystemService(android.content.Context.POWER_SERVICE)
                                    as android.os.PowerManager
                                if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                    startActivity(
                                        android.content.Intent(
                                            android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                            android.net.Uri.parse("package:$packageName"),
                                        ),
                                    )
                                }
                            }
                            result.success(true)
                        } catch (ex: Exception) {
                            result.success(false)
                        }
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

    private fun releaseRecorder() {
        try { recorder?.release() } catch (_: Exception) {}
        recorder = null
        recorderPath = null
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
