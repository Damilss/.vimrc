#!/usr/bin/env bash
# shellcheck disable=SC2088 # "~/" in messages is display text, not a path
# Debian 13 (trixie) setup: installs the apt packages with sudo, then runs
# install.sh and doctor.sh as your own user.  Run it as your normal user;
# only the apt-get commands use sudo.
set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
	cat <<EOF
Usage: $(basename "$0") [--extras] [--no-apt] [--skip-plugins]

  --extras        also install shellcheck (apt) and ruff (pipx; not packaged in trixie)
  --no-apt        skip apt-get (packages already installed by an administrator)
  --skip-plugins  passed to install.sh
EOF
}

PACKAGES='vim clangd git curl build-essential'
EXTRA_PACKAGES='shellcheck pipx'

EXTRAS=0
APT=1
SKIP_PLUGINS=0
while [ $# -gt 0 ]; do
	case $1 in
	--extras) EXTRAS=1 ;;
	--no-apt) APT=0 ;;
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
[ "$(uname -s)" = Linux ] || die "this script is for Debian; on macOS use setup-macos.sh."

if [ -r /etc/os-release ]; then
	# shellcheck disable=SC1091
	OS_ID=$(. /etc/os-release && printf '%s' "${ID:-}")
	# shellcheck disable=SC1091
	OS_CODENAME=$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")
	# shellcheck disable=SC1091
	OS_NAME=$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-unknown}")
	if [ "$OS_ID" != debian ]; then
		warn "written for Debian 13 (trixie); this is $OS_NAME.  Continuing; package names may differ."
	elif [ "$OS_CODENAME" != trixie ]; then
		warn "written for Debian 13 (trixie); this is $OS_NAME.  Continuing."
	fi
else
	warn '/etc/os-release not found; cannot confirm this is Debian.'
fi

if [ "$APT" -eq 1 ]; then
	command -v apt-get >/dev/null 2>&1 || die "apt-get not found; install these yourself and rerun with --no-apt: $PACKAGES"
	command -v sudo >/dev/null 2>&1 || die "sudo not found.  As root run:
  apt-get update && apt-get install -y $PACKAGES
then rerun this script as your user with --no-apt."
	pkgs=$PACKAGES
	[ "$EXTRAS" -eq 1 ] && pkgs="$pkgs $EXTRA_PACKAGES"
	info "sudo apt-get install $pkgs"
	sudo apt-get update
	# shellcheck disable=SC2086 # word splitting of the package list is intended
	sudo apt-get install -y $pkgs
fi

if [ "$EXTRAS" -eq 1 ]; then
	command -v pipx >/dev/null 2>&1 || die "pipx not found; install it (sudo apt-get install pipx) and rerun."
	if pipx list --short 2>/dev/null | grep -q '^ruff '; then
		info 'ruff already installed (pipx)'
	else
		info 'pipx install ruff'
		pipx install ruff
	fi
	case ":$PATH:" in
	*":$HOME/.local/bin:"*) ;;
	*) warn "~/.local/bin is not on PATH, so Vim will not find ruff.  Run 'pipx ensurepath' and open a new shell." ;;
	esac
fi

vim_has_async || die "$(command -v "$VIM_BIN" || echo "$VIM_BIN") lacks +job/+channel/+timers; install Debian's 'vim' package (not vim-tiny)."

if [ "$SKIP_PLUGINS" -eq 1 ]; then
	"$REPO_DIR/scripts/install.sh" --skip-plugins
else
	"$REPO_DIR/scripts/install.sh"
fi

info 'running doctor.sh'
"$REPO_DIR/scripts/doctor.sh"
