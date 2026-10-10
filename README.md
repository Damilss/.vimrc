# My Vim configuration

Personal configuration for terminal Vim on macOS and Debian 13 (trixie). It includes:

- the AMOLED Black Shiny color theme,
- extra syntax colors for several languages,
- language-server C/C++ diagnostics and completion (ALE + clangd),
- automatic closing of quotes and brackets (auto-pairs).

Repository: <https://github.com/damilss/.vimrc>

Everything lives in one tracked file, [`.vimrc`](.vimrc). `~/.vimrc` is a symlink to it. The plugins are optional. Without them, Vim starts normally with the theme and settings below.

## What is in the vimrc

### Editor settings

| Area | Setting |
| --- | --- |
| Filetypes | `filetype plugin indent on`, `syntax enable` |
| Display | `number`, `cursorline`, `background=dark`, `termguicolors` (when supported) |
| Indentation | Vim defaults: C uses `cindent` with 8-column tabs (no `shiftwidth`/`expandtab` overrides) |
| Theme | AMOLED Black Shiny palette (from the VS Code theme of the same name). Pink identifiers by default; `let g:amoled_black_shiny_pink_normal = 0` before loading switches to `#EEEEEE` |
| Comments | Indigo italic, lifted to about 5:1 contrast |
| Line numbers | Brighter than the theme's (`#9E9E9E`, current line bold `#EEEEEE`) so they stay readable on dim displays |
| Syntax colors | VS Code-matching links for C/C++, Python, Java, Swift, Bash/sh, YAML, Markdown (+ embedded HTML), and RISC-V/ARM/AArch64 assembly |
| Built-in syntax options | `g:c_functions`, `g:c_function_pointers`, `g:java_highlight_all`/`functions`/`generics`, `g:python_constant_highlight` |
| Markdown | Highlighted fences for c, cpp, java, python, swift, bash/shell/zsh, asm/riscv/arm/aarch64. Gray prose via `wincolor` |
| Filetype detection | `*.yml`/`*.yaml` → yaml; `*.riscv`/`*.rv` → asm |
| Insert mappings | `Alt-Backspace` (macOS) and `Ctrl-H` / Ctrl-Backspace (Linux) delete the previous word |

### Language tools and pairing

| Component | Purpose |
| --- | --- |
| [vim-plug](https://github.com/junegunn/vim-plug) 0.14.0 | Installs the two plugins into `~/.vim/plugged` |
| [ALE](https://github.com/dense-analysis/ale) v4.0.0 | Runs language servers and linters asynchronously. Shows signs, underlines, the current line's message, and the location list. Provides completion, go-to-definition, references, and hover |
| [auto-pairs](https://github.com/jiangmiao/auto-pairs) (2019 master, pinned) | Pairs `()`, `[]`, `{}`, `""`, `''`, and backticks. Skips over closers, deletes empty pairs, and expands `{}` on Enter. Unmaintained since 2019, but it works with Vim 9.1 (tested) |
| clangd | C/C++ analysis. On macOS this is Xcode's `/usr/bin/clangd` (or Homebrew `llvm`'s when no clangd is on `PATH`); on Debian, apt's `clangd` |

ALE only runs the linters listed in the vimrc (`g:ale_linters_explicit = 1`). A linter that isn't installed is skipped silently.

| Filetype | Diagnostics | Completion / `gd` `gr` `K` |
| --- | --- | --- |
| C, C++ | clangd | yes (clangd) |
| sh/bash | shellcheck | no |
| Python | ruff, plus pyright if installed | only with pyright |
| Java | javac (waits 1.5 s after typing stops) | no |

All other filetypes behave exactly as they did before. Nothing reformats or "fixes" files automatically.

Diagnostics update as you type (after a short pause), when you leave Insert mode, and on save. Unsaved edits are checked too.

## Keybindings

The full list, with displaced defaults, is in [docs/keybindings.md](docs/keybindings.md).

| Mode | Key | Action | Where |
| --- | --- | --- | --- |
| Normal | `gd` | Go to definition | C/C++ (and Python with pyright) |
| Normal | `gr` | Find references | same |
| Normal | `K` | Hover: type/docs popup | same |
| Normal | `]e` / `[e` | Next / previous diagnostic (wraps) | C/C++, sh, Python, Java |
| Insert, menu open | `Tab` / `Shift-Tab` | Next / previous suggestion | everywhere |
| Insert, menu open | `Ctrl-Y` | Accept suggestion (Vim built-in) | everywhere |
| Insert | `Enter` | Newline; between `{}` opens an indented block | everywhere |
| Insert | `Alt-Backspace`, `Ctrl-H` | Delete previous word (existing) | everywhere |

The completion menu appears by itself as you type in C/C++. Nothing is selected or inserted until you press `Tab`, so plain typing and Enter are never taken over.

## Install

### macOS

```bash
git clone https://github.com/damilss/.vimrc.git ~/vsprojects/.vimrc   # or use an existing checkout
~/vsprojects/.vimrc/scripts/setup-macos.sh            # add --extras for shellcheck + ruff
```

The script checks Xcode Command Line Tools, the SDK, Vim's `+job/+channel/+timers`, and clangd. It installs Homebrew `llvm` only if no clangd is found. Then it runs `install.sh` and `doctor.sh`. Launch with plain `vim`. Details are in [docs/setup-macos.md](docs/setup-macos.md).

### Debian 13 (trixie)

```bash
sudo apt-get install -y git
git clone https://github.com/damilss/.vimrc.git ~/vsprojects/.vimrc
~/vsprojects/.vimrc/scripts/setup-debian.sh           # add --extras for shellcheck + ruff
```

This installs `vim clangd git curl build-essential` with sudo, then sets up your user files. It has been written and syntax-checked but **not yet run on Debian**. See [docs/setup-debian.md](docs/setup-debian.md).

### What the scripts do

| Script | Role |
| --- | --- |
| `scripts/setup-macos.sh` | macOS prerequisite checks, Homebrew installs if needed, then `install.sh` + `doctor.sh` |
| `scripts/setup-debian.sh` | apt packages (sudo only for apt), then `install.sh` + `doctor.sh` |
| `scripts/install.sh` | Links `~/.vimrc` → this repo's `.vimrc`, backing up any previous file or symlink. Downloads vim-plug. Runs `:PlugInstall --sync` and verifies the result. Safe to rerun |
| `scripts/doctor.sh` | Read-only checks. `[FAIL]` items make it exit nonzero; `[opt]` items are informational |
| `scripts/smoke-test.sh` | Drives real Vim in a pseudo-terminal against `examples/c`: diagnostics (including every missing `#include`), completion, navigation, hover, pairing, re-sourcing |

All scripts run from any directory, handle spaces in paths, work with macOS's Bash 3.2, and refuse to run as root.

## Per-project build flags

clangd needs to know how each project is compiled. For a small C project, put a `compile_flags.txt` in the project root, one flag per line:

```text
-Wall
-Wextra
-Wpedantic
-std=c17
```

For larger projects, or per-file flags, generate a `compile_commands.json` (e.g. `cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`). clangd finds it in the project root or in a `build/` directory.

These flags belong to each project. They are deliberately **not** in the vimrc, so C flags never get applied to C++. [examples/c/README.md](examples/c/README.md) walks through both approaches.

A [`.clangd`](https://clangd.llvm.org/config) file in the project can add flags too, for example in a repository that only has VS Code's `c_cpp_properties.json`.

**Missing `#include`s.** clangd reports only the first missing header in a file. When a `compile_flags.txt`, `compile_commands.json`, or `.clangd` is in the file's directory or above it, the vimrc marks every other missing one too, as `[includes] Error: 'x.h' file not found`. Without one of those files, clangd still checks the file but has to guess its flags, so you get only clangd's report of the first one. Details are in [docs/troubleshooting.md](docs/troubleshooting.md#missing-headers-stdioh-file-not-found).

## Diagnostics commands

| Command | Use |
| --- | --- |
| `:ALEInfo` | Which linters are enabled and running, the executable used, and the command log |
| `:lopen` | Location list of the current buffer's diagnostics |
| `:ALEDetail` | Full message for the diagnostic under the cursor |
| `:ALELint` | Check now |
| `:ALEToggleBuffer` | Turn ALE off/on for this buffer |
| `:ALEStopAllLSPs` | Stop clangd and other language servers; the next edit restarts them. Use after adding or changing a `compile_flags.txt` or `compile_commands.json` |
| `scripts/doctor.sh` | Check the whole setup from the shell |

More help is in [docs/troubleshooting.md](docs/troubleshooting.md).

## Plugin management

The plugins are declared in `.vimrc` between `plug#begin` and `plug#end`, pinned to a tag or commit.

- `:PlugStatus` shows their state.
- `:PlugInstall` installs missing ones.
- To upgrade ALE, change its `tag` in `.vimrc`, then run `:PlugUpdate`.
- `:PlugClean` removes plugins no longer listed.
- `:PlugUpgrade` updates vim-plug itself.

## Rollback

`install.sh` prints the exact commands when it displaces a file. In general:

```bash
rm ~/.vimrc && mv ~/.vimrc.backup.<timestamp> ~/.vimrc   # restore the previous vimrc
rm -rf ~/.vim/plugged ~/.vim/autoload/plug.vim          # remove plugins and vim-plug
```

`vim -Nu NONE` opens Vim with no configuration at all for emergencies. Homebrew packages installed by `--extras` can be removed with `brew uninstall shellcheck ruff`.

## More documentation

- [docs/setup-macos.md](docs/setup-macos.md) and [docs/setup-debian.md](docs/setup-debian.md)
- [docs/keybindings.md](docs/keybindings.md)
- [docs/troubleshooting.md](docs/troubleshooting.md)
- [docs/implementation-status.md](docs/implementation-status.md): what was done and what was tested where
