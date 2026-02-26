#!/usr/bin/env python3
"""
EnricherPro Unified Server
Serves Flutter web app + proxies API requests to backend
Port: 5060 (Flutter + API)
Backend API: localhost:5000 (internal)
"""

import http.server
import socketserver
import urllib.request
import urllib.error
import json
from urllib.parse import urlparse, parse_qs

class UnifiedRequestHandler(http.server.SimpleHTTPRequestHandler):
    """
    Unified request handler that:
    1. Proxies /api/* and /health requests to backend API (port 5000)
    2. Serves Flutter web app for all other requests
    """
    
    # Backend API URL
    BACKEND_URL = 'http://localhost:5000'
    
    def __init__(self, *args, **kwargs):
        # Serve from Flutter build/web directory
        super().__init__(*args, directory='/home/user/flutter_app/build/web', **kwargs)
    
    def end_headers(self):
        """Add CORS headers and cache-busting headers to all responses"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('X-Frame-Options', 'ALLOWALL')
        self.send_header('Content-Security-Policy', 'frame-ancestors *')
        
        # Force browsers to NOT cache JavaScript/CSS files
        if self.path.endswith('.js') or self.path.endswith('.css'):
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
        
        super().end_headers()
    
    def do_OPTIONS(self):
        """Handle preflight CORS requests"""
        self.send_response(200)
        self.end_headers()
    
    def do_GET(self):
        """Handle GET requests - proxy API or serve Flutter"""
        if self.path.startswith('/api/') or self.path == '/health':
            self.proxy_to_backend('GET')
        else:
            # Serve Flutter web app
            super().do_GET()
    
    def do_POST(self):
        """Handle POST requests - proxy to backend API"""
        if self.path.startswith('/api/') or self.path.startswith('/health'):
            self.proxy_to_backend('POST')
        else:
            self.send_error(404, "Not Found")
    
    def proxy_to_backend(self, method):
        """Proxy request to backend API on port 5000"""
        try:
            # Build backend URL
            backend_url = f"{self.BACKEND_URL}{self.path}"
            
            # Read request body for POST
            content_length = int(self.headers.get('Content-Length', 0))
            request_body = self.rfile.read(content_length) if content_length > 0 else None
            
            # Create request
            headers = {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            
            req = urllib.request.Request(
                backend_url,
                data=request_body,
                headers=headers,
                method=method
            )
            
            # Send request to backend (10 minute timeout for batch operations)
            with urllib.request.urlopen(req, timeout=600) as response:
                response_data = response.read()
                
                # Send response to client
                self.send_response(response.status)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(response_data)
                
        except urllib.error.HTTPError as e:
            # Backend returned error
            error_data = e.read().decode('utf-8')
            print(f"❌ Backend HTTP Error {e.code}: {error_data[:200]}")
            self.send_response(e.code)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(error_data.encode('utf-8'))
            
        except urllib.error.URLError as e:
            # Backend unreachable
            print(f"❌ Backend URLError: {str(e.reason)}")
            self.send_response(503)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            error_response = json.dumps({
                'error': 'Backend API offline',
                'details': str(e.reason)
            })
            self.wfile.write(error_response.encode('utf-8'))
            
        except Exception as e:
            # Other error
            print(f"❌ Proxy Exception: {type(e).__name__}: {str(e)}")
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            error_response = json.dumps({
                'error': 'Proxy error',
                'details': str(e)
            })
            self.wfile.write(error_response.encode('utf-8'))
    
    def log_message(self, format, *args):
        """Custom logging"""
        # Log API requests
        if self.path.startswith('/api/') or self.path == '/health':
            print(f"🔄 API: {args[0]}")
        # Skip logging for static files
        elif not any(ext in self.path for ext in ['.js', '.css', '.png', '.ico', '.woff']):
            print(f"📄 Web: {args[0]}")

def run_server(port=5060):
    """Start unified server"""
    handler = UnifiedRequestHandler
    
    with socketserver.TCPServer(("0.0.0.0", port), handler) as httpd:
        print("=" * 60)
        print("🚀 EnricherPro Unified Server Started")
        print("=" * 60)
        print(f"📱 Flutter Web App:  http://0.0.0.0:{port}/")
        print(f"🔌 API Endpoints:    http://0.0.0.0:{port}/api/*")
        print(f"💚 Health Check:     http://0.0.0.0:{port}/health")
        print(f"🔧 Backend Proxy:    localhost:5000 → port {port}")
        print("=" * 60)
        print("✅ CORS Enabled")
        print("✅ API Proxying Enabled")
        print("✅ Flutter App Serving Enabled")
        print("=" * 60)
        print("\n🎯 Ready to serve requests!\n")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n🛑 Shutting down server...")

if __name__ == '__main__':
    run_server(5060)
