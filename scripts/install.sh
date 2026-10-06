#!/usr/bin/env bash
# shellcheck disable=SC2088 # "~/" in messages is display text, not a path
# Links ~/.vimrc to this repository's .vimrc, installs vim-plug, and installs
# the plugins the vimrc declares.  Installs no system packages (see
# setup-macos.sh / setup-debian.sh).  Safe to rerun: a correct link and an
# installed vim-plug are left alone.
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
	cat <<EOF
Usage: $(basename "$0") [--skip-plugins]

  --skip-plugins  only link ~/.vimrc; do not download vim-plug or plugins
EOF
}

SKIP_PLUGINS=0
while [ $# -gt 0 ]; do
	case $1 in
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
[ -n "${HOME:-}" ] && [ -d "$HOME" ] || die "HOME is not set to a directory."
[ -f "$VIMRC_SRC" ] || die "tracked vimrc not found: $VIMRC_SRC"

BACKUP=''
LINKED=0

link_vimrc() {
	local dest="$HOME/.vimrc"
	if [ -L "$dest" ] && [ "$dest" -ef "$VIMRC_SRC" ]; then
		info "~/.vimrc already links to $VIMRC_SRC"
		return
	fi
	if [ -d "$dest" ] && [ ! -L "$dest" ]; then
		die "$dest is a directory; move it out of the way yourself, then rerun."
	fi
	if [ -e "$dest" ] || [ -L "$dest" ]; then
		BACKUP=$(backup_path "$dest")
		info "moved the previous ~/.vimrc to $BACKUP"
	fi
	ln -s "$VIMRC_SRC" "$dest"
	LINKED=1
	info "linked ~/.vimrc -> $VIMRC_SRC"
}

install_plug() {
	local dir="$HOME/.vim/autoload" tmp
	if [ -s "$dir/plug.vim" ]; then
		info "vim-plug already installed at $dir/plug.vim"
		return
	fi
	command -v curl >/dev/null 2>&1 || die "curl is required to download vim-plug."
	mkdir -p "$dir"
	# Download next to the destination so the final mv is atomic.
	tmp=$(mktemp "$dir/.plug.vim.XXXXXX")
	if ! curl -fsSL --retry 2 -o "$tmp" "$PLUG_URL"; then
		rm -f "$tmp"
		die "could not download $PLUG_URL"
	fi
	if ! grep -q 'plug#begin' "$tmp"; then
		rm -f "$tmp"
		die "downloaded file is not vim-plug: $PLUG_URL"
	fi
	chmod 644 "$tmp"
	mv "$tmp" "$dir/plug.vim"
	info "installed vim-plug to $dir/plug.vim"
}

missing_plugins() {
	local f missing=''
	for f in $PLUGIN_FILES; do
		[ -f "$HOME/.vim/plugged/$f" ] || missing="$missing ${f%%/*}"
	done
	printf '%s' "${missing# }"
}

install_plugins() {
	local missing
	command -v "$VIM_BIN" >/dev/null 2>&1 || die "$VIM_BIN not found on PATH."
	command -v git >/dev/null 2>&1 || die "git is required to install plugins."
	info "installing plugins with $(command -v "$VIM_BIN") (PlugInstall --sync)"
	# Vim's exit status is not trusted on its own; the files are checked below.
	"$VIM_BIN" -Nu "$VIMRC_SRC" -i NONE -n -es \
		-c 'PlugInstall --sync' -c 'qa!' </dev/null >/dev/null 2>&1 || true
	missing=$(missing_plugins)
	if [ -n "$missing" ]; then
		warn "plugins not installed: $missing"
		warn "open vim and run :PlugInstall to see the error, then rerun this script."
		return 1
	fi
	info "plugins installed in $HOME/.vim/plugged"
}

link_vimrc
status=0
if [ "$SKIP_PLUGINS" -eq 0 ]; then
	install_plug
	install_plugins || status=1
fi

if [ -n "$BACKUP" ]; then
	cat <<EOF

Rollback (restores your previous ~/.vimrc):
  rm "$HOME/.vimrc" && mv "$BACKUP" "$HOME/.vimrc"
EOF
elif [ "$LINKED" -eq 1 ]; then
	cat <<EOF

Rollback (there was no previous ~/.vimrc):
  rm "$HOME/.vimrc"
EOF
fi
if [ "$SKIP_PLUGINS" -eq 0 ]; then
	cat <<EOF

To remove the plugins and vim-plug as well:
  rm -rf "$HOME/.vim/plugged" "$HOME/.vim/autoload/plug.vim"
EOF
fi
exit "$status"
