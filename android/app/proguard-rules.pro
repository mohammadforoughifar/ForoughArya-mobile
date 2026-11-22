# ---------------------------------------------------------------------------
# قواعد نگه‌داشتن کلاس‌های ضروری هنگام R8 (کاهش حجم کد و منابع)
# ---------------------------------------------------------------------------

# Flutter embedding
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# پلاگین‌های استفاده‌شده در پروژه (از طریق reflection/entry-point صدا زده می‌شوند)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class com.crazecoder.openfile.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.odml.** { *; }
-keep class androidx.camera.** { *; }

# flutter_local_notifications + GSON TypeToken (جلوگیری از خطای R8 fullMode روی اکشن‌های اعلان)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# سرویس پیش‌زمینهٔ بومی اعلان
-keep class com.forougharya.forough_mobile.PushPollingService { *; }

# Kotlin / Coroutines / metadata
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings { <fields>; }
-keepattributes *Annotation*, Signature, Exceptions, InnerClasses

# حذف لاگ‌های دیباگ/اطلاعاتی در نسخهٔ release
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
}
