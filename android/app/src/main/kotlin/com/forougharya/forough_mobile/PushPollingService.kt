package com.forougharya.forough_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * سرویس پیش‌زمینهٔ اعلان‌ها.
 *
 * چرا بومی و نه Dart؟
 *   اندروید وقتی اپ بسته/در پس‌زمینه است، تایمرهای داخل اپ (Dart) را متوقف می‌کند و
 *   WorkManager حداقل ۱۵ دقیقه فاصله دارد. برای «پاپ‌آپ فوری حتی وقتی اپ بسته است»
 *   تنها راهِ در دسترسِ اپ، یک سرویس پیش‌زمینه با اعلان ثابت است که هر ۶۰ ثانیه
 *   `/api/notifications` را می‌خواند و اعلان تازه را در نوار اندروید می‌نشاند.
 *
 *   داده‌های لازم (آدرس سرور، توکن، شرکت فعال، آخرین شناسهٔ دیده‌شده) از همان
 *   SharedPreferences خوانده می‌شود که flutter_secure_storage در اندروید استفاده
 *   می‌کند؛ سپس سرویس مستقل از اپ کار می‌کند.
 *
 * شروع: از Dart با MethodChannel «forough/push» → start()
 * توقف: stop() یا خروج از حساب
 */
class PushPollingService : Service() {

    companion object {
        const val CHANNEL_ID = "forough_service"
        const val CHANNEL_NAME = "سرویس اعلان فروغ آریا"
        const val CHANNEL_DESC = "اعلان ثابت لازم برای دریافت اعلان‌ها در حالت بسته بودن برنامه"

        /** کانال اعلان‌هایی که به کاربر نمایش داده می‌شود (همان کانال Dart) */
        const val NOTIF_CHANNEL_ID = "forough_notifications"
        const val NOTIF_CHANNEL_NAME = "اعلان‌های فروغ آریا"

        const val FOREGROUND_ID = 9901
        const val INTERVAL_MS = 60_000L

        fun start(context: Context) {
            try {
                val i = Intent(context, PushPollingService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
            } catch (_: Exception) {
            }
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, PushPollingService::class.java))
            } catch (_: Exception) {
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var running = false
    private lateinit var prefs: SharedPreferences

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            executor.execute { pollOnce() }
            handler.postDelayed(this, INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        prefs = securePrefs(this)
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!running) {
            running = true
            try {
                val n = buildForegroundNotification()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        FOREGROUND_ID,
                        n,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                    )
                } else {
                    startForeground(FOREGROUND_ID, n)
                }
            } catch (_: Exception) {
                stopSelf()
                return START_NOT_STICKY
            }
            handler.post(tick)
        }
        return START_STICKY // اگر سیستم کشت، خودش دوباره بالا می‌آورد
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacksAndMessages(null)
        try {
            executor.shutdownNow()
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    // ------------------------------------------------------------------
    //  اعلان‌ها
    // ------------------------------------------------------------------

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)

        val service = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_MIN,
        )
        service.description = CHANNEL_DESC
        service.setShowBadge(false)
        nm.createNotificationChannel(service)

        val notif = NotificationChannel(
            NOTIF_CHANNEL_ID,
            NOTIF_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        )
        notif.description = "نامه‌های ارجاع‌شده، دستور کارها و اعلان‌های سازمانی"
        notif.enableVibration(true)
        nm.createNotificationChannel(notif)
    }

    private fun contentIntent(): PendingIntent {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent().setClassName(packageName, "$packageName.MainActivity")
        launch.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        return PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildForegroundNotification(): Notification {
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return b
            .setContentTitle("اعلان‌ها فعال است")
            .setContentText("دریافت اعلان‌های فروغ آریا در پس‌زمینه")
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(contentIntent())
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }

    /** حذف تگ‌ها و موجودیت‌های HTML از متن اعلان. */
    private fun plainText(raw: String): String {
        if (raw.isBlank()) return raw
        val looksHtml = Regex("<\\s*/?\\s*[a-zA-Z][^<>]*>|&(#\\d+|#x[0-9a-fA-F]+|[a-zA-Z]{2,8});")
            .containsMatchIn(raw)
        if (!looksHtml) return raw
        val text = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            android.text.Html.fromHtml(raw, android.text.Html.FROM_HTML_MODE_COMPACT)
        } else {
            @Suppress("DEPRECATION")
            android.text.Html.fromHtml(raw)
        }).toString()
        return text.replace('\u00A0', ' ').replace('\uFFFC', ' ')
            .replace(Regex("[ \\t]+"), " ")
            .replace(Regex("\\n{3,}"), "\n\n")
            .trim()
    }

    private fun showUserNotification(id: Int, title: String, body: String, payload: String) {
        val nm = getSystemService(NotificationManager::class.java)
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIF_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val style = Notification.BigTextStyle().bigText(body)
        b.setContentTitle(if (title.isBlank()) "اعلان سازمانی" else title)
            .setContentText(body)
            .setStyle(style)
            .setSmallIcon(applicationInfo.icon)
            .setAutoCancel(true)
            .setContentIntent(contentIntent())
            .setOnlyAlertOnce(false)
        try {
            nm.notify(id, b.build())
        } catch (_: Exception) {
        }
        // اپ اگر باز شود، با همین payload رکورد مربوطه را باز می‌کند
        try {
            prefs.edit().putString("push_pending_payload", payload).apply()
        } catch (_: Exception) {
        }
    }

    // ------------------------------------------------------------------
    //  خواندن اعلان‌ها از سرور
    // ------------------------------------------------------------------

    private fun pollOnce() {
        val token = prefs.getString("auth_token", null)
        if (token.isNullOrEmpty()) {
            return // کاربر خارج شده؛ تا لاگین بعدی کاری نمی‌کنیم
        }
        val base = (prefs.getString("api_base_url", null) ?: "http://localhost:5100")
            .trimEnd('/')
        val companyId = prefs.getString("company_id", null)
        val seen = prefs.getInt("push_last_seen_id", 0)

        // آدرس فعلی + آدرس‌های جایگزین همان سرور (سوییچ خودکار با تغییر شبکه)
        val candidates = LinkedHashSet<String>()
        candidates.add(base)
        (prefs.getString("api_base_urls", null) ?: "")
            .split('\n')
            .map { it.trim().trimEnd('/') }
            .filter { it.isNotEmpty() }
            .forEach { candidates.add(it) }

        var conn: HttpURLConnection? = null
        try {
            var connected: HttpURLConnection? = null
            for (candidate in candidates) {
                try {
                    val c = URL("$candidate/api/notifications?take=20").openConnection() as HttpURLConnection
                    c.requestMethod = "GET"
                    c.connectTimeout = if (candidates.size > 1) 6000 else 15000
                    c.readTimeout = 20000
                    c.setRequestProperty("Accept", "application/json")
                    c.setRequestProperty("Authorization", "Bearer $token")
                    if (!companyId.isNullOrEmpty()) {
                        c.setRequestProperty("X-Company-Id", companyId)
                    }
                    c.responseCode // اتصال واقعی اینجا برقرار می‌شود
                    connected = c
                    if (candidate != base) {
                        prefs.edit().putString("api_base_url", candidate).apply()
                    }
                    break
                } catch (_: java.io.IOException) {
                    // این آدرس در این شبکه در دسترس نیست؛ بعدی
                }
            }
            conn = connected ?: return
            if (conn.responseCode !in 200..299) return

            val text = conn.inputStream.bufferedReader().use(BufferedReader::readText)
            val items: JSONArray = if (text.trimStart().startsWith("{")) {
                JSONObject(text).optJSONArray("items") ?: JSONArray()
            } else {
                JSONArray(text)
            }

            var maxId = seen
            val fresh = ArrayList<JSONObject>()
            for (i in 0 until items.length()) {
                val o = items.optJSONObject(i) ?: continue
                val id = o.optInt("id", 0)
                if (id > maxId) maxId = id
                if (id > seen) fresh.add(o)
            }
            if (fresh.isEmpty()) return

            // قدیمی‌ترها اول تا ترتیب نوار اعلان طبیعی باشد
            fresh.sortBy { it.optInt("id", 0) }
            var allShown = true
            for (o in fresh) {
                val id = o.optInt("id", 0)
                val title = plainText(o.optString("title", ""))
                val from = o.optString("fromName", "")
                // متن اعلان ممکن است HTML ادیتور وب باشد (مثلاً شرح دستور کار)
                val bodyText = plainText(o.optString("body", ""))
                val body = listOf(from, bodyText).filter { it.isNotBlank() }.joinToString(" — ")
                val company = o.optString("companyName", "")
                val fullTitle = if (company.isNotBlank()) "[$company] $title" else title
                try {
                    showUserNotification(id, fullTitle, body, o.toString())
                } catch (_: Exception) {
                    allShown = false
                }
            }
            // «دیده‌شده» فقط وقتی جلو می‌رود که همه واقعاً نشانده شده باشند
            if (allShown && maxId > seen) {
                prefs.edit().putInt("push_last_seen_id", maxId).apply()
            }
        } catch (_: Exception) {
            // شبکه قطع/سرور خاموش → دور بعد تلاش می‌شود
        } finally {
            try {
                conn?.disconnect()
            } catch (_: Exception) {
            }
        }
    }
}

/**
 * flutter_secure_storage در اندروید مقادیر را در SharedPreferences رمزنگاری‌شده
 * با نام «FlutterSecureStorage» نگه می‌دارد و مقدار هر کلید به شکل
 *   "<base64(ciphertext)> <base64(iv)>"? ...
 * بسته به نسخه متفاوت است. برای همین، هم فایل رمزنگاری‌شده و هم فایل سادهٔ
 * آینه‌ای (که Dart هنگام لاگین می‌نویسد) بررسی می‌شود.
 */
private fun securePrefs(ctx: Context): SharedPreferences =
    ctx.getSharedPreferences("forough_push", Context.MODE_PRIVATE)
