#!/usr/bin/env python3
"""Photo upload server for the quote board.

Serves an upload form and handles file uploads to /var/www/imgs/<NAME>/.
Intended to run behind Caddy on sec-board.digdug.dev (auth handled by Caddy).
"""

import html
import os
import re
import glob
from http.server import HTTPServer, BaseHTTPRequestHandler
from email.parser import BytesParser

IMGS_DIR = "/var/www/imgs"
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB

# PNG: 89 50 4E 47, JPEG: FF D8 FF
MAGIC_BYTES = {
    b"\x89PNG": "png",
    b"\xff\xd8\xff": "jpg",
}


def detect_image_type(data):
    for magic, ext in MAGIC_BYTES.items():
        if data[:len(magic)] == magic:
            return ext
    return None


def get_next_number(name):
    existing = glob.glob(os.path.join(IMGS_DIR, name, f"{name}*.*"))
    max_num = 0
    for path in existing:
        basename = os.path.basename(path)
        match = re.match(rf"^{re.escape(name)}(\d+)\.", basename)
        if match:
            max_num = max(max_num, int(match.group(1)))
    return max_num + 1


def get_available_names():
    if not os.path.isdir(IMGS_DIR):
        return []
    return sorted(
        d for d in os.listdir(IMGS_DIR)
        if os.path.isdir(os.path.join(IMGS_DIR, d))
    )


def html_page(title, body):
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <style>
    body {{ font-family: system-ui, sans-serif; max-width: 500px; margin: 40px auto; padding: 0 20px; }}
    h1 {{ font-size: 1.4em; }}
    label {{ display: block; margin-top: 16px; font-weight: bold; }}
    select, input[type=file] {{ margin-top: 4px; }}
    button {{ margin-top: 20px; padding: 8px 24px; font-size: 1em; cursor: pointer; }}
    .msg {{ padding: 12px; border-radius: 6px; margin-top: 16px; }}
    .ok {{ background: #d4edda; color: #155724; }}
    .err {{ background: #f8d7da; color: #721c24; }}
    a {{ color: #0066cc; }}
  </style>
</head>
<body>{body}</body>
</html>"""


def upload_form():
    names = get_available_names()
    options = "".join(f'<option value="{html.escape(n)}">{html.escape(n)}</option>' for n in names)
    return html_page("Upload Photo", f"""
  <h1>Upload Photo</h1>
  <form method="POST" enctype="multipart/form-data" action="/upload">
    <label for="name">Person</label>
    <select name="name" id="name" required>{options}</select>

    <label for="photo">Photo (PNG or JPEG, max 10MB)</label>
    <input type="file" name="photo" id="photo" accept="image/png,image/jpeg" required>

    <button type="submit">Upload</button>
  </form>
""")


def success_page(name, filename):
    return html_page("Upload Successful", f"""
  <h1>Upload Successful</h1>
  <div class="msg ok">Saved <strong>{html.escape(filename)}</strong> for {html.escape(name)}.</div>
  <p style="margin-top:16px"><a href="/upload">Upload another</a></p>
""")


def error_page(message):
    return html_page("Upload Error", f"""
  <h1>Upload Error</h1>
  <div class="msg err">{html.escape(message)}</div>
  <p style="margin-top:16px"><a href="/upload">Try again</a></p>
""")


def parse_multipart(handler):
    content_type = handler.headers.get("Content-Type", "")
    content_length = int(handler.headers.get("Content-Length", 0))

    if content_length > MAX_FILE_SIZE:
        return None, None, "File too large (max 10MB)."

    body = handler.rfile.read(content_length)

    # Build a MIME message to parse multipart data
    header = f"Content-Type: {content_type}\r\n\r\n".encode()
    msg = BytesParser().parsebytes(header + body)

    name = None
    file_data = None

    for part in msg.walk():
        disp = part.get("Content-Disposition", "")
        if 'name="name"' in disp:
            payload = part.get_payload(decode=True)
            if isinstance(payload, bytes):
                name = payload.decode().strip()
        elif 'name="photo"' in disp:
            payload = part.get_payload(decode=True)
            if isinstance(payload, bytes):
                file_data = payload

    return name, file_data, None


class UploadHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/upload":
            body = upload_form()
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(body.encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path != "/upload":
            self.send_response(404)
            self.end_headers()
            return

        name, file_data, err = parse_multipart(self)

        if err:
            self._respond(400, error_page(err))
            return

        if not name or not file_data:
            self._respond(400, error_page("Missing name or photo."))
            return

        # Validate name is an existing directory (no path traversal)
        if not re.match(r"^[A-Za-z]+$", name):
            self._respond(400, error_page("Invalid name."))
            return

        name_dir = os.path.join(IMGS_DIR, name)
        if not os.path.isdir(name_dir):
            self._respond(400, error_page(f"No directory found for '{name}'."))
            return

        # Validate image type by magic bytes
        ext = detect_image_type(file_data)
        if ext is None:
            self._respond(400, error_page("File must be a PNG or JPEG image."))
            return

        if len(file_data) > MAX_FILE_SIZE:
            self._respond(400, error_page("File too large (max 10MB)."))
            return

        # Save the file
        num = get_next_number(name)
        filename = f"{name}{num}.{ext}"
        filepath = os.path.join(name_dir, filename)
        with open(filepath, "wb") as f:
            f.write(file_data)

        self._respond(200, success_page(name, filename))

    def _respond(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, format, *args):
        # Log to stdout for journald
        print(f"{self.client_address[0]} - {format % args}")


if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", 8787), UploadHandler)
    print("Upload server listening on 127.0.0.1:8787")
    server.serve_forever()
