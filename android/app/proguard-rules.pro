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

# Kotlin / Coroutines / metadata
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings { <fields>; }
-keepattributes *Annotation*, Signature, Exceptions, InnerClasses

# حذف لاگ‌ها در نسخهٔ release
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
}
