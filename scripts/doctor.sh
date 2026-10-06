#!/usr/bin/env bash
# shellcheck disable=SC2088 # "~/" in messages is display text, not a path
# Read-only health check for this Vim setup.  Changes nothing.
#   [ok]    working
#   [FAIL]  required and missing/broken; makes the exit status nonzero
#   [opt]   optional (other languages, extra compilers); never affects status
set -u
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FAILED=0
ok() { printf '  [ok]   %s\n' "$1"; }
fail() {
	printf '  [FAIL] %s\n' "$1"
	[ -n "${2:-}" ] && printf '         -> %s\n' "$2"
	FAILED=1
}
opt() {
	printf '  [opt]  %s\n' "$1"
	[ -n "${2:-}" ] && printf '         -> %s\n' "$2"
}
section() { printf '\n%s\n' "$1"; }

OS=$(uname -s)
if [ "$OS" = Darwin ]; then
	SETUP="$REPO_DIR/scripts/setup-macos.sh"
else
	SETUP="$REPO_DIR/scripts/setup-debian.sh"
fi

# Asks Vim, loading the tracked vimrc, to evaluate an expression.
vim_eval() {
	local out status
	out=$(mktemp "${TMPDIR:-/tmp}/vimrc-doctor.XXXXXX") || return 1
	"$VIM_BIN" -Nu "$VIMRC_SRC" -i NONE -n -es \
		-c "call writefile([string($1)], '$out')" -c 'qa!' </dev/null >/dev/null 2>&1
	status=$?
	cat "$out"
	rm -f "$out"
	return $status
}

section 'Vim'
if VIM_PATH=$(command -v "$VIM_BIN" 2>/dev/null); then
	ok "$VIM_PATH: $("$VIM_BIN" --version | head -n 1)"
	if vim_has_async; then
		ok 'features +job +channel +timers (needed by ALE)'
	else
		fail 'Vim lacks +job, +channel, or +timers' "install a full Vim build (run $SETUP)"
	fi
else
	fail "$VIM_BIN not found on PATH" "run $SETUP"
fi

section 'Configuration'
if [ -L "$HOME/.vimrc" ] && [ "$HOME/.vimrc" -ef "$VIMRC_SRC" ]; then
	ok "~/.vimrc -> $VIMRC_SRC"
elif [ -e "$HOME/.vimrc" ]; then
	fail "~/.vimrc exists but is not linked to $VIMRC_SRC" "run $REPO_DIR/scripts/install.sh (it backs up the current file)"
else
	fail '~/.vimrc does not exist' "run $REPO_DIR/scripts/install.sh"
fi
if [ -s "$HOME/.vim/autoload/plug.vim" ]; then
	ok 'vim-plug: ~/.vim/autoload/plug.vim'
else
	fail 'vim-plug is not installed' "run $REPO_DIR/scripts/install.sh"
fi
for f in $PLUGIN_FILES; do
	name=${f%%/*}
	if [ -f "$HOME/.vim/plugged/$f" ]; then
		rev=$(git -C "$HOME/.vim/plugged/$name" describe --tags --always 2>/dev/null || echo '?')
		ok "plugin $name ($rev)"
	else
		fail "plugin $name is not installed" "run $REPO_DIR/scripts/install.sh, or :PlugInstall in Vim"
	fi
done
if command -v "$VIM_BIN" >/dev/null 2>&1; then
	if ale_loaded=$(vim_eval "exists(':ALEInfo')"); then
		ok 'vimrc loads without errors'
	else
		fail 'vimrc reported errors while loading' "run: $VIM_BIN -Nu \"$VIMRC_SRC\" and read :messages"
	fi
	if [ "$ale_loaded" = 2 ]; then
		ok 'ALE is loaded by the vimrc'
	else
		fail 'ALE does not load from the vimrc' "run $REPO_DIR/scripts/install.sh"
	fi
fi

section 'C/C++ language server'
if CLANGD=$(find_clangd); then
	ok "clangd: $CLANGD ($("$CLANGD" --version 2>/dev/null | head -n 1))"
	if command -v "$VIM_BIN" >/dev/null 2>&1; then
		vim_clangd=$(vim_eval "get(g:, 'ale_c_clangd_executable', '')")
		ok "vimrc gives ALE: $vim_clangd"
	fi
elif [ "$OS" = Darwin ]; then
	fail 'clangd not found on PATH or in Homebrew LLVM' 'install Xcode Command Line Tools (xcode-select --install) or: brew install llvm'
else
	fail 'clangd not found on PATH' 'sudo apt-get install clangd'
fi

section 'Compilers and headers'
if command -v cc >/dev/null 2>&1; then
	ok "cc: $(cc --version 2>/dev/null | head -n 1)"
else
	fail 'no C compiler (cc)' "run $SETUP"
fi
if [ "$OS" = Darwin ]; then
	if CLT=$(xcode-select -p 2>/dev/null); then
		ok "developer tools: $CLT"
	else
		fail 'Xcode Command Line Tools are not installed' 'xcode-select --install'
	fi
	if SDK=$(xcrun --show-sdk-path 2>/dev/null) && [ -f "$SDK/usr/include/stdio.h" ]; then
		ok "macOS SDK: $SDK"
	else
		fail 'no macOS SDK with C headers found' 'xcode-select --install, or xcode-select -s to the installed Xcode'
	fi
	GCC=''
	for g in /opt/homebrew/bin/gcc-[0-9]* /usr/local/bin/gcc-[0-9]*; do
		if [ -x "$g" ]; then
			GCC=$g
			break
		fi
	done
	if [ -n "$GCC" ]; then
		opt "GNU gcc: $GCC (plain gcc on macOS is Apple clang)"
	else
		opt 'GNU gcc not installed (plain gcc on macOS is Apple clang)' 'brew install gcc'
	fi
else
	if command -v gcc >/dev/null 2>&1; then ok "gcc: $(gcc --version | head -n 1)"; else fail 'gcc not installed' 'sudo apt-get install build-essential'; fi
	if [ -f /usr/include/stdio.h ]; then ok 'C headers: /usr/include/stdio.h'; else fail 'C library headers missing' 'sudo apt-get install build-essential'; fi
	if command -v clang >/dev/null 2>&1; then opt "clang: $(clang --version | head -n 1)"; else opt 'clang not installed' 'sudo apt-get install clang'; fi
fi
if command -v make >/dev/null 2>&1; then ok 'make'; else fail 'make not installed' "run $SETUP"; fi

section 'Other languages (optional; ALE skips missing tools)'
if command -v shellcheck >/dev/null 2>&1; then
	opt "sh: shellcheck $(shellcheck --version | sed -n 's/^version: //p')"
else
	opt 'sh: shellcheck not installed' "$SETUP --extras"
fi
if command -v ruff >/dev/null 2>&1; then
	opt "python: $(ruff --version)"
else
	opt 'python: ruff not installed' "$SETUP --extras"
fi
if command -v pyright-langserver >/dev/null 2>&1; then
	opt 'python: pyright-langserver (completion, gd/gr/K)'
else
	opt 'python: pyright not installed (no completion or gd/gr/K in Python)' 'npm install -g pyright'
fi
if command -v javac >/dev/null 2>&1; then
	opt "java: $(javac -version 2>&1 | head -n 1)"
else
	opt 'java: javac not installed' 'install a JDK'
fi

printf '\n'
if [ "$FAILED" -eq 0 ]; then
	echo 'All required checks passed.'
else
	echo 'Some required checks failed (see [FAIL] above).'
fi
exit "$FAILED"
