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
trap 'rm -f "$OUT"' EXIT
export VIMRC_SMOKE_OUT="$OUT"

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
