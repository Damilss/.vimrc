#!/usr/bin/env python3
"""Spelling and grammar check of one Vim buffer by a local model via Ollama.

ALE runs this for markdown, text, and gitcommit buffers (see the grammar
section of the vimrc) with the buffer on stdin.  The buffer is split into
paragraphs.  Every paragraph already checked is answered from a cache; one
unchecked paragraph is sent to the model per run, the one under the cursor
first and then those visible in the window.  If more remain, the output says
so and the vimrc runs this again, so results fill in a paragraph at a time.
ALE kills this process when the buffer changes, which closes the connection
and makes Ollama stop generating.

Output is one JSON object per line:
  {"lnum", "col", "end_col", "type", "text", "wrong", "fix"}   an issue
  {"pending": true}                                            more to check
  {"status": "unreachable" | "no-model" | "error", "detail"}   nothing checked

Standard library only; runs on the Python 3.9 that ships with macOS.
"""

import argparse
import hashlib
import json
import os
import re
import socket
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

# Bump when the prompt or the cached format changes, so old answers are
# not reused.
PROMPT_VERSION = 1
MAX_BLOCK_LINES = 40
REQUEST_TIMEOUT = 60
CACHE_MAX_AGE = 30 * 86400
PRUNE_INTERVAL = 86400

WHAT = {
    'markdown': 'a Markdown document',
    'text': 'a plain-text document',
    'gitcommit': 'a git commit message',
}

SYSTEM_PROMPT = (
    'You proofread {what}. Report only definite spelling, grammar, and '
    'punctuation errors; never style, tone, or word choice. The text has '
    'numbered lines. For each error give: line (its number); wrong (the '
    'erroneous words copied exactly from that line: only the words that must '
    'change, but all of them, so that replacing wrong with fix alone corrects '
    'the error; if that is a short word that appears more than once on the '
    'line, include the next word too); fix (the replacement for wrong only); '
    'and kind. '
    'Ignore code, commands, file names, URLs, and technical terms. The last '
    'sentence may be unfinished; do not report that. Return an empty list if '
    'there are no errors.{extra}'
)

EXTRA = {
    'markdown': ' Markdown markup such as #, *, -, >, and links is not an error.',
    'gitcommit': (' Line 1 is a terse commit subject: a prefix such as "fix:" '
                  'or "feat:" and a lowercase start are fine there.'),
}

# One worked example, sent before the real text.  It shows the model how
# much text to quote, which made its fixes noticeably more accurate.
EXAMPLE_TEXT = ('1: Me and him goes to the libary every week, its open late.\n'
                '2: The results was better then we hoped, so we celebrate.')
EXAMPLE_REPLY = json.dumps({'issues': [
    {'line': 1, 'wrong': 'Me and him goes', 'fix': 'He and I go', 'kind': 'grammar'},
    {'line': 1, 'wrong': 'libary', 'fix': 'library', 'kind': 'spelling'},
    {'line': 1, 'wrong': 'its', 'fix': "it's", 'kind': 'punctuation'},
    {'line': 2, 'wrong': 'results was', 'fix': 'results were', 'kind': 'grammar'},
    {'line': 2, 'wrong': 'then', 'fix': 'than', 'kind': 'grammar'},
    {'line': 2, 'wrong': 'celebrate', 'fix': 'celebrated', 'kind': 'grammar'},
]})

SCHEMA = {
    'type': 'object',
    'properties': {
        'issues': {
            'type': 'array',
            'items': {
                'type': 'object',
                'properties': {
                    'line': {'type': 'integer'},
                    'wrong': {'type': 'string'},
                    'fix': {'type': 'string'},
                    'kind': {'type': 'string',
                             'enum': ['spelling', 'grammar', 'punctuation']},
                },
                'required': ['line', 'wrong', 'fix', 'kind'],
            },
        },
    },
    'required': ['issues'],
}

FENCE = re.compile(r'^ {0,3}(`{3,}|~{3,})')
SCISSORS = re.compile(r'^# -+ >8 -+$')
# Spans of a line whose words are not prose: inline code, URLs, link
# targets, autolinks, and HTML tags or comments.
PROTECTED = re.compile(
    r'(`+)[^`].*?\1'
    r'|https?://\S+'
    r'|\]\([^)]*\)'
    r'|<[^<>\s][^<>]*>'
)


class CheckError(Exception):
    """The model could not be asked; status is reported to Vim."""

    def __init__(self, status, detail):
        Exception.__init__(self, detail)
        self.status = status
        self.detail = detail


# ---------- Paragraphs ----------

def skipped_lines(lines, filetype):
    """Indices of lines that are not prose for this filetype."""
    skip = set()
    if filetype == 'gitcommit':
        for i, line in enumerate(lines):
            if SCISSORS.match(line):
                skip.update(range(i, len(lines)))
                break
            if line.startswith('#'):
                skip.add(i)
        return skip
    if filetype != 'markdown':
        return skip

    i = 0
    # YAML front matter.
    if lines and lines[0].strip() == '---':
        for j in range(1, len(lines)):
            if lines[j].strip() in ('---', '...'):
                skip.update(range(0, j + 1))
                i = j + 1
                break
    fence = None
    in_comment = False
    for k in range(i, len(lines)):
        line = lines[k]
        if fence:
            skip.add(k)
            m = FENCE.match(line)
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) \
                    and not line[m.end():].strip():
                fence = None
            continue
        if in_comment:
            skip.add(k)
            if '-->' in line:
                in_comment = False
            continue
        m = FENCE.match(line)
        if m:
            fence = m.group(1)
            skip.add(k)
        elif line.lstrip().startswith('|'):
            skip.add(k)
        elif '<!--' in line and '-->' not in line[line.index('<!--'):]:
            in_comment = True
            skip.add(k)
    return skip


def split_blocks(lines, filetype):
    """List of (first line index, [lines]) for each run of prose lines."""
    skip = skipped_lines(lines, filetype)
    blocks = []
    current = []
    start = 0
    for i, line in enumerate(lines):
        if i in skip or not line.strip():
            if current:
                blocks.append((start, current))
                current = []
            continue
        if not current:
            start = i
        current.append(line)
        if len(current) >= MAX_BLOCK_LINES:
            blocks.append((start, current))
            current = []
    if current:
        blocks.append((start, current))
    return blocks


# ---------- Locating the model's answers ----------

def protected_spans(line):
    return [m.span() for m in PROTECTED.finditer(line)]


def find_occurrences(line, wrong):
    """Start indices of wrong in line, whole words preferred."""
    starts = []
    pos = line.find(wrong)
    while pos >= 0:
        starts.append(pos)
        pos = line.find(wrong, pos + 1)
    whole = [s for s in starts
             if (s == 0 or not (line[s - 1].isalnum() and wrong[0].isalnum()))
             and (s + len(wrong) == len(line)
                  or not (line[s + len(wrong)].isalnum() and wrong[-1].isalnum()))]
    return whole or starts


def locate(block, issue, taken=()):
    """Return (line in block, char index) for a reported issue, or None.

    Positions in taken are skipped, so the same mistake reported twice on a
    line marks both places.
    """
    wrong = issue['wrong']
    line_no = issue['line'] - 1
    for candidate in (line_no, line_no - 1, line_no + 1):
        if not 0 <= candidate < len(block):
            continue
        text = block[candidate]
        spans = protected_spans(text)
        for start in find_occurrences(text, wrong):
            end = start + len(wrong)
            if (candidate, start) not in taken \
                    and not any(start < b and a < end for a, b in spans):
                return candidate, start
    return None


def clean_issues(block, raw):
    """Keep issues that point at real, unprotected text and change it."""
    issues = []
    seen = set()
    for item in raw if isinstance(raw, list) else []:
        if not isinstance(item, dict):
            continue
        wrong = item.get('wrong')
        fix = item.get('fix')
        line = item.get('line')
        kind = item.get('kind') if item.get('kind') in ('spelling', 'grammar', 'punctuation') else 'grammar'
        if not isinstance(wrong, str) or not isinstance(fix, str) or not isinstance(line, int):
            continue
        wrong = wrong.strip()
        if not wrong or wrong == fix.strip():
            continue
        found = locate(block, {'line': line, 'wrong': wrong}, seen)
        if found is None:
            continue
        seen.add(found)
        issues.append({'line': found[0], 'start': found[1], 'wrong': wrong,
                       'fix': fix.strip(), 'kind': kind})
    return issues


# ---------- Ollama ----------

def normalize_host(host):
    """Turn an OLLAMA_HOST-style value into a base URL a client can use."""
    host = (host or '').strip() or '127.0.0.1:11434'
    if '://' not in host:
        host = 'http://' + host
    parts = urllib.parse.urlsplit(host)
    name = parts.hostname or '127.0.0.1'
    if name in ('0.0.0.0', '::'):
        name = '127.0.0.1'
    port = parts.port or (443 if parts.scheme == 'https' else 11434)
    if ':' in name:
        name = '[' + name + ']'
    return '%s://%s:%d%s' % (parts.scheme, name, port, parts.path.rstrip('/'))


def keep_alive_value(value):
    return int(value) if re.match(r'^-?\d+$', value) else value


def ask_model(host, model, keep_alive, filetype, block):
    """Ask the model about one block; return its raw issue list."""
    numbered = '\n'.join('%d: %s' % (i + 1, line) for i, line in enumerate(block))
    body = {
        'model': model,
        'stream': False,
        'think': False,
        'format': SCHEMA,
        'keep_alive': keep_alive_value(keep_alive),
        'options': {'temperature': 0, 'num_ctx': 4096},
        'messages': [
            {'role': 'system', 'content': SYSTEM_PROMPT.format(
                what=WHAT.get(filetype, WHAT['text']), extra=EXTRA.get(filetype, ''))},
            {'role': 'user', 'content': EXAMPLE_TEXT},
            {'role': 'assistant', 'content': EXAMPLE_REPLY},
            {'role': 'user', 'content': numbered},
        ],
    }
    request = urllib.request.Request(
        host + '/api/chat', data=json.dumps(body).encode('utf-8'),
        headers={'Content-Type': 'application/json'})
    # No proxies: the model is local or on the LAN.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(request, timeout=REQUEST_TIMEOUT) as response:
            reply = json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        detail = e.read().decode('utf-8', 'replace')
        if e.code == 404 and 'not found' in detail:
            raise CheckError('no-model', 'model %s not found at %s' % (model, host))
        raise CheckError('error', 'HTTP %d from %s: %s' % (e.code, host, detail[:200]))
    except (urllib.error.URLError, OSError) as e:
        reason = getattr(e, 'reason', e)
        if isinstance(reason, socket.timeout):
            raise CheckError('error', 'no answer from %s within %d s' % (host, REQUEST_TIMEOUT))
        raise CheckError('unreachable', 'Ollama not reachable at %s (%s)' % (host, reason))
    except ValueError:
        return []
    try:
        return json.loads(reply['message']['content'])['issues']
    except (KeyError, TypeError, ValueError):
        # An unusable answer is cached as "no issues" so it is not retried
        # in a loop; editing the paragraph asks again.
        return []


# ---------- Cache ----------

def cache_dir():
    path = os.environ.get('VIMRC_GRAMMAR_CACHE')
    if not path:
        base = os.environ.get('XDG_CACHE_HOME') or os.path.expanduser('~/.cache')
        path = os.path.join(base, 'vimrc-grammar')
    return path


def cache_key(model, filetype, block):
    data = json.dumps([PROMPT_VERSION, model, filetype, block], ensure_ascii=False)
    return hashlib.sha256(data.encode('utf-8')).hexdigest()


def cache_read(directory, key):
    path = os.path.join(directory, key + '.json')
    try:
        with open(path, encoding='utf-8') as f:
            issues = json.load(f)
    except (OSError, ValueError):
        return None
    try:
        # Keep entries that are still used from being pruned.
        if time.time() - os.path.getmtime(path) > PRUNE_INTERVAL:
            os.utime(path)
    except OSError:
        pass
    return issues


def cache_write(directory, key, issues):
    """Write atomically, so a killed process never leaves half an entry."""
    try:
        os.makedirs(directory, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=directory, prefix='.tmp-')
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(issues, f, ensure_ascii=False)
        os.replace(tmp, os.path.join(directory, key + '.json'))
    except OSError:
        pass


def cache_prune(directory):
    """Once a day, delete entries unused for CACHE_MAX_AGE."""
    stamp = os.path.join(directory, '.pruned')
    now = time.time()
    try:
        if now - os.path.getmtime(stamp) < PRUNE_INTERVAL:
            return
    except OSError:
        pass
    try:
        for name in os.listdir(directory):
            path = os.path.join(directory, name)
            if (name.endswith('.json') or name.startswith('.tmp-')) \
                    and now - os.path.getmtime(path) > CACHE_MAX_AGE:
                os.remove(path)
        with open(stamp, 'w'):
            pass
    except OSError:
        pass


# ---------- Output ----------

def byte_col(line, index):
    """1-based byte column of the character at index."""
    return len(line[:index].encode('utf-8')) + 1


def typing_span(line, byte_column):
    """Character span of the word at or just before the cursor."""
    index = len(line.encode('utf-8')[:max(byte_column - 1, 0)].decode('utf-8', 'ignore'))
    start = index
    while start > 0 and not line[start - 1].isspace():
        start -= 1
    end = index
    while end < len(line) and not line[end].isspace():
        end += 1
    return start, end


def issue_output(lines, block_start, issue):
    lnum = block_start + issue['line']
    line = lines[lnum]
    start = issue['start']
    end = start + len(issue['wrong'])
    fix = issue['fix'] if issue['fix'] else '(delete)'
    return {
        'lnum': lnum + 1,
        'col': byte_col(line, start),
        'end_col': byte_col(line, end) - 1,
        'type': 'E' if issue['kind'] == 'spelling' else 'W',
        'text': '%s → %s (%s)' % (issue['wrong'], fix, issue['kind']),
        'wrong': issue['wrong'],
        'fix': issue['fix'],
    }


def check(text, filetype, model, host, keep_alive, top, bottom, cursor, insert):
    """Return the output objects for one run."""
    lines = text.split('\n')
    if text.endswith('\n'):
        lines.pop()
    directory = cache_dir()
    cache_prune(directory)
    cursor_line = cursor[0] - 1

    results = {}
    unchecked = []
    for index, (start, block) in enumerate(split_blocks(lines, filetype)):
        key = cache_key(model, filetype, block)
        issues = cache_read(directory, key)
        if issues is not None:
            results[index] = (start, issues)
            continue
        end = start + len(block) - 1
        if start <= cursor_line <= end:
            unchecked.insert(0, (index, start, block, key))
        elif start <= bottom - 1 and end >= top - 1:
            unchecked.append((index, start, block, key))

    output = []
    if unchecked:
        index, start, block, key = unchecked[0]
        try:
            issues = clean_issues(block, ask_model(host, model, keep_alive, filetype, block))
        except CheckError as e:
            output.append({'status': e.status, 'detail': e.detail})
        else:
            cache_write(directory, key, issues)
            results[index] = (start, issues)
            if len(unchecked) > 1:
                output.append({'pending': True})

    for index in sorted(results):
        start, issues = results[index]
        for issue in issues:
            item = issue_output(lines, start, issue)
            if insert and item['lnum'] == cursor[0]:
                line = lines[cursor_line]
                a, b = typing_span(line, cursor[1])
                if issue['start'] < b and a < issue['start'] + len(issue['wrong']):
                    continue
            output.append(item)
    return output


def parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--filetype', default='text')
    parser.add_argument('--model', default='qwen3.5:9b')
    parser.add_argument('--host', default=os.environ.get('OLLAMA_HOST', ''))
    parser.add_argument('--keep-alive', default='30m')
    parser.add_argument('--top', type=int, default=1)
    parser.add_argument('--bottom', type=int, default=1)
    parser.add_argument('--cursor', default='1:1')
    parser.add_argument('--insert', action='store_true')
    args = parser.parse_args(argv)
    try:
        line, col = (int(x) for x in args.cursor.split(':'))
    except ValueError:
        parser.error('--cursor must be LINE:COL')
    args.cursor = (line, col)
    return args


def main(argv=None):
    args = parse_args(sys.argv[1:] if argv is None else argv)
    text = sys.stdin.buffer.read().decode('utf-8', 'replace')
    output = check(text, args.filetype, args.model, normalize_host(args.host),
                   args.keep_alive, args.top, args.bottom, args.cursor, args.insert)
    for item in output:
        sys.stdout.write(json.dumps(item, ensure_ascii=False) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
