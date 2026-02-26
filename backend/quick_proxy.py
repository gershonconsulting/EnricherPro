#!/usr/bin/env python3
"""Quick Proxy Server for EnricherPro"""

import http.server
import socketserver
import json
import urllib.request
import urllib.error

class QuickProxyHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory='/home/user/flutter_app/build/web', **kwargs)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()
    
    def do_GET(self):
        if self.path.startswith('/api/') or self.path == '/health':
            self.proxy_request('GET')
        else:
            super().do_GET()
    
    def do_POST(self):
        if self.path.startswith('/api/'):
            self.proxy_request('POST')
        else:
            self.send_response(404)
            self.end_headers()
    
    def proxy_request(self, method):
        try:
            backend_url = f'http://localhost:5000{self.path}'
            print(f'🔄 Proxying {method}: {backend_url}')
            
            if method == 'POST':
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length)
                req = urllib.request.Request(
                    backend_url,
                    data=post_data,
                    headers={'Content-Type': 'application/json'}
                )
                with urllib.request.urlopen(req, timeout=120) as response:
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(response.read())
            else:
                with urllib.request.urlopen(backend_url, timeout=10) as response:
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(response.read())
                    
        except urllib.error.URLError as e:
            print(f'❌ Backend connection error: {e}')
            self.send_response(502)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            error_response = json.dumps({
                'error': 'Backend API unavailable',
                'details': str(e)
            })
            self.wfile.write(error_response.encode('utf-8'))
        except Exception as e:
            print(f'❌ Proxy error: {type(e).__name__}: {e}')
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            error_response = json.dumps({
                'error': 'Proxy error',
                'details': str(e)
            })
            self.wfile.write(error_response.encode('utf-8'))
    
    def log_message(self, format, *args):
        if self.path.startswith('/api/') or self.path == '/health':
            print(f"🔄 API: {args[0]}")

if __name__ == '__main__':
    PORT = 5060
    
    with socketserver.TCPServer(("0.0.0.0", PORT), QuickProxyHandler) as httpd:
        print("=" * 60)
        print("🚀 EnricherPro Quick Proxy Server")
        print("=" * 60)
        print(f"📱 Flutter Web:  http://0.0.0.0:{PORT}/")
        print(f"🔌 API Proxy:    http://0.0.0.0:{PORT}/api/*")
        print(f"💚 Health:       http://0.0.0.0:{PORT}/health")
        print("=" * 60)
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n🛑 Shutting down...")
