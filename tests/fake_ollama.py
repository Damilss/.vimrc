#!/usr/bin/env python3
"""A stand-in for Ollama's HTTP API, for testing scripts/grammar_check.py.

/api/chat flags a fixed list of misspellings wherever they appear in the
last user message, so answers are instant and predictable.  A model named
"missing" gets Ollama's 404.  Every chat request is recorded.

Used in-process by tests/test_grammar_check.py, and as a server by
scripts/smoke-test.sh:  fake_ollama.py --port-file FILE
"""

import argparse
import json
import re
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

RULES = [
    ('grammer', 'grammar', 'spelling'),
    ('definately', 'definitely', 'spelling'),
    ('Their was', 'There was', 'grammar'),
]


def default_reply(text):
    issues = []
    for line in text.split('\n'):
        m = re.match(r'(\d+): (.*)$', line)
        if not m:
            continue
        for wrong, fix, kind in RULES:
            for _ in range(m.group(2).count(wrong)):
                issues.append({'line': int(m.group(1)), 'wrong': wrong,
                               'fix': fix, 'kind': kind})
    return {'issues': issues}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send_json(self, code, data):
        body = json.dumps(data).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == '/api/version':
            self.send_json(200, {'version': 'fake'})
        elif self.path == '/api/tags':
            self.send_json(200, {'models': [{'name': 'qwen3.5:9b'}]})
        else:
            self.send_json(404, {'error': 'not found'})

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        request = json.loads(self.rfile.read(length).decode('utf-8'))
        server = self.server
        server.requests.append(request)
        if self.path != '/api/chat':
            self.send_json(404, {'error': 'not found'})
            return
        if request.get('model') == 'missing':
            self.send_json(404, {'error': 'model "missing" not found, try pulling it first'})
            return
        text = request['messages'][-1]['content']
        if server.reply is not None:
            content = server.reply(text)
        else:
            content = json.dumps(default_reply(text))
        self.send_json(200, {'model': request.get('model'),
                             'message': {'role': 'assistant', 'content': content},
                             'done': True})


def start(port=0):
    """Start in a background thread; returns the server (url, requests, reply)."""
    server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
    server.requests = []
    # Set to a function(text) -> content string to override the answer.
    server.reply = None
    server.url = 'http://127.0.0.1:%d' % server.server_address[1]
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--port-file', required=True)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    server.requests = []
    server.reply = None
    with open(args.port_file, 'w') as f:
        f.write('%d\n' % server.server_address[1])
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == '__main__':
    sys.exit(main())
