#!/usr/bin/env python3
"""hud-guide-server.py — serves the status HUD setup page to this machine only, so its Done button can save
the choices (orchestration-kit). Started by `scripts/hud-guide.sh open`; not meant to be run by hand.

  hud-guide-server.py --page FILE --guide hud-guide.sh --state DIR [--account DIR]... [--idle SECONDS]

Listens on 127.0.0.1 at a free port, under a random one-time path (http://127.0.0.1:<port>/<key>/).
Writes the URL to DIR/hud-guide.url once it listens. GET <key>/ serves the page; POST <key>/apply with
{"dotMode": ..., "hideItems": ...} runs `hud-guide.sh apply` once per account (DIR "default" = the default
account) and answers {"ok": bool, "message": str}. After a saved answer it writes DIR/hud-guide.result
("ok" or "failed", then the messages) and exits; a failed save keeps it listening so the page can retry.
It also exits after --idle seconds (default 3600) with no request, writing "timeout".
Refused: any other path, a Host or Origin that is not this server (another web page or a renamed address),
a body that is not JSON, larger than 4 KB, or holds anything but dotMode and hideItems.
"""
import argparse, json, os, secrets, subprocess, sys, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ap = argparse.ArgumentParser()
ap.add_argument('--page', required=True)
ap.add_argument('--guide', required=True)
ap.add_argument('--state', required=True)
ap.add_argument('--account', action='append', default=[])
ap.add_argument('--idle', type=float, default=3600)
a = ap.parse_args()
KEY = secrets.token_urlsafe(18)
ACCOUNTS = a.account or ['default']
last = [time.monotonic()]
done = threading.Event()


def finish(status, msg):
    tmp = os.path.join(a.state, 'hud-guide.result.tmp')
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write(status + '\n' + msg.rstrip() + '\n')
    os.replace(tmp, os.path.join(a.state, 'hud-guide.result'))
    done.set()


def apply(vals):
    out, ok = [], True
    for acct in ACCOUNTS:
        env = dict(os.environ)
        if acct == 'default':
            env.pop('CLAUDE_CONFIG_DIR', None)
        else:
            env['CLAUDE_CONFIG_DIR'] = acct
        r = subprocess.run(['bash', a.guide, 'apply', json.dumps(vals)], env=env, capture_output=True, text=True, timeout=120)
        who = 'the default account' if acct == 'default' else acct
        text = (r.stdout + r.stderr).strip()
        out.append(('%s: %s' % (who, text)) if len(ACCOUNTS) > 1 else text)
        ok = ok and r.returncode == 0
    return ok, '\n'.join(out)


class H(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, code, body, ctype='application/json'):
        b = body.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', ctype + '; charset=utf-8')
        self.send_header('Content-Length', str(len(b)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        self.wfile.write(b)

    def mine(self):
        port = self.server.server_address[1]
        ours = {'127.0.0.1:%d' % port, 'localhost:%d' % port}
        if self.headers.get('Host', '') not in ours:
            return False
        origin = self.headers.get('Origin')
        return origin is None or origin in {'http://' + h for h in ours}

    def do_GET(self):
        last[0] = time.monotonic()
        if not self.mine():
            return self.send(403, '{"ok":false,"message":"not this server"}')
        if self.path.split('?')[0] not in ('/%s/' % KEY, '/%s/index.html' % KEY):
            return self.send(404, '{"ok":false,"message":"not found"}')
        with open(a.page, encoding='utf-8') as f:
            self.send(200, f.read(), 'text/html')

    def do_POST(self):
        last[0] = time.monotonic()
        if not self.mine():
            return self.send(403, '{"ok":false,"message":"not this server"}')
        if self.path != '/%s/apply' % KEY:
            return self.send(404, '{"ok":false,"message":"not found"}')
        if not self.headers.get('Content-Type', '').startswith('application/json'):
            return self.send(415, '{"ok":false,"message":"send JSON"}')
        n = int(self.headers.get('Content-Length') or 0)
        if n <= 0 or n > 4096:
            return self.send(413, '{"ok":false,"message":"empty or too large"}')
        try:
            v = json.loads(self.rfile.read(n))
            assert isinstance(v, dict) and set(v) <= {'dotMode', 'hideItems'}
        except Exception:
            return self.send(400, json.dumps({'ok': False, 'message': 'only dotMode and hideItems can be saved here'}))
        ok, msg = apply(v)
        self.send(200, json.dumps({'ok': ok, 'message': msg}))
        if ok:
            finish('ok', msg)


srv = ThreadingHTTPServer(('127.0.0.1', 0), H)
srv.daemon_threads = True
url = 'http://127.0.0.1:%d/%s/' % (srv.server_address[1], KEY)
with open(os.path.join(a.state, 'hud-guide.url.tmp'), 'w', encoding='utf-8') as f:
    f.write(url + '\n')
os.replace(os.path.join(a.state, 'hud-guide.url.tmp'), os.path.join(a.state, 'hud-guide.url'))
threading.Thread(target=srv.serve_forever, daemon=True).start()
while not done.wait(1):
    if time.monotonic() - last[0] > a.idle:
        finish('timeout', 'The setup page closed after %d minutes without a Done.' % (a.idle // 60))
time.sleep(0.5)  # let the last answer reach the browser
srv.shutdown()
try:
    os.remove(os.path.join(a.state, 'hud-guide.url'))
except OSError:
    pass
sys.exit(0)
