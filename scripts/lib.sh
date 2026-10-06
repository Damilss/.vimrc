# shellcheck shell=bash disable=SC2034 # variables are used by the sourcing scripts
# Shared helpers for the scripts in this directory.  Sourced, not executed.
# Written for the Bash 3.2 that ships with macOS: no associative arrays,
# mapfile, ${var,,}, readlink -f, or GNU-only flags.

# Absolute, symlink-free path of the repository (the parent of scripts/).
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# The tracked vimrc that ~/.vimrc links to.
VIMRC_SRC="$REPO_DIR/.vimrc"
# vim-plug release fetched by install.sh.
PLUG_URL='https://raw.githubusercontent.com/junegunn/vim-plug/0.14.0/plug.vim'
# Vim to use; VIMRC_VIM overrides it (plain VIM is reserved by Vim itself).
VIM_BIN=${VIMRC_VIM:-vim}
# Plugins declared in .vimrc, as "<directory under ~/.vim/plugged>/<plugin file>".
PLUGIN_FILES='ale/plugin/ale.vim auto-pairs/plugin/auto-pairs.vim'

info() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

refuse_root() {
	if [ "$(id -u)" -eq 0 ]; then
		die "run this as your normal user, not root or sudo (it changes files in your HOME)."
	fi
}

# True if Vim's --version output lists +job, +channel, and +timers.
vim_has_async() {
	local version
	version=$("$VIM_BIN" --version 2>/dev/null) || return 1
	case "$version" in *+job*) ;; *) return 1 ;; esac
	case "$version" in *+channel*) ;; *) return 1 ;; esac
	case "$version" in *+timers*) ;; *) return 1 ;; esac
}

# Prints the clangd the vimrc would use: PATH first, then Homebrew LLVM.
find_clangd() {
	local prefix
	if command -v clangd >/dev/null 2>&1; then
		command -v clangd
		return 0
	fi
	if [ "$(uname -s)" = Darwin ] && command -v brew >/dev/null 2>&1; then
		prefix=$(brew --prefix llvm 2>/dev/null) || return 1
		if [ -x "$prefix/bin/clangd" ]; then
			printf '%s\n' "$prefix/bin/clangd"
			return 0
		fi
	fi
	return 1
}

# Moves $1 to "$1.backup.<timestamp>" (never reusing an existing name) and
# prints the new path.  Symlinks are moved as links; their targets are untouched.
backup_path() {
	local target=$1 dest n=1
	dest="$target.backup.$(date +%Y%m%d-%H%M%S)"
	while [ -e "$dest" ] || [ -L "$dest" ]; do
		dest="$target.backup.$(date +%Y%m%d-%H%M%S).$n"
		n=$((n + 1))
	done
	mv "$target" "$dest"
	printf '%s\n' "$dest"
}
