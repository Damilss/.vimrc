# Implementation status

The original requirements are in [CLAUDE_HANDOFF.md](../CLAUDE_HANDOFF.md). This page records what was actually done and how it was checked. Last updated 2026-10-07 (grammar checking, at the end of this page).

## Decisions that differ from the handoff

| Handoff | Done instead | Why |
| --- | --- | --- |
| "On macOS, use Homebrew Vim and LLVM" | Apple `/usr/bin/vim` 9.1 and Xcode clangd 21; Homebrew LLVM is only a fallback | Your choice. Apple Vim already has `+job +channel +timers`, Xcode clangd finds the SDK by itself, and `/opt/homebrew/bin` comes after `/usr/bin` on this PATH |
| C/C++ only | Also sh (shellcheck), Python (ruff, pyright if installed), Java (javac). JS/TS and SQL left out | Your request. `g:ale_linters_explicit = 1`, so no other filetype changes behavior |
| Ctrl-H as an auto-pairs Backspace (plugin default) | Turned off (`g:AutoPairsMapCh = 0`) | It would have overridden your existing `<C-H>` → `<C-W>` delete-word mapping |
| auto-pairs Alt shortcuts (plugin default) | Turned off | Terminal Vim receives Alt+key as 8-bit characters (`å`, `©`, …) |
| Fixed per-keystroke linting for all filetypes | Java waits 1500 ms (`b:ale_lint_delay`) | ALE v4.0.0 has no per-buffer `lint_on_text_changed`; javac is slow |

## Inventory before the change (verified)

- `.vimrc` was a single, plugin-free file with the theme, syntax links, and the `<M-BS>`/`<C-H>` Insert mappings.
- `~/.vimrc` was a regular file identical to the repo copy. It was not a symlink.
- No plugin manager, no `~/.vim/autoload`, no `pack/`.
- No install scripts. The README was two lines.

## Completed

- **`.vimrc`:**
  - A Plugins section (vim-plug; ALE v4.0.0 and auto-pairs pinned).
  - ALE options set before load, with the linter dictionary merged using `extend(..., 'keep')`.
  - Cached clangd discovery: override → PATH → `brew --prefix llvm`.
  - Buffer-local `gd`/`gr`/`K`/`]e`/`[e` in an idempotent `vimrc_ale` augroup.
  - Tab/Shift-Tab menu navigation.
  - ALE highlight links to the existing `Diagnostic*` palette.
  - A one-time hint when ALE or clangd is missing.
  - All existing lines and behavior are unchanged, apart from the header comment.
- **Scripts:** `scripts/lib.sh`, `install.sh`, `setup-macos.sh`, `setup-debian.sh`, `doctor.sh`, `smoke-test.sh`, and `tests/smoke.vim`.
- **Example:** `examples/c/` (vec.h, vec.c, main.c, Makefile, compile_flags.txt, README).
- **Docs:** README.md and docs/*.md. `.gitignore` covers .DS_Store, compile databases, and build output.

## Validation on macOS (this Mac, 2026-10-06)

Environment:
- macOS 26.7.1, arm64.
- Vim: `/usr/bin/vim` 9.1 (patches 1-1752).
- clangd: `/usr/bin/clangd` → Apple clangd 21.0.0.
- Compilers: Apple clang 21, Homebrew gcc-15.
- Shell: `/bin/bash` 3.2.57.

| # | Check | Result |
| --- | --- | --- |
| 1 | `bash -n` with `/bin/bash` 3.2 on every script | pass |
| 1 | ShellCheck 0.11.0 (`shellcheck -x scripts/*.sh`) | pass, no findings |
| 2 | Headless load of the vimrc without plugins, with plugins, without clangd (PATH=/bin), and without both | no errors. Editing works; hint names exactly what is missing |
| 3 | `install.sh` in temporary HOMEs, repo path and HOME path containing spaces, run from `/` | regular file → backed up once; rerun → no new backup; foreign symlink → moved, target untouched; dangling symlink → moved; unrelated `~/.vim` files kept; root refused |
| 3 | Plugin install in a temp HOME over the network | vim-plug 0.14.0, ALE `v4.0.0`, auto-pairs `39f06b8` |
| 4 | `scripts/setup-macos.sh --extras` on the real HOME | `brew install shellcheck ruff`. `~/.vimrc` moved to `~/.vimrc.backup.20261006-004241` and symlinked. Plugins installed. doctor: all required checks `[ok]` |
| 5 | `make` in `examples/c` with Apple clang and gcc-15, then run | no warnings; prints `10 squares, sum 385` |
| 6 | `clangd --check=main.c` | flags loaded from `compile_flags.txt`, 0 errors. With `int *oops = 3.5;` added: 1 error. Reverted: 0 |
| 7 | `scripts/smoke-test.sh`: real Vim in a pseudo-terminal, real HOME | **32/32 pass**: ALE+clangd attached; completion enabled before load; buffer maps; `<C-H>` still yours; Enter owned by auto-pairs; unsaved error reported and cleared on undo; `numbers.` offers data/len/cap; Tab+Ctrl-Y accepts; `gd` to the function declaration and the struct field; `K` popup; `gr` list; pairing `( [ { " '`, skip, Backspace, escaped quote, char literal, apostrophe, Enter-in-braces indent, plain Tab; re-source twice without duplicate autocmds; highlight links kept; `gd` default in other buffers; no `E` errors in `:messages` |
| 8 | Enter with the completion menu open, nothing selected | keeps typed text, inserts newline |
| 9 | ALE in other filetypes (real HOME) | sh → shellcheck SC2086; Python → ruff F401; Java → javac type error, `b:ale_lint_delay=1500` |

## Not verified / manual checks for you

These depend on your terminal and your eyes. Automated tests can't judge them.

- [ ] In your terminal (Ghostty), signs, undercurls and colors look right and are readable.
- [ ] Alt-Backspace and Ctrl-H still delete a word in your terminal.
- [ ] The hover popup and the current-line virtual text are readable and don't get in the way.
- [ ] Completion feels right while typing at normal speed (ALE waits 100 ms before asking clangd).
- [ ] Optional: `npm install -g pyright`, then check Python completion and `gd`.
- [ ] C++: not exercised by the example. Open a `.cpp` file with a `compile_flags.txt` containing e.g. `-std=c++20` and confirm diagnostics appear.

## Debian 13 (trixie): pending

Nothing has been run on Debian.

| Item | Status |
| --- | --- |
| Package names/versions on packages.debian.org (vim 9.1.1230, clangd 19, shellcheck 0.10.0, pipx 1.7.1, build-essential 12.12; ruff not packaged) | checked 2026-10-06 |
| `setup-debian.sh`: `bash -n` and ShellCheck | pass (on macOS) |
| `setup-debian.sh` run on Debian | **pending** |
| Debian `vim` provides `+job +channel +timers` | **pending** (script and doctor check it) |
| `doctor.sh` on Debian | **pending** |
| `smoke-test.sh` on Debian (util-linux `script -qec` branch untested) | **pending** |
| Interactive checks above, on Debian | **pending** |

## 2026-10-07: grammar checking (Markdown, text, git commits)

Added after the original handoff, at Emilio's request: spelling and grammar underlines from a local model.

### Decisions

| Choice | Why |
| --- | --- |
| Local model through Ollama, `qwen3.5:9b` | Benchmarked on this Mac against Vim's `spell` (3 of 10 planted mistakes), `qwen3.5:4b` (rewrote whole lines, nothing precise to underline), and `gemma4:12b` (41 s per paragraph). The 9B model found 9 of 10 with exact spans in 1 to 4 s per paragraph |
| An ALE linter plus `scripts/grammar_check.py`, no new plugin | Reuses ALE's pause timing, job cancellation, undercurls, signs, `]e`/`[e`, and `:ALEDetail`. Python standard library only, Python 3.9 compatible (macOS ships 3.9.6) |
| One paragraph per request: the cursor's, then the ones on screen | Sending a whole 30-line file found only 10 of 60 mistakes and took 13.5 s. Per paragraph is accurate, and progress shows sooner. Text off screen is never sent (Emilio's choice, to limit battery use) |
| Cache by paragraph text in `~/.cache/vimrc-grammar` | Unchanged paragraphs keep their underlines without asking again. Writes are atomic (temp file + rename), so a killed check leaves no partial entry |
| `exec` in the linter command | ALE's stop signal then reaches Python, the connection closes, and Ollama stops generating. Measured: a new check waited 22 s behind an uncancelled one and 0.5 s after a cancelled one |
| One worked example in the prompt | Without it the model split "works good" into wrong fixes ("work well"). With it, every fix in that test sentence was correct |
| Spelling = error, grammar/punctuation = warning | Both use the existing red undercurls (`DiagnosticUnderlineError`/`Warn`) |
| `z=` applies the fix; elsewhere it stays Vim's `z=` | Emilio keeps `spell` off and turns it on by hand with `:setlocal spell` |
| `~/.vimrc` replaced by a regular-file copy of `5b864e1` before any change | Emilio's request: the live config stays as it was until they have reviewed this work. `doctor.sh` therefore shows `[FAIL] ~/.vimrc ... not linked`; `scripts/install.sh` restores the link (backing up the copy) |

### Validation on macOS (2026-10-07)

Ollama 0.40.0, `qwen3.5:9b`, Vim 9.1, ALE v4.0.0. All runs used the repo vimrc via `vim -Nu`; `~/.vimrc` was verified unchanged (sha256 `aea4d7d5...`) before and after.

| # | Check | Result |
| --- | --- | --- |
| 1 | `python3 -I tests/test_grammar_check.py` (fake Ollama) | 23/23 pass: paragraph splitting (fences, front matter, tables, comments, git comments and scissors, 40-line cap), UTF-8 byte columns, whole-word matching, neighbor-line fallback, repeated mistakes, dropping unfound/no-op/code/URL spans, word at the cursor while typing, one request per run with cursor first, off-screen text not sent, cache hit, moved paragraph, model change, request shape, unreachable host, missing model, bad reply, atomic cache writes, host normalization |
| 2 | `scripts/smoke-test.sh` | **40/40 pass**: the 32 earlier steps, plus Markdown buffer gets the `grammar` linter, 1 s delay, `z=` and `]e`; a typed misspelling is underlined at the right columns as an error; `z=` fixes it; `u` restores it; `z=` away from an issue changes nothing; fenced code not checked; git commit `#` lines not checked; text buffers get the linter; re-sourcing does not duplicate the `vimrc_grammar` autocmds |
| 3 | `shellcheck -x scripts/*.sh`, `bash -n` (Bash 3.2), `py_compile` | pass |
| 4 | Real model in real Vim, 14-line Markdown note with a code block, inline code, and a URL | 13 issues, correct columns; nothing flagged in code or URLs; first underlines after 13 s (a paragraph with 9 mistakes), all done at 20 s |
| 5 | Real model, `COMMIT_EDITMSG` with typos from this repo's history | `brigthen`, `accidently`, `ajdust` flagged; `commment` missed; comment lines ignored |
| 6 | Cancellation: type a new paragraph while a long check runs | New paragraph underlined 3.7 s after typing (including the 1 s pause); never more than one helper process; none left after exit |
| 7 | `scripts/doctor.sh` | Grammar section lists python3, Ollama 0.40.0, and the model as `[opt]`; with `OLLAMA_HOST=127.0.0.1:9` it reports "not reachable" with the fix |

### Not verified / manual checks for you

- [ ] Review the diff, then re-link: `scripts/install.sh` (backs up the current `~/.vimrc` copy and restores the symlink).
- [ ] In Ghostty, the grammar undercurls and the current-line message are readable and not distracting.
- [ ] The 1 s pause feels right while writing (`g:vimrc_grammar_delay`).
- [ ] Battery and fan over a long writing session on battery.
- [ ] A real `git commit` opens Vim with underlines in the message.
- [ ] Debian/Pi: untested. See [setup-debian.md](setup-debian.md#grammar-checking-optional-not-yet-tested-on-debian).
