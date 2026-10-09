#!/usr/bin/env python3
"""Tests for scripts/grammar_check.py against tests/fake_ollama.py.

Run:  python3 -I tests/test_grammar_check.py
No model, network, or real cache is used.
"""

import io
import json
import os
import shutil
import sys
import tempfile
import unittest

# Keep __pycache__ out of the repository on Linux.
sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'scripts'))
sys.path.insert(0, HERE)

import fake_ollama  # noqa: E402
import grammar_check as g  # noqa: E402


class Base(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = fake_ollama.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def setUp(self):
        self.cache = tempfile.mkdtemp(prefix='grammar-test-')
        os.environ['VIMRC_GRAMMAR_CACHE'] = self.cache
        self.server.requests.clear()
        self.server.reply = None

    def tearDown(self):
        shutil.rmtree(self.cache, ignore_errors=True)

    def run_check(self, text, filetype='markdown', top=1, bottom=100, cursor=(1, 1),
                  insert=False, model='qwen3.5:9b', host=None):
        return g.check(text, filetype, model, host or self.server.url, '30m',
                       top, bottom, cursor, insert)

    def issues(self, output):
        return [o for o in output if 'lnum' in o]

    def check_all(self, text, **kw):
        """Run until nothing is pending, like the vimrc's re-queue."""
        for _ in range(50):
            output = self.run_check(text, **kw)
            if not any(o.get('pending') for o in output):
                return output
        self.fail('still pending after 50 runs')


class Blocks(Base):
    def blocks(self, text, filetype):
        return [(s, b) for s, b in g.split_blocks(text.split('\n'), filetype)]

    def test_paragraphs(self):
        text = 'one\ntwo\n\nthree\n'
        self.assertEqual(self.blocks(text, 'text'), [(0, ['one', 'two']), (3, ['three'])])

    def test_markdown_skips_code_front_matter_tables_comments(self):
        text = '\n'.join([
            '---', 'title: grammer', '---',          # 0-2 front matter
            'Prose one.',                            # 3
            '```c', 'int grammer;', '', '```',       # 4-7 fence with blank line
            '~~~~', '```', 'still code', '~~~~',     # 8-11 tilde fence holding ```
            '| a | grammer |',                       # 12 table
            '<!--', 'grammer', '-->',                # 13-15 comment
            'Prose two.',                            # 16
        ])
        self.assertEqual(self.blocks(text, 'markdown'), [(3, ['Prose one.']), (16, ['Prose two.'])])

    def test_gitcommit_skips_comments_and_scissors(self):
        text = '\n'.join([
            'fix: subject', '', 'Body line.', '# Please enter the commit message',
            '# ------------------------ >8 ------------------------',
            'diff --git a/x b/x', '+grammer',
        ])
        self.assertEqual(self.blocks(text, 'gitcommit'), [(0, ['fix: subject']), (2, ['Body line.'])])

    def test_long_blocks_are_split(self):
        text = '\n'.join('line %d' % i for i in range(g.MAX_BLOCK_LINES + 5))
        blocks = self.blocks(text, 'text')
        self.assertEqual([len(b) for _, b in blocks], [g.MAX_BLOCK_LINES, 5])


class Locate(Base):
    def test_utf8_byte_columns(self):
        out = self.issues(self.check_all('Café ☕ grammer here'))
        self.assertEqual(len(out), 1)
        # é takes 2 bytes and ☕ 3, so columns are not character counts.
        prefix = 'Café ☕ '.encode('utf-8')
        self.assertEqual(out[0]['col'], len(prefix) + 1)
        self.assertEqual(out[0]['end_col'], len(prefix) + len('grammer'))
        self.assertEqual(out[0]['type'], 'E')
        self.assertEqual(out[0]['text'], 'grammer → grammar (spelling)')

    def test_whole_word_preferred(self):
        block = ['this is it']
        self.assertEqual(g.locate(block, {'line': 1, 'wrong': 'is'}), (0, 5))

    def test_neighbor_line_fallback(self):
        block = ['first line', 'has grammer']
        self.assertEqual(g.locate(block, {'line': 1, 'wrong': 'grammer'}), (1, 4))

    def test_drops_missing_noop_and_protected(self):
        block = ['Use `grammer` at https://x.io/grammer or [link](grammer) but grammer']
        raw = [
            {'line': 1, 'wrong': 'nowhere', 'fix': 'x', 'kind': 'spelling'},
            {'line': 1, 'wrong': 'Use', 'fix': 'Use', 'kind': 'grammar'},
            {'line': 1, 'wrong': 'grammer', 'fix': 'grammar', 'kind': 'spelling'},
            {'line': 1, 'wrong': 'grammer', 'fix': 'grammar', 'kind': 'spelling'},
            'not a dict',
            {'line': 'one', 'wrong': 'x', 'fix': 'y'},
        ]
        issues = g.clean_issues(block, raw)
        self.assertEqual(len(issues), 1)
        self.assertEqual(issues[0]['start'], block[0].rindex('grammer'))

    def test_repeated_mistake_marks_each_place(self):
        raw = [{'line': 1, 'wrong': 'teh', 'fix': 'the', 'kind': 'spelling'}] * 3
        issues = g.clean_issues(['teh cat and teh dog'], raw)
        self.assertEqual([i['start'] for i in issues], [0, 12])

    def test_unknown_kind_becomes_grammar_warning(self):
        issues = g.clean_issues(['a b c'], [{'line': 1, 'wrong': 'b', 'fix': 'B', 'kind': 'style'}])
        self.assertEqual(issues[0]['kind'], 'grammar')

    def test_insert_mode_hides_word_being_typed(self):
        text = 'A grammer and grammer'
        # Cursor right after the second word (byte column 22, past the end).
        out = self.issues(self.check_all(text, cursor=(1, 22), insert=True))
        self.assertEqual([o['col'] for o in out], [3])
        out = self.issues(self.check_all(text, cursor=(1, 22), insert=False))
        self.assertEqual([o['col'] for o in out], [3, 15])


class Scheduling(Base):
    TEXT = '\n'.join(['Para one grammer.', '', 'Para two.', '', 'Para three definately.',
                      '', 'Para four.'])

    def test_one_request_per_run_cursor_first_then_pending(self):
        out = self.run_check(self.TEXT, top=1, bottom=7, cursor=(5, 1))
        self.assertEqual(len(self.server.requests), 1)
        self.assertIn('Para three', self.server.requests[0]['messages'][-1]['content'])
        self.assertTrue(any(o.get('pending') for o in out))
        self.assertEqual([o['lnum'] for o in self.issues(out)], [5])

    def test_only_visible_paragraphs_are_checked(self):
        self.check_all(self.TEXT, top=1, bottom=3, cursor=(1, 1))
        sent = [r['messages'][-1]['content'] for r in self.server.requests]
        self.assertEqual(len(sent), 2)
        self.assertFalse(any('Para three' in s or 'Para four' in s for s in sent))

    def test_cache_answers_without_requests(self):
        first = self.check_all(self.TEXT, top=1, bottom=7)
        count = len(self.server.requests)
        self.assertEqual(count, 4)
        second = self.run_check(self.TEXT, top=1, bottom=7)
        self.assertEqual(len(self.server.requests), count)
        self.assertEqual(self.issues(first), self.issues(second))
        self.assertEqual([o['lnum'] for o in self.issues(second)], [1, 5])

    def test_cache_survives_moved_paragraph(self):
        self.check_all('Para one grammer.')
        out = self.run_check('New first line.\n\nPara one grammer.', cursor=(1, 1), bottom=1)
        self.assertEqual([o['lnum'] for o in self.issues(out)], [3])

    def test_model_change_misses_cache(self):
        self.check_all('Para one grammer.')
        self.check_all('Para one grammer.', model='other-model')
        self.assertEqual(len(self.server.requests), 2)

    def test_request_shape(self):
        self.check_all('Para one grammer.', filetype='gitcommit')
        r = self.server.requests[0]
        self.assertEqual(r['think'], False)
        self.assertEqual(r['options'], {'temperature': 0, 'num_ctx': 4096})
        self.assertEqual(r['keep_alive'], '30m')
        self.assertIn('git commit message', r['messages'][0]['content'])
        self.assertEqual(r['messages'][-1]['content'], '1: Para one grammer.')


class Failures(Base):
    def test_unreachable(self):
        out = self.run_check('Some grammer.', host='http://127.0.0.1:9')
        self.assertEqual([o.get('status') for o in out], ['unreachable'])
        self.assertFalse([n for n in os.listdir(self.cache) if n.endswith('.json')])

    def test_missing_model(self):
        out = self.run_check('Some grammer.', model='missing')
        self.assertEqual([o.get('status') for o in out], ['no-model'])

    def test_bad_reply_cached_as_empty(self):
        self.server.reply = lambda text: 'not json'
        out = self.run_check('Some grammer.')
        self.assertEqual(out, [])
        self.server.reply = None
        self.run_check('Some grammer.')
        self.assertEqual(len(self.server.requests), 1)

    def test_cache_writes_leave_no_temp_files(self):
        self.check_all('One grammer.\n\nTwo.')
        names = os.listdir(self.cache)
        self.assertTrue(all(n.endswith('.json') or n == '.pruned' for n in names), names)


class Host(unittest.TestCase):
    def test_normalize(self):
        self.assertEqual(g.normalize_host(''), 'http://127.0.0.1:11434')
        self.assertEqual(g.normalize_host('0.0.0.0'), 'http://127.0.0.1:11434')
        self.assertEqual(g.normalize_host('192.168.1.5:11434'), 'http://192.168.1.5:11434')
        self.assertEqual(g.normalize_host('http://mac.local'), 'http://mac.local:11434')
        self.assertEqual(g.normalize_host('https://ollama.example/'), 'https://ollama.example:443')
        self.assertEqual(g.normalize_host('[::1]:11434'), 'http://[::1]:11434')


class Main(Base):
    def test_main_prints_json_lines(self):
        stdin, stdout = sys.stdin, sys.stdout
        sys.stdin = io.TextIOWrapper(io.BytesIO('Some grammer.\n'.encode('utf-8')))
        sys.stdout = io.StringIO()
        try:
            g.main(['--filetype', 'text', '--host', self.server.url, '--cursor', '1:1'])
            lines = sys.stdout.getvalue().splitlines()
        finally:
            sys.stdin, sys.stdout = stdin, stdout
        self.assertEqual([json.loads(line)['wrong'] for line in lines], ['grammer'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
