#!/usr/bin/env python3
# دانلود مدل گفتار فارسی Vosk (small-fa-0.42) برای قرار دادن در APK.
# مدل داخل ریپازیتوری کامیت نمی‌شود؛ این اسکریپت آن را می‌سازد:
#   python3 tools/fetch_vosk_model.py
# سپس:
#   flutter build apk --release --split-per-abi
import hashlib, os, sys, urllib.request

MODEL = 'vosk-model-small-fa-0.42'
DEST = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src',
                    'main', 'assets', 'models', MODEL + '.zip')
URLS = [
    f'https://alphacephei.com/vosk/models/{MODEL}.zip',
    f'https://hf-mirror.com/csukuangfj/vosk-models/resolve/main/fa/{MODEL}.zip',
    f'https://huggingface.co/csukuangfj/vosk-models/resolve/main/fa/{MODEL}.zip',
]
MIN_BYTES = 40 * 1024 * 1024
EXPECTED_SHA256 = '977cb5faa538f3a835ccfd35f5f6d8284b5c450b89c700b9bd4736b66536ad46'

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
