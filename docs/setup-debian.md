# Debian 13 (trixie) setup

> **Status: written and checked (`bash -n`, ShellCheck) on macOS only. Not yet run on Debian.**
> Package names were checked on packages.debian.org (2026-10-06): `vim` 9.1.1230, `clangd` 19, `shellcheck` 0.10.0, `pipx` 1.7.1, `build-essential` 12.12.
> `ruff` is not packaged for trixie, so `--extras` installs it with pipx.

## Packages

| Package | Why |
| --- | --- |
| `vim` | Full Vim with `+job +channel +timers`. Not `vim-tiny`, which lacks them |
| `clangd` | C/C++ language server (pulls in clangd-19) |
| `git` | vim-plug clones plugins with git |
| `curl` | downloads vim-plug |
| `build-essential` | gcc, make, libc headers |
| `shellcheck`, `pipx` (with `--extras`) | sh linting; pipx installs ruff for Python |

## Install sequence

Run as your normal user. Only the `apt-get` commands use `sudo`.

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/damilss/.vimrc.git ~/vsprojects/.vimrc
~/vsprojects/.vimrc/scripts/setup-debian.sh            # core
~/vsprojects/.vimrc/scripts/setup-debian.sh --extras   # also shellcheck + ruff
```

The script runs these steps:

1. It reads `/etc/os-release` and warns, without stopping, if this isn't Debian trixie.
2. It runs `sudo apt-get update` and `sudo apt-get install -y vim clangd git curl build-essential`. With `--extras` it also installs `shellcheck pipx`.
3. With `--extras`, it runs `pipx install ruff` unless ruff is already installed. If `~/.local/bin` is not on PATH, it warns you to run `pipx ensurepath`.
4. It checks that `vim` has the async features.
5. It runs `scripts/install.sh`, the same installer as on macOS. That links `~/.vimrc`, backs up any previous one, and installs vim-plug and the plugins.
6. It runs `scripts/doctor.sh`.

If someone else administers the machine and you can't use sudo, have them install the packages, then run `setup-debian.sh --no-apt`.

Optional extras:

- Python completion: `sudo apt-get install npm && npm install -g pyright`, or install pyright with pipx.
- Java: `sudo apt-get install default-jdk` for javac.

## Validate

```bash
cd ~/vsprojects/.vimrc
scripts/doctor.sh
scripts/smoke-test.sh          # needs script(1) from bsdutils, installed by default
make -C examples/c && examples/c/squares && make -C examples/c clean
```

Then open `vim examples/c/main.c` and do the exercise in [examples/c/README.md](../examples/c/README.md).

Record the results in [implementation-status.md](implementation-status.md). Debian checks there are currently **pending**.

## Notes

- Ctrl-Backspace sends `^H` in most Linux terminals. The vimrc maps that to delete-word in Insert mode, and auto-pairs is configured not to take it over.
- clangd 19 (Debian) and Apple clangd 21 (macOS) can word some diagnostics differently. Both use the same project `compile_flags.txt`.
- GCC may warn about things clangd doesn't, and the reverse. Always build with the real compiler.

## Rollback

```bash
rm ~/.vimrc && mv ~/.vimrc.backup.<timestamp> ~/.vimrc    # path printed by install.sh
rm -rf ~/.vim/plugged ~/.vim/autoload/plug.vim
sudo apt-get remove clangd shellcheck                     # only packages you don't want
pipx uninstall ruff
```
