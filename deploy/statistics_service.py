"""First-party opt-in counters. No IP, device ID, cookie or raw-event archive."""
import argparse
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import re
import sqlite3
from contextlib import closing
from contextlib import contextmanager
from pathlib import Path

PLATFORMS = {'web', 'android', 'windows'}
KINDS = {'session', 'download'}

@contextmanager
def connect(path):
    db = sqlite3.connect(path, timeout=10)
    db.execute('CREATE TABLE IF NOT EXISTS counts (day TEXT, kind TEXT, platform TEXT, version TEXT, total INTEGER, PRIMARY KEY(day,kind,platform,version))')
    # Random per-event tokens only prevent duplicate retries. Never an install ID.
    db.execute('CREATE TABLE IF NOT EXISTS seen (token TEXT PRIMARY KEY, day TEXT)')
    try:
        with db: yield db
    finally: db.close()

def report(path):
    if not Path(path).exists(): return []
    with closing(sqlite3.connect(Path(path).resolve().as_uri()+'?mode=ro',uri=True)) as db:
        return [dict(zip(('day','kind','platform','version','total'), row)) for row in db.execute('SELECT * FROM counts ORDER BY day DESC,kind,platform,version')]

def handler(path):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args): pass  # Do not log client IPs or bodies.
        def answer(self, status, body):
            payload = json.dumps(body).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        def do_GET(self):
            self.answer(200 if self.path == '/api/stats/health' else 404, {'ok': self.path == '/api/stats/health'})
        def do_POST(self):
            if self.path != '/api/stats/events': return self.answer(404, {'error':'not_found'})
            # Browser callers must be our own site; native clients have no Origin.
            if self.headers.get('Origin') not in (None, 'https://sheepraider.nooxtools.me'):
                return self.answer(403, {'error':'origin'})
            try:
                size = int(self.headers.get('Content-Length', '0'))
                if not 0 < size <= 1024: raise ValueError()
                if self.headers.get_content_type() != 'application/json': raise ValueError()
                data = json.loads(self.rfile.read(size))
                if not isinstance(data, dict) or set(data) != {'kind','platform','version','event','consent'}: raise ValueError()
                if data['consent'] != 'v1' or data['kind'] not in KINDS or data['platform'] not in PLATFORMS: raise ValueError()
                if data['kind']=='download' and data['platform']=='web': raise ValueError()
                if not isinstance(data['version'],str) or not re.fullmatch(r'[A-Za-z0-9_.-]{1,40}',data['version']): raise ValueError()
                if not isinstance(data['event'],str) or not re.fullmatch(r'[a-f0-9]{32}',data['event']): raise ValueError()
            except (ValueError, TypeError, KeyError): return self.answer(400, {'error':'invalid_event'})
            today = datetime.now(timezone.utc).date().isoformat()
            with connect(path) as db:
                db.execute("DELETE FROM seen WHERE day < date(?, '-2 days')", (today,))
                cursor = db.execute('INSERT OR IGNORE INTO seen VALUES (?,?)', (data['event'],today))
                if cursor.rowcount:
                    db.execute('INSERT INTO counts VALUES (?,?,?,?,1) ON CONFLICT(day,kind,platform,version) DO UPDATE SET total=total+1', (today,data['kind'],data['platform'],data['version']))
            self.answer(202, {'accepted':True})
    return Handler

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database',type=Path,default=Path('/var/lib/ralphwolf-stats/counts.sqlite'))
    parser.add_argument('--port',type=int,default=4939)
    parser.add_argument('--report',action='store_true')
    args = parser.parse_args()
    if args.report: print(json.dumps(report(args.database),indent=2)); return
    with connect(args.database): pass
    ThreadingHTTPServer(('127.0.0.1',args.port),handler(args.database)).serve_forever()

if __name__=='__main__': main()
