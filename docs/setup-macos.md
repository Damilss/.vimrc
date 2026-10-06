# macOS setup

Tested on macOS 26.7.1 (Apple Silicon) with Apple's `/usr/bin/vim` 9.1 and Xcode's clangd 21. See [implementation-status.md](implementation-status.md).

## Prerequisites

| Need | Why | Check |
| --- | --- | --- |
| Xcode or the Command Line Tools | compiler, SDK headers, `git`, `make`, and `clangd` (`/usr/bin/clangd` is an Xcode shim) | `xcode-select -p`, `xcrun --show-sdk-path` |
| Vim with `+job +channel +timers` | ALE runs clangd as an async job | `vim --version \| grep -E '[+-](job\|channel\|timers)'` |
| `curl` | downloads vim-plug | built in |
| Homebrew (optional) | only if no clangd is found, or for `--extras` | `command -v brew` |

If the Command Line Tools are missing, run `xcode-select --install`, finish the installer window, and rerun the setup. The setup script never installs Homebrew itself. If it needs Homebrew and Homebrew is missing, it stops and points you to <https://brew.sh>.

## Which Vim and which clangd

This setup uses the **Vim already on your PATH**, normally Apple's `/usr/bin/vim`. Apple's build has the async features ALE needs. Homebrew Vim is not required. In this machine's PATH, `/opt/homebrew/bin` comes after `/usr/bin`, so a Homebrew `vim` wouldn't be picked up by a plain `vim` anyway.

To use a different Vim for the scripts, set `VIMRC_VIM`, e.g. `VIMRC_VIM=/opt/homebrew/bin/vim scripts/doctor.sh`. You then launch that Vim yourself. The vimrc is the same.

The vimrc picks clangd at startup, once per Vim session:

1. If you set `g:ale_c_clangd_executable` / `g:ale_cpp_clangd_executable` before the vimrc's Plugins section, that wins.
2. Otherwise `clangd` on `PATH`. On macOS that is `/usr/bin/clangd` → Xcode's Apple clangd, which already knows where the macOS SDK is.
3. Otherwise Homebrew LLVM's clangd, found with `brew --prefix llvm` (works for `/opt/homebrew` and `/usr/local`). Homebrew's LLVM is keg-only, and this setup never puts it ahead of Apple's `clang` on your PATH.

## Install

From an existing checkout:

```bash
cd ~/vsprojects/.vimrc
scripts/setup-macos.sh            # core: links ~/.vimrc, installs vim-plug + plugins
scripts/setup-macos.sh --extras   # also: brew install shellcheck ruff
```

Fresh clone. Clone anywhere except `~/.vimrc` itself, which must stay free for the symlink:

```bash
git clone https://github.com/damilss/.vimrc.git ~/vsprojects/.vimrc
~/vsprojects/.vimrc/scripts/setup-macos.sh
```

The setup script runs these steps:

1. It checks the Command Line Tools and SDK, Vim's features, and clangd. If no clangd is found, it runs `brew install llvm`.
2. With `--extras`, it runs `brew install shellcheck ruff`, skipping anything already installed.
3. It runs `scripts/install.sh`:
   - If `~/.vimrc` is a regular file or a different symlink, it moves it to `~/.vimrc.backup.<timestamp>`. A symlink is moved as-is and its target is untouched. The new backup path is printed.
   - It links `~/.vimrc` to the repo's `.vimrc`.
   - It downloads vim-plug 0.14.0 over HTTPS to a temp file, checks it, and moves it into `~/.vim/autoload/plug.vim`.
   - It runs `vim -es +'PlugInstall --sync'` and then verifies that `ale` and `auto-pairs` exist in `~/.vim/plugged`.
4. It runs `scripts/doctor.sh`.

Rerunning is safe. A correct link and an installed vim-plug are left alone, and no new backup is made. Other contents of `~/.vim` are never touched.

For Python completion and `gd`/`gr`/`K`, optionally run `npm install -g pyright`. ALE will find `pyright-langserver` on PATH.

## Validate

```bash
scripts/doctor.sh                  # every required line should be [ok]
scripts/smoke-test.sh              # real Vim + clangd interaction test, about 20 s
make -C examples/c && examples/c/squares && make -C examples/c clean
```

Then open `vim examples/c/main.c` and try the exercise in [examples/c/README.md](../examples/c/README.md).

## SDK and header problems

If clangd reports `'stdio.h' file not found`:

1. Check `xcode-select -p` and `xcrun --show-sdk-path`. If either fails, run `xcode-select --install`. If you have several Xcodes, use `sudo xcode-select -s /Applications/Xcode.app`.
2. Run `clangd --check=path/to/file.c` in the shell. It prints the compile command and the `-isysroot` it uses. Xcode's clangd adds the SDK automatically.
3. If you switched to Homebrew's clangd and only it fails, the problem is its SDK lookup. Prefer Xcode's clangd, or check `"$(brew --prefix llvm)/bin/clang" -v -fsyntax-only file.c`.

Do not add your local SDK path to the vimrc or to a committed `compile_flags.txt`. It differs between machines and Xcode versions.

## Rollback

`install.sh` prints the exact restore command when it moves a file. From this machine's install on 2026-10-06:

```bash
rm ~/.vimrc && mv ~/.vimrc.backup.20261006-004241 ~/.vimrc
rm -rf ~/.vim/plugged ~/.vim/autoload/plug.vim
brew uninstall shellcheck ruff        # only if you no longer want them
```
