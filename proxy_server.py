"""
Unified proxy server that serves both Flutter web app and proxies API requests
This eliminates CORS issues by serving everything from the same origin
"""

import http.server
import socketserver
import urllib.request
import json
from urllib.parse import urlparse, parse_qs

PORT = 5060
BACKEND_URL = "http://localhost:5000"

class ProxyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Proxy API health check requests to backend
        if self.path.startswith('/health'):
            self.proxy_to_backend('GET')
        else:
            # Serve static files from build/web
            super().do_GET()
    
    def do_POST(self):
        # Proxy API requests to backend
        if self.path.startswith('/api/'):
            self.proxy_to_backend('POST')
        else:
            self.send_error(404)
    
    def do_OPTIONS(self):
        # Handle CORS preflight
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def proxy_to_backend(self, method):
        """Proxy request to backend server"""
        try:
            # Build backend URL
            backend_url = f"{BACKEND_URL}{self.path}"
            
            # Read request body for POST
            content_length = 0
            body = None
            if method == 'POST':
                content_length = int(self.headers.get('Content-Length', 0))
                body = self.rfile.read(content_length) if content_length > 0 else None
            
            # Create request
            req = urllib.request.Request(backend_url, data=body, method=method)
            if body:
                req.add_header('Content-Type', 'application/json')
            
            # Make request to backend (longer timeout for email validation)
            with urllib.request.urlopen(req, timeout=120) as response:
                # Send response
                self.send_response(response.status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                
                # Forward response body
                self.wfile.write(response.read())
        
        except Exception as e:
            print(f"Proxy error: {e}")
            self.send_error(502, f"Backend error: {str(e)}")
    
    def end_headers(self):
        # Add cache busting headers for static files
        if not self.path.startswith('/api/') and not self.path.startswith('/health'):
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
        super().end_headers()


if __name__ == '__main__':
    with socketserver.TCPServer(("0.0.0.0", PORT), ProxyHTTPRequestHandler) as httpd:
        print("=" * 60)
        print(f"🚀 Unified Proxy Server running on port {PORT}")
        print(f"   Frontend: http://0.0.0.0:{PORT}/")
        print(f"   Backend Proxy: http://0.0.0.0:{PORT}/api/*")
        print(f"   Backend Target: {BACKEND_URL}")
        print("=" * 60)
        httpd.serve_forever()
