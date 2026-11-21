# =============================================================================
# ساخت نسخه Release کم‌حجم اپ فروغ آریا در ویندوز (PowerShell)
# کاربرد: .\scripts\build-slim.ps1 [apk-split | apk-arm64 | apk-universal | aab | web]
# =============================================================================
param(
  [ValidateSet("apk-split", "apk-arm64", "apk-universal", "aab", "web")]
  [string]$Mode = "apk-split"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

flutter clean
flutter pub get

$CommonFlags = @(
  "--release",
  "--tree-shake-icons",
  "--obfuscate",
  "--split-debug-info=build/symbols"
)

switch ($Mode) {
  "apk-arm64" {
    flutter build apk @CommonFlags --target-platform android-arm64
    Get-Item build/app/outputs/flutter-apk/app-release.apk | Select-Object Name, @{N="SizeMB";E={[math]::Round($_.Length/1MB,2)}}
  }
  "apk-split" {
    flutter build apk @CommonFlags --split-per-abi
    Get-ChildItem build/app/outputs/flutter-apk/*.apk | Select-Object Name, @{N="SizeMB";E={[math]::Round($_.Length/1MB,2)}}
  }
  "apk-universal" {
    flutter build apk @CommonFlags
    Get-Item build/app/outputs/flutter-apk/app-release.apk | Select-Object Name, @{N="SizeMB";E={[math]::Round($_.Length/1MB,2)}}
  }
  "aab" {
    flutter build appbundle @CommonFlags
    Get-Item build/app/outputs/bundle/release/app-release.aab | Select-Object Name, @{N="SizeMB";E={[math]::Round($_.Length/1MB,2)}}
  }
  "web" {
    flutter build web --release --tree-shake-icons
  }
}
