#!/usr/bin/env python3
# دانلود مدل گفتار فارسی (whisper.cpp، نسخهٔ فشردهٔ q5_1) برای قرار دادن در APK.
# مدل داخل ریپازیتوری کامیت نمی‌شود؛ این اسکریپت آن را می‌سازد:
#   python3 tools/fetch_voice_model.py
# سپس:
#   flutter build apk --release --split-per-abi
import hashlib, os, sys, urllib.request

DEST = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src',
                    'main', 'assets', 'models', 'ggml-base.bin')
URLS = [
    'https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin',
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin',
]
MIN_BYTES = 45 * 1024 * 1024  # فایل اصلی ≈ ۵۷MB
EXPECTED_SHA256 = '422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898'

os.makedirs(os.path.dirname(DEST), exist_ok=True)
for url in URLS:
    try:
        print('Downloading', url)
        urllib.request.urlretrieve(url, DEST + '.part')
        size = os.path.getsize(DEST + '.part')
        if size < MIN_BYTES:
            print('file too small:', size)
            os.remove(DEST + '.part')
            continue
        sha = hashlib.sha256(open(DEST + '.part', 'rb').read()).hexdigest()
        if EXPECTED_SHA256 and sha != EXPECTED_SHA256:
            print('sha256 mismatch:', sha)
            os.remove(DEST + '.part')
            continue
        os.replace(DEST + '.part', DEST)
        print(f'OK: {DEST} ({size/1024/1024:.1f} MB) sha256={sha}')
        sys.exit(0)
    except Exception as e:
        print('failed:', e)
print('همهٔ آینه‌ها ناموفق بودند.')
sys.exit(1)
