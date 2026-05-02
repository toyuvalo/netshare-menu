#!/usr/bin/env python3
"""NetShare LAN server -- serves files and accepts uploads via browser."""

import sys, os, socket, html, urllib.parse, mimetypes, json, re, secrets
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

serve_dir  = Path(sys.argv[1]).resolve()
port       = int(sys.argv[2])
drop_dir   = Path(sys.argv[3]).resolve()
bind_ip    = sys.argv[4] if len(sys.argv) > 4 else ''
auth_token = sys.argv[5] if len(sys.argv) > 5 else ''
drop_dir.mkdir(parents=True, exist_ok=True)

if not auth_token:
    print('FATAL: auth token required (argv[5])', flush=True)
    sys.exit(2)

HOST_NAME    = socket.gethostname()
COOKIE_NAME  = 'nst'

PAGE_CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: #1c1c1e; color: #fff;
       font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
       padding: 20px; max-width: 640px; margin: 0 auto; }
h1   { color: #50c8a0; font-size: 1.4em; margin-bottom: 4px; }
.sub { color: #888; font-size: .85em; margin-bottom: 24px; }
.drop-zone {
    border: 2px dashed #444; border-radius: 12px;
    padding: 40px 20px; text-align: center; cursor: pointer;
    transition: border-color .2s, background .2s; margin-bottom: 12px; }
.drop-zone:hover, .drop-zone.drag { border-color: #50c8a0; background: #1e2e28; }
.drop-zone input { display: none; }
.drop-zone .icon { font-size: 2.2em; margin-bottom: 10px; }
.drop-zone p { color: #aaa; font-size: .9em; }
.drop-zone p span { color: #50c8a0; }
.btn { background: #50c8a0; color: #000; border: none; border-radius: 8px;
       padding: 12px 28px; font-size: 1em; font-weight: 600;
       cursor: pointer; width: 100%; margin-top: 10px; display: none; }
.btn:active { opacity: .8; }
.progress { display: none; margin-top: 16px; }
.progress-bar { background: #333; border-radius: 4px; height: 8px; overflow: hidden; }
.progress-fill { background: #50c8a0; height: 100%; width: 0%; transition: width .3s; }
.progress-text { color: #aaa; font-size: .85em; margin-top: 8px; text-align: center; }
.result { display: none; background: #1e2e28; border: 1px solid #2a5a40;
          border-radius: 8px; padding: 16px; margin-top: 16px; }
.result h3 { color: #50c8a0; margin-bottom: 6px; }
.result p  { color: #ccc; font-size: .9em; }
.section   { margin-top: 32px; }
.section h2 { color: #555; font-size: .75em; text-transform: uppercase;
              letter-spacing: .08em; margin-bottom: 10px;
              border-bottom: 1px solid #2a2a2c; padding-bottom: 8px; }
.file-item { display: flex; align-items: center;
             padding: 10px 0; border-bottom: 1px solid #222; }
.file-item a { color: #50c8a0; text-decoration: none; flex: 1; font-size: .95em; }
.file-item a:hover { text-decoration: underline; }
.file-size { color: #555; font-size: .8em; margin-left: 12px; white-space: nowrap; }
.empty     { color: #444; font-size: .9em; padding: 16px 0; }
"""

PAGE_JS = """
const dropZone  = document.getElementById('dropZone');
const fileInput = document.getElementById('fileInput');
const uploadBtn = document.getElementById('uploadBtn');
const progress  = document.getElementById('progress');
const fill      = document.getElementById('progressFill');
const pText     = document.getElementById('progressText');
const result    = document.getElementById('result');
const resultTxt = document.getElementById('resultText');
let files = [];

dropZone.addEventListener('click', () => fileInput.click());
fileInput.addEventListener('change', () => { files = Array.from(fileInput.files); showBtn(); });
dropZone.addEventListener('dragover',  e => { e.preventDefault(); dropZone.classList.add('drag'); });
dropZone.addEventListener('dragleave', () => dropZone.classList.remove('drag'));
dropZone.addEventListener('drop', e => {
    e.preventDefault(); dropZone.classList.remove('drag');
    files = Array.from(e.dataTransfer.files); showBtn();
});

function showBtn() {
    if (!files.length) return;
    uploadBtn.style.display = 'block';
    uploadBtn.textContent = files.length === 1
        ? 'Send "' + files[0].name + '"'
        : 'Send ' + files.length + ' files';
}

uploadBtn.addEventListener('click', async () => {
    if (!files.length) return;
    progress.style.display = 'block';
    result.style.display   = 'none';
    uploadBtn.disabled     = true;
    const names = [];
    for (let i = 0; i < files.length; i++) {
        pText.textContent = 'Sending ' + files[i].name + ' (' + (i+1) + '/' + files.length + ')...';
        fill.style.width  = (i / files.length * 80) + '%';
        const fd = new FormData();
        fd.append('file', files[i]);
        const r = await fetch('/upload', { method: 'POST', body: fd });
        const j = await r.json();
        names.push(j.name);
    }
    fill.style.width      = '100%';
    pText.textContent     = 'Done!';
    result.style.display  = 'block';
    resultTxt.textContent = names.join(', ') + ' — saved to Downloads/received/';
    uploadBtn.disabled    = false;
    files = [];
});
"""


def fmt_size(n):
    if n >= 1 << 20: return f"{n/(1<<20):.1f} MB"
    if n >= 1 << 10: return f"{n/(1<<10):.0f} KB"
    return f"{n} B"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _check_auth(self):
        # Returns 'query' if authed via ?t=, 'cookie' if via cookie, else False.
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        candidate = qs.get('t', [''])[0]
        if candidate and secrets.compare_digest(candidate, auth_token):
            return 'query'
        for piece in self.headers.get('Cookie', '').split(';'):
            piece = piece.strip()
            if piece.startswith(COOKIE_NAME + '='):
                if secrets.compare_digest(piece[len(COOKIE_NAME) + 1:], auth_token):
                    return 'cookie'
        return False

    def _send_auth_cookie(self):
        # Sticky cookie so post-scan follow-ups (uploads, file clicks) work.
        self.send_header('Set-Cookie',
                         f'{COOKIE_NAME}={auth_token}; Path=/; HttpOnly; SameSite=Lax')

    def do_GET(self):
        if not self._check_auth():
            self.send_error(403); return
        path = urllib.parse.unquote(self.path.split('?')[0]).lstrip('/')
        if path == '' or path == '/':
            self._serve_index(serve_dir)
            return
        target = (serve_dir / path).resolve()
        try:
            target.relative_to(serve_dir)
        except ValueError:
            self.send_error(403); return
        if target.is_dir():
            self._serve_index(target)
        elif target.is_file():
            self._serve_file(target)
        else:
            self.send_error(404)

    def do_POST(self):
        if not self._check_auth():
            self.send_error(403); return
        if self.path != '/upload':
            self.send_error(404); return
        try:
            length = int(self.headers.get('Content-Length', 0))
            body   = self.rfile.read(length)
            ct     = self.headers.get('Content-Type', '')
            bm     = re.search(r'boundary=([^\s;]+)', ct)
            saved  = []
            if bm:
                boundary = bm.group(1).encode()
                for part in body.split(b'--' + boundary):
                    if b'Content-Disposition' not in part: continue
                    disp_match = re.search(rb'filename="([^"]+)"', part)
                    if not disp_match: continue
                    fname = os.path.basename(disp_match.group(1).decode('utf-8', errors='replace'))
                    if not fname: continue
                    if b'\r\n\r\n' not in part: continue
                    data = part.split(b'\r\n\r\n', 1)[1]
                    if data.endswith(b'\r\n'): data = data[:-2]
                    out = drop_dir / fname
                    stem, suffix, n = out.stem, out.suffix, 1
                    while out.exists():
                        out = drop_dir / f"{stem}_{n}{suffix}"; n += 1
                    out.write_bytes(data)
                    saved.append(out.name)
            resp = json.dumps({'name': ', '.join(saved) or 'unknown'}).encode()
        except Exception as e:
            resp = json.dumps({'name': 'error', 'error': str(e)}).encode()
        self.send_response(200)
        self._send_auth_cookie()
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(resp))
        self.end_headers()
        self.wfile.write(resp)

    def _serve_file(self, path: Path):
        data = path.read_bytes()
        mime = mimetypes.guess_type(str(path))[0] or 'application/octet-stream'
        self.send_response(200)
        self._send_auth_cookie()
        self.send_header('Content-Type', mime)
        self.send_header('Content-Length', len(data))
        self.send_header('Content-Disposition', f'attachment; filename="{path.name}"')
        self.end_headers()
        self.wfile.write(data)

    def _serve_index(self, directory: Path):
        items = sorted(directory.iterdir(), key=lambda p: (p.is_file(), p.name.lower())) \
                if directory.exists() else []

        rows = []
        for item in items:
            if item.name.startswith('.'): continue
            rel = item.relative_to(serve_dir)
            name_e = html.escape(item.name)
            if item.is_dir():
                rows.append(f'<div class="file-item"><a href="/{rel}/">&#128193; {name_e}/</a></div>')
            else:
                sz = fmt_size(item.stat().st_size)
                rows.append(f'<div class="file-item">'
                             f'<a href="/{rel}" download>{name_e}</a>'
                             f'<span class="file-size">{sz}</span></div>')

        files_html = (''.join(rows) if rows
                      else '<p class="empty">Nothing here</p>')

        body = f"""<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>NetShare</title>
<style>{PAGE_CSS}</style>
</head><body>
<h1>NetShare</h1>
<p class="sub">Send files to {html.escape(HOST_NAME)}</p>
<div class="drop-zone" id="dropZone">
  <div class="icon">&#128193;</div>
  <p>Drop files here or <span>tap to browse</span></p>
  <input type="file" id="fileInput" multiple>
</div>
<button class="btn" id="uploadBtn"></button>
<div class="progress" id="progress">
  <div class="progress-bar"><div class="progress-fill" id="progressFill"></div></div>
  <div class="progress-text" id="progressText">Sending...</div>
</div>
<div class="result" id="result">
  <h3>&#10003; Received</h3>
  <p id="resultText"></p>
</div>
<div class="section">
  <h2>Files available</h2>
  {files_html}
</div>
<script>{PAGE_JS}</script>
</body></html>""".encode('utf-8')

        self.send_response(200)
        self._send_auth_cookie()
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', len(body))
        self.end_headers()
        self.wfile.write(body)


server = HTTPServer((bind_ip, port), Handler)
print(f'READY:{port}', flush=True)
server.serve_forever()
