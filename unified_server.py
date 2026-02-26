#!/usr/bin/env python3
"""
Unified Server for EnricherPro
- Serves Flutter web app on port 5060
- Proxies API requests to backend on port 5000
- Eliminates CORS issues
"""

import http.server
import socketserver
import urllib.request
import urllib.error
import json
from urllib.parse import urlparse, parse_qs

PORT = 5060
BACKEND_URL = "http://localhost:5000"

class UnifiedRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler that serves Flutter app and proxies API requests"""
    
    def __init__(self, *args, **kwargs):
        # Serve files from build/web directory
        super().__init__(*args, directory='build/web', **kwargs)
    
    def do_GET(self):
        """Handle GET requests"""
        # Proxy /health endpoint
        if self.path == '/health':
            self.proxy_to_backend()
        else:
            # Serve static files from build/web
            super().do_GET()
    
    def do_POST(self):
        """Handle POST requests - proxy to backend"""
        if self.path.startswith('/api/'):
            self.proxy_to_backend()
        else:
            self.send_error(404, "Not Found")
    
    def do_OPTIONS(self):
        """Handle OPTIONS requests for CORS preflight"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def proxy_to_backend(self):
        """Proxy request to backend API server"""
        try:
            # Build backend URL
            backend_url = f"{BACKEND_URL}{self.path}"
            
            # Read request body for POST requests
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None
            
            # Create request
            headers = {
                'Content-Type': 'application/json',
            }
            
            req = urllib.request.Request(
                backend_url,
                data=body,
                headers=headers,
                method=self.command
            )
            
            # Make request to backend with longer timeout (10 minutes for large batches with Snovio)
            with urllib.request.urlopen(req, timeout=600) as response:
                response_data = response.read()
                
                # Send response
                self.send_response(response.status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(response_data)
                
        except urllib.error.HTTPError as e:
            # Backend returned an error
            error_data = e.read()
            self.send_response(e.code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(error_data)
            
        except urllib.error.URLError as e:
            # Backend connection failed
            self.send_response(502)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            error_response = json.dumps({
                'error': 'Backend API unavailable',
                'details': str(e)
            }).encode()
            self.wfile.write(error_response)
            
        except Exception as e:
            # Other errors
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            error_response = json.dumps({
                'error': 'Proxy error',
                'details': str(e)
            }).encode()
            self.wfile.write(error_response)
    
    def log_message(self, format, *args):
        """Custom logging"""
        print(f"[{self.log_date_time_string()}] {format % args}")


if __name__ == '__main__':
    print("\n" + "="*60)
    print("🚀 EnricherPro - Unified Server")
    print("="*60)
    print(f"\n🌐 Website:          EnricherPro.com")
    print(f"📱 Flutter Web App:  http://0.0.0.0:{PORT}/")
    print(f"🔧 Backend API:      {BACKEND_URL}")
    print(f"🌐 Port:             {PORT}")
    print("\n" + "="*60)
    print("Starting server...")
    print("="*60 + "\n")
    
    with socketserver.TCPServer(("0.0.0.0", PORT), UnifiedRequestHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n🛑 Server stopped")
