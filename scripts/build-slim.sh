#!/usr/bin/env bash
# =============================================================================
# ساخت نسخهٔ Release کم‌حجم اپ فروغ آریا (APK / AAB / Web PWA)
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:-apk-split}"

echo "==> دریافت وابستگی‌ها و پاک‌سازی کش ساخت قبلی..."
flutter clean
flutter pub get

COMMON_FLAGS=(
  --release
  --tree-shake-icons
  --obfuscate
  --split-debug-info=build/symbols
)

case "$MODE" in
  apk-arm64)
    echo "==> ساخت تک‌فایل APK مخصوص گوشی‌های ۶۴ بیتی (کمترین حجم، مناسب ۹۵٪+ گوشی‌ها)..."
    flutter build apk "${COMMON_FLAGS[@]}" --target-platform android-arm64
    ls -lh build/app/outputs/flutter-apk/app-release.apk
    ;;
  apk-split)
    echo "==> ساخت APK تفکیک‌شده برای هر معماری (arm64-v8a و armeabi-v7a)..."
    flutter build apk "${COMMON_FLAGS[@]}" --split-per-abi
    ls -lh build/app/outputs/flutter-apk/*.apk
    ;;
  apk-universal)
    echo "==> ساخت APK یونیورسال بدون x86_64 (نصب روی همهٔ گوشی‌های ۳۲ و ۶۴ بیتی)..."
    flutter build apk "${COMMON_FLAGS[@]}"
    ls -lh build/app/outputs/flutter-apk/app-release.apk
    ;;
  aab)
    echo "==> ساخت App Bundle (AAB) برای استورها..."
    flutter build appbundle "${COMMON_FLAGS[@]}"
    ls -lh build/app/outputs/bundle/release/app-release.aab
    ;;
  web)
    echo "==> ساخت نسخهٔ وب (PWA) کم‌حجم..."
    flutter build web --release --tree-shake-icons
    du -sh build/web
    ;;
  *)
    echo "کاربرد: bash scripts/build-slim.sh [apk-split | apk-arm64 | apk-universal | aab | web]"
    exit 1
    ;;
esac
