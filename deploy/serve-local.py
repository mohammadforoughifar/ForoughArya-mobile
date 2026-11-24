#!/usr/bin/env python3
"""سرور سبک اجرای سریع وب‌اپلیکیشن آیفون فروغ آریا (پشتیبانی کامل WASM، کش و SPA)."""
import http.server
import mimetypes
import os
import socketserver
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else int(os.environ.get('PORT', '8090'))

mimetypes.add_type('application/wasm', '.wasm')
mimetypes.add_type('text/javascript', '.mjs')
mimetypes.add_type('text/javascript', '.js')
mimetypes.add_type('application/manifest+json', '.webmanifest')
mimetypes.add_type('font/ttf', '.ttf')
mimetypes.add_type('font/otf', '.otf')


class PwaRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        p = self.path.split('?', 1)[0]
        if p in ('/', '/index.html', '/sw.js', '/pwa-config.js', '/manifest.json'):
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        # اجازهٔ نمایش در پیش‌نمایش زنده (iframe) و فونت‌ها/اسکریپت‌های هم‌مبدأ
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

    def do_GET(self):
        clean = self.path.split('?', 1)[0]
        full = self.translate_path(clean)
        if not os.path.exists(full) and '.' not in os.path.basename(clean):
            self.path = '/index.html'
        return super().do_GET()


class ThreadingServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True


if __name__ == '__main__':
    with ThreadingServer(('0.0.0.0', PORT), PwaRequestHandler) as httpd:
        print(f'Forough Arya iOS PWA running on http://0.0.0.0:{PORT}', flush=True)
        httpd.serve_forever()
