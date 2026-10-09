#!/usr/bin/env bash
# Runs tests/smoke.vim: real Vim, the tracked vimrc, the installed plugins,
# and clangd against examples/c, inside a pseudo-terminal (via script(1)) so
# typing, timers, and ALE behave as in an interactive session.
# Requires install.sh to have run.  Modifies no files in the repository.
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v "$VIM_BIN" >/dev/null 2>&1 || die "$VIM_BIN not found on PATH."
command -v script >/dev/null 2>&1 || die "script(1) is required (macOS: built in; Debian: bsdutils)."

OUT=$(mktemp "${TMPDIR:-/tmp}/vimrc-smoke.XXXXXX")
GRAMMAR_DIR=$(mktemp -d "${TMPDIR:-/tmp}/vimrc-grammar.XXXXXX")
FAKE_PID=''
cleanup() {
	rm -f "$OUT"
	if [ -n "$FAKE_PID" ]; then
		kill "$FAKE_PID" 2>/dev/null || true
		wait "$FAKE_PID" 2>/dev/null || true
	fi
	rm -rf "$GRAMMAR_DIR"
}
trap cleanup EXIT
export VIMRC_SMOKE_OUT="$OUT"

# The grammar steps talk to tests/fake_ollama.py instead of a real model, and
# use a throwaway cache.  Without python3 they are skipped.
if command -v python3 >/dev/null 2>&1; then
	python3 -I "$REPO_DIR/tests/fake_ollama.py" --port-file "$GRAMMAR_DIR/port" &
	FAKE_PID=$!
	for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
		[ -s "$GRAMMAR_DIR/port" ] && break
		sleep 0.25
	done
	[ -s "$GRAMMAR_DIR/port" ] || die "fake Ollama (tests/fake_ollama.py) did not start."
	read -r PORT <"$GRAMMAR_DIR/port"
	export VIMRC_SMOKE_GRAMMAR_HOST="http://127.0.0.1:$PORT"
	export VIMRC_GRAMMAR_CACHE="$GRAMMAR_DIR/cache"
else
	warn "python3 not found; skipping the grammar steps"
fi

cd "$REPO_DIR/examples/c"
set -- "$VIM_BIN" -Nu "$VIMRC_SRC" -i NONE -n main.c -c "source $(printf '%q' "$REPO_DIR/tests/smoke.vim")"

info "running Vim in a pseudo-terminal (up to 3 minutes)"
if [ "$(uname -s)" = Darwin ]; then
	script -q /dev/null "$@" </dev/null >/dev/null 2>&1 || true
else
	# util-linux script takes the command as one shell string.
	script -qec "$(printf '%q ' "$@")" /dev/null </dev/null >/dev/null 2>&1 || true
fi

[ -s "$OUT" ] || die "Vim exited without writing results."
cat "$OUT"
tail -n 1 "$OUT" | grep -q 'RESULT: PASS'
