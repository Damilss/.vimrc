#!/usr/bin/env bash
# macOS setup: checks the developer tools, Vim, and clangd, installs what is
# missing with Homebrew, then runs install.sh and doctor.sh.
#
# Uses the Vim and clangd already on PATH (normally Apple's /usr/bin/vim and
# Xcode's clangd).  Homebrew LLVM is installed only if no clangd is found.
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
	cat <<EOF
Usage: $(basename "$0") [--extras] [--skip-plugins]

  --extras        also brew install shellcheck and ruff (sh and Python linting)
  --skip-plugins  passed to install.sh
EOF
}

EXTRAS=0
SKIP_PLUGINS=0
while [ $# -gt 0 ]; do
	case $1 in
	--extras) EXTRAS=1 ;;
	--skip-plugins) SKIP_PLUGINS=1 ;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage >&2
		die "unknown option: $1"
		;;
	esac
	shift
done

refuse_root
[ "$(uname -s)" = Darwin ] || die "this script is for macOS; on Debian use setup-debian.sh."

have_brew() { command -v brew >/dev/null 2>&1; }
need_brew() {
	have_brew || die "Homebrew is required to install $1.
Install it yourself from https://brew.sh (review the installer first), then rerun this script."
}
brew_install() {
	local f
	for f in "$@"; do
		if brew list --formula "$f" >/dev/null 2>&1; then
			info "$f already installed (Homebrew)"
		else
			info "brew install $f"
			brew install "$f"
		fi
	done
}

info 'checking Xcode Command Line Tools'
if ! xcode-select -p >/dev/null 2>&1; then
	die "Command Line Tools are not installed.  Run:
  xcode-select --install
finish the installer window, then rerun this script."
fi
SDK=$(xcrun --show-sdk-path 2>/dev/null) || die "no macOS SDK found; run: xcode-select --install"
info "SDK: $SDK"

info 'checking Vim'
command -v "$VIM_BIN" >/dev/null 2>&1 || die "$VIM_BIN not found on PATH."
if ! vim_has_async; then
	die "$(command -v "$VIM_BIN") lacks +job/+channel/+timers, which ALE needs.
Install Homebrew Vim (brew install vim) and rerun with VIMRC_VIM=\$(brew --prefix)/bin/vim."
fi
info "Vim: $(command -v "$VIM_BIN")"

info 'checking clangd'
if ! CLANGD=$(find_clangd); then
	need_brew llvm
	brew_install llvm
	CLANGD=$(find_clangd) || die "clangd still not found after installing llvm."
fi
info "clangd: $CLANGD"

if [ "$EXTRAS" -eq 1 ]; then
	need_brew 'shellcheck and ruff'
	brew_install shellcheck ruff
fi

if [ "$SKIP_PLUGINS" -eq 1 ]; then
	"$REPO_DIR/scripts/install.sh" --skip-plugins
else
	"$REPO_DIR/scripts/install.sh"
fi

info 'running doctor.sh'
"$REPO_DIR/scripts/doctor.sh"
