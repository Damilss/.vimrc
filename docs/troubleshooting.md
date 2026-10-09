# Troubleshooting

Start with the shell check, then the Vim one:

```bash
~/vsprojects/.vimrc/scripts/doctor.sh
```

```vim
:ALEInfo
```

## `:ALEInfo`

Run it in the buffer that misbehaves. The useful parts are:

| Section | What to look for |
| --- | --- |
| `Current Filetype` | `c`, `cpp`, `sh`, `python`, `java`, and `markdown`, `text`, `gitcommit` (grammar). Other filetypes have no linters, by design |
| `Enabled Linters` | e.g. `['clangd']`. Empty means the filetype isn't configured |
| `Linter Variables` | `g:ale_c_clangd_executable`: the clangd actually used |
| `Command History` | the exact command run and its output. A clangd that failed to start shows here |

`E492: Not an editor command: ALEInfo` means ALE isn't loaded. See the next section.

## Plugins or vim-plug missing

Vim prints `vimrc: no C/C++ diagnostics (missing ALE plugin)` once when you open a C/C++ file.

- `ls ~/.vim/autoload/plug.vim ~/.vim/plugged` should show `plug.vim`, `ale`, and `auto-pairs`.
- Run `scripts/install.sh`. If the install fails, open Vim and run `:PlugInstall` to see vim-plug's own error window. It is usually network trouble or a missing `git`.
- `:PlugStatus` shows each plugin's state.
- If `~/.vimrc` isn't the symlink, you're editing a different config. Check with `ls -l ~/.vimrc`, and fix it with `scripts/install.sh`, which backs up the old file.

## clangd not found or PATH problems

The message is `vimrc: no C/C++ diagnostics (missing clangd)`.

- Check `command -v clangd` in the **same environment Vim starts from**. A GUI or IDE launcher may have a shorter PATH than your shell.
- **macOS:** `/usr/bin/clangd` comes with Xcode or the Command Line Tools. If the tools are missing, run `xcode-select --install`, or `brew install llvm`. The vimrc finds Homebrew's keg-only clangd through `brew --prefix llvm` without any PATH change.
- **Debian:** `sudo apt-get install clangd`.
- To force one specific binary, add this before the vimrc's Plugins section:

  ```vim
  let g:ale_c_clangd_executable = '/path/to/clangd'
  let g:ale_cpp_clangd_executable = '/path/to/clangd'
  ```
- The vimrc looks up clangd once per Vim session. After installing it, restart Vim; re-sourcing the vimrc is not enough.
- `ruff`, `shellcheck`, `pyright-langserver`, and `javac` must also be on Vim's PATH. On Debian, pipx installs into `~/.local/bin`, so run `pipx ensurepath`.

## Missing headers (`'stdio.h' file not found`)

1. Test outside Vim with `clangd --check=file.c`. It prints the compile command, the flags source (`compile_flags.txt` / `compile_commands.json` / fallback), and every diagnostic.
2. **macOS:** check `xcrun --show-sdk-path`. If it fails, reinstall the Command Line Tools or run `sudo xcode-select -s /Applications/Xcode.app`. Don't paste an SDK path into the vimrc or a committed flags file.
3. **Debian:** `sudo apt-get install build-essential` provides `/usr/include`.
4. If your **own** headers aren't found, add `-Iinclude` (relative to the project root) to the project's `compile_flags.txt`.

clangd's guide to system headers: <https://clangd.llvm.org/guides/system-headers>.

## Compile database discovery

For each file, clangd looks upward from the file's directory for `compile_commands.json` (also inside a `build/` subdirectory at each level) or `compile_flags.txt`. The nearest one wins. With neither, it guesses flags, which usually means the wrong `-std` and no include paths.

- `clangd --check=file.c 2>&1 | grep -i 'compil'` shows which database it loaded.
- CMake: `cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` writes `build/compile_commands.json`, which clangd finds.
- Make: `bear -- make` (Debian: `apt install bear`; macOS: `brew install bear`) writes `compile_commands.json` in the current directory.
- Generated databases contain absolute paths. Keep them out of git (`.gitignore` here already ignores them).
- When you add or change a database, restart clangd with `:ALEStopAllLSPs`. The next edit starts it again.

## Diagnostic timing

- ALE checks after you stop typing for `g:ale_lint_delay` ms (200 by default; Java uses 1500; grammar checking uses `g:vimrc_grammar_delay`, 1000), when you leave Insert mode, and on save. Unsaved changes are checked; clangd gets the buffer contents directly.
- If nothing updates, run `:ALELint` and then `:ALEInfo`. Check `Command History` and whether clangd is running.
- On the first open of a file, clangd can take a second or two to parse it and its headers.
- Diagnostics come from Clang. GCC may warn about different things, so keep building with your real compiler.

## Completion

- The menu appears on its own in C/C++. If it doesn't, check `:echo g:ale_completion_enabled` (should be `1`) and `:ALEInfo`.
- `Tab`/`Shift-Tab` move through the menu, `Ctrl-Y` accepts, and `Ctrl-E` cancels. Enter never accepts; it inserts a newline.
- No struct members after `.`? The variable's type must be known to clangd. Check for an error earlier in the file (`]e`) and that the header is found.
- Python completion needs pyright (`npm install -g pyright`). ruff only gives diagnostics.
- Header auto-insertion is described in [keybindings.md](keybindings.md#completion-global).

## Grammar checking

Markdown, text, and git commit buffers are checked by a local model through Ollama. Behavior and settings are in the README's [Grammar checking](../README.md#grammar-checking).

| Symptom | What to check |
| --- | --- |
| `vimrc: no grammar check (Ollama not reachable at …)` | Ollama isn't running. On macOS, start the Ollama app; on Linux, run `ollama serve` (or its systemd service). `curl http://127.0.0.1:11434/api/version` should answer. If `$OLLAMA_HOST` is set, Vim uses it. |
| `vimrc: no grammar check (model … not found)` | Run `ollama pull qwen3.5:9b`, or set `g:vimrc_grammar_model` to a model you have (`ollama list`). |
| Nothing underlined, no message | Run `:ALEInfo` in the buffer. `Enabled Linters` should be `['grammar']`, and `Command History` shows the helper's command and output. With an empty list, check `scripts/doctor.sh`: grammar checking needs `python3` and the helper file. If `~/.vimrc` is a copy rather than the symlink, set `g:vimrc_grammar_helper` to the repo's `scripts/grammar_check.py`. |
| The first underline takes several seconds | Ollama unloads the model 30 minutes after the last check (`g:vimrc_grammar_keep_alive`). Loading it again takes about 3.5 s. A paragraph with many mistakes also takes longer, because the model writes out each one. |
| A paragraph below the screen isn't checked | By design: only the cursor's paragraph and what's on screen are sent. Scroll to it and pause. |
| A suggestion is wrong | The model is small. Ignore the suggestion, or reword. Cached answers are dropped once the paragraph changes. `rm -rf ~/.cache/vimrc-grammar` forgets all of them. |
| `z=` says "No grammar suggestion here" | The cursor isn't on an underlined word, or the check hasn't come back yet. With `:setlocal spell`, `z=` shows Vim's spelling suggestions instead. |
| Too much memory or battery | `:ALEToggleBuffer` pauses checking in one buffer. A shorter `g:vimrc_grammar_keep_alive` (e.g. `'5m'`) unloads the model sooner. `vim --cmd 'let g:vimrc_grammar_enabled = 0'` turns it off. |

To see exactly what the helper reports, run it by hand:

```bash
scripts/grammar_check.py --filetype markdown --cursor 1:1 < notes.md
```

## Mapping conflicts

```vim
:verbose imap <CR>
:verbose imap <Tab>
:verbose imap <S-Tab>
:verbose imap <C-H>
:verbose nmap gd
```

| Symptom | Likely cause |
| --- | --- |
| Ctrl-Backspace deletes one character | The terminal sends `^?` instead of `^H`, so the `<C-H>` mapping never sees it. Check your terminal's key settings. auto-pairs does not map `<C-H>` in this setup |
| `<CR>` shows an auto-pairs mapping | Expected: auto-pairs wraps Enter in every buffer for brace expansion |
| `gd`/`K` do Vim's default in a C file | ALE wasn't loaded when the buffer opened. Check `:ALEInfo`, then `:edit` the file again |
| Typing `å` or `©` does something odd | Only if you re-enabled auto-pairs' Alt shortcuts (see keybindings.md) |

## Emergency

- `vim -Nu NONE file` opens Vim without this configuration.
- `vim --cmd 'let g:ale_enabled = 0' file` opens it with ALE disabled.
- `:ALEDisable` / `:ALEEnable` turn ALE off and on in the current session.
