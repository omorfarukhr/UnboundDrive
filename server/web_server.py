import os
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler

class NoCacheHTTPRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

def run(port=8085, directory="build/web"):
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    if not os.path.exists(directory):
        os.makedirs(directory, exist_ok=True)
    
    server_address = ("", port)
    handler = lambda *args, **kwargs: NoCacheHTTPRequestHandler(*args, directory=directory, **kwargs)
    httpd = HTTPServer(server_address, handler)
    print(f"==================================================")
    print(f"  [+] UnboundDrive No-Cache Web Server running    ")
    print(f"  [*] Serving: {directory}                       ")
    print(f"  [*] Address: http://localhost:{port}           ")
    print(f"==================================================")
    sys.stdout.flush()
    httpd.serve_forever()

if __name__ == "__main__":
    p = 8085
    if len(sys.argv) > 1:
        p = int(sys.argv[1])
    run(port=p)
