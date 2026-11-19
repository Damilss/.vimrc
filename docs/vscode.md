# VS Code + VSCodeVim

This page explains how to set up VS Code (1.146) with the [VSCodeVim](https://github.com/VSCodeVim/Vim) extension (1.32.4) so it behaves like this vimrc: the same `gd`/`gr`/`K`/`]e`/`[e` keys, completion keys, delete-word keys, pairing, diagnostics, and colour tweaks. The files to install are:

- [`vscode/settings.json`](../vscode/settings.json): keys to merge into your user settings.
- [`vscode/keybindings.json`](../vscode/keybindings.json): the complete user keybindings file.

What was checked, and how: every setting key and value was checked against the installed extensions' `package.json` and VS Code's bundled source. The key behaviour was read from VSCodeVim's `out/extension.js`. Items marked *test* weren't run in a live editor. If one misbehaves, its fallback is listed under [Fallbacks](#fallbacks).

## Setup (macOS)

1. **Key repeat.** Without this, holding `j` opens the accent popup instead of repeating:

   ```sh
   defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
   ```

   This affects VS Code only; other apps keep the accent popup. Quit VS Code with **Cmd-Q** and reopen it, because *Reload Window* is not enough. If keys still don't repeat, log out and back in. To undo: `defaults delete com.microsoft.VSCode ApplePressAndHoldEnabled`.

2. **Extensions.** These replace ALE's linters. clangd (`llvm-vs-code-extensions.vscode-clangd`), Pylance, the Java extensions, and EditorConfig were already installed.

   ```sh
   CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
   "$CODE" --install-extension usernamehw.errorlens     # ALE's virtual text, signs, and echo line
   "$CODE" --install-extension timonwong.shellcheck     # ALE's sh linter
   "$CODE" --install-extension charliermarsh.ruff       # ALE's ruff linter
   ```

3. **Settings.** Merge the keys from `vscode/settings.json` into `~/Library/Application Support/Code/User/settings.json`. They must go in **user** settings, because VSCodeVim's key bindings are application-scoped and are ignored in a workspace `.vscode/settings.json`. `vim.normalModeKeyBindingsNonRecursive`, `workbench.colorCustomizations`, and `editor.tokenColorCustomizations` are single keys. If you already have one of them, merge into it, because a second copy silently replaces the first.

4. **Keybindings.** Copy `vscode/keybindings.json` to `~/Library/Application Support/Code/User/keybindings.json`, or merge its rules into an existing one.

5. Keep `"C_Cpp.intelliSenseEngine": "disabled"`. cpptools stays installed for its debugger. Any other value gives duplicate C/C++ diagnostics and completions alongside clangd.

6. **C block comments.** Copy `vscode/comment-continuation` to
   `~/.vscode/extensions/emilio-local.c-comment-continuation-0.1.0`, then run
   **Developer: Reload Window**. This local extension adds ` * ` when pressing
   Enter inside `/* ... */` or `/** ... */` in C/C++/CUDA, including VSCodeVim's
   `o` command. It works with clangd and has no executable code or dependencies.
   Keep `editor.autoIndent` at `advanced` or `full` (the default).

## Keys

### Language server

| Mode | Key | Vim (ALE) | VS Code |
| --- | --- | --- | --- |
| Normal | `gd` | `:ALEGoToDefinition` | VSCodeVim's default `gd` (Go to Definition). Not remapped: the default records the jump for Ctrl-O, and a remap would not. |
| Normal | `gr` | `:ALEFindReferences` in a preview window | Peek References (`editor.action.referenceSearch.trigger`). The list always opens, even for one result. |
| Normal | `K` | `:ALEHover` | `editor.action.showHover`. Press `K` again to move focus into the hover, and Esc to close it. (`gh` also works.) |
| Normal | `Ctrl-O` / `Ctrl-I` | jump back / forward | VSCodeVim's own jumplist, which works across files |
| Command | `:ALEGoToDefinition -split` / `-vsplit` | definition in a split | Cmd-K F12, *Open Definition to the Side* (`editor.action.revealDefinitionAside`) |

In the `gr` list:

| Key | Vim (ALE preview) | VS Code peek list |
| --- | --- | --- |
| `j` / `k` | move | move (VSCodeVim binds these in every list) |
| `Enter` | open, close the list | open, close the list (`openReference`) |
| `t` | open in a tab | open to the side (`openReferenceToSide`); VS Code has no Vim tab pages |
| `q` | close | close (`closeReferenceSearch`); Esc also closes it |

`gr` and `]e`/`[e` set the `'` mark first (`:mark '`), as ALE does with ``m` ``, so Ctrl-O comes back after them. *(test)*

### Diagnostics

| Mode | Key | Vim (ALE) | VS Code |
| --- | --- | --- | --- |
| Normal | `]e` | `:ALENextWrap` | `editor.action.marker.next`, then `closeMarkersNavigation` so only the cursor moves *(test)* |
| Normal | `[e` | `:ALEPreviousWrap` | `editor.action.marker.prev`, then `closeMarkersNavigation` *(test)* |

Both wrap within the file. `"problems.sortOrder": "position"` makes them walk in line order; the default jumps to every error before any warning. VS Code's marker navigation skips Hint-level diagnostics.

### Completion

| Mode | Key | Menu open | Menu closed |
| --- | --- | --- | --- |
| Insert | `Tab` | next suggestion | inserts a Tab (or jumps to the next snippet placeholder) |
| Insert | `Shift-Tab` | previous suggestion | outdent (VS Code's default; Vim inserted a Tab) |
| Insert | `Ctrl-Y` | accept the highlighted item (or just close the menu if nothing is highlighted) | VSCodeVim: copy the character from the line above |
| Insert | `Ctrl-E` | close the menu and keep what you typed | VSCodeVim: copy the character from the line below |
| Insert | `Ctrl-N` / `Ctrl-P` | next / previous | open the menu with nothing selected |
| Insert | `Enter` | accept the highlighted item without adding a newline; newline if nothing is selected | newline |

Settings: `"editor.suggest.selectionMode": "never"` (noselect), `"editor.acceptSuggestionOnEnter": "on"`, `"editor.tabCompletion": "off"`. Tab cycling and the other Vim completion shortcuts apply in real editors with VSCodeVim on (`editorTextFocus && vim.active`). Enter accepts a highlighted suggestion in the editor whether Vim is active or inactive, without adding a newline; with nothing selected it inserts a newline.

### Insert-mode delete word

| Key | Vim | VS Code |
| --- | --- | --- |
| `Alt-Backspace` | `inoremap <M-BS> <C-W>` | `vim.remap` to `<C-w>` |
| `Ctrl-Backspace` | `inoremap <C-BS> <C-W>` | `vim.remap` to `<C-w>` |
| `Ctrl-H` | `inoremap <C-H> <C-W>` | `vim.remap` to `<C-w>` |

All three go through VSCodeVim's `<C-w>`, so they follow Vim's word rules rather than VS Code's `deleteWordLeft`.

### Pairing (auto-pairs)

| Behaviour | VS Code |
| --- | --- |
| Insert the pair for `(` `[` `{` `"` `'` | built in, defined per language |
| Typing a closer skips an existing one | `"editor.autoClosingOvertype": "always"` (any closer, not only ones VS Code inserted) |
| Backspace in an empty pair deletes both | `"editor.autoClosingDelete": "always"` |
| Enter between `{}` puts `}` on its own line | built in |
| No quote pairing after a letter (`don't`) | built in (VS Code also skips `"` after a letter) |

## Diagnostics (ALE → VS Code)

| Filetype | ALE linter | VS Code |
| --- | --- | --- |
| C / C++ | clangd | vscode-clangd, using `/usr/bin/clangd` from PATH |
| sh | shellcheck | ShellCheck extension, `"shellcheck.executablePath": "/opt/homebrew/bin/shellcheck"` |
| Python | ruff, pyright | Ruff extension (`"ruff.path": ["/opt/homebrew/bin/ruff"]`) and Pylance (`typeCheckingMode: standard`) |
| Java | javac | the Java language server (Eclipse JDT); it is not plain javac |

ALE's display options map to Error Lens:

| ALE | Error Lens |
| --- | --- |
| `g:ale_virtualtext_cursor = 'current'` | `"errorLens.followCursor": "activeLine"` |
| `g:ale_echo_msg_format = '[%linter%] %severity%: %s'` | `"errorLens.messageTemplate"` and `"errorLens.statusBarMessageTemplate"`: `[$source] $severity: $message` |
| echo line for the cursor's problem | `"errorLens.statusBarMessageEnabled": true`, type `activeCursor` |
| `g:ale_sign_column_always = 1` | gutter letters on every line (`gutterIconsEnabled`, `gutterIconSet: letter`, `gutterIconsFollowCursorOverride`) |
| `g:ale_fix_on_save = 0` | nothing to set: format-on-save and code-actions-on-save are off by default. Don't add `source.fixAll` to `editor.codeActionsOnSave`, because Ruff and ShellCheck would then fix on save. |

Error Lens colours match the vimrc's `Diagnostic*` groups: error `#E1270E`, warning `#FF453A`, info `#6CC7F6`, hint `#5BC266`.

## Editor settings and colours

| Vim | VS Code |
| --- | --- |
| `shiftwidth=4 expandtab`, `.editorconfig` | `"editor.tabSize": 4`, `"editor.insertSpaces": true`, `"editor.detectIndentation": true` (each file keeps its own style), EditorConfig extension |
| `tabstop=8` | not ported: detection needs `tabSize` and the indent to be the same, so literal tabs show 4 wide |
| `cursorline` (number highlighted too) | `"editor.renderLineHighlight": "all"` |
| `LineNr #9E9E9E`, `CursorLineNr #EEEEEE` | `editorLineNumber.foreground` / `activeForeground` |
| comments `#7F7EC0` italic (and docstrings) | `editor.tokenColorCustomizations` rule for `comment` and `string.quoted.docstring.*` |
| `MatchParen` white | `editorBracketMatch.foreground: #FFFFFF` (the theme's match background equals the cursorline) |
| `Search #FFB638`, `IncSearch #FF478D` | `vim.searchHighlightColor` / `vim.searchMatchColor`, with `#0E0E0E` text |
| `Added` / `Changed` / `Removed` | `markup.inserted` / `changed` / `deleted` rules |
| `markdownStrike` | `markup.strikethrough` rule |
| `*.riscv`, `*.rv` → asm | `"files.associations"` → `riscv` (riscv-sense extension) |
| status line / command line | `"workbench.statusBar.visible": true`, which VSCodeVim needs to show `:`, `/`, the mode, and pending keys |

All colour overrides are scoped to `"[AMOLED Black Shiny]"`, so switching themes drops them.

## Known gaps

- **Global, not buffer-local.** The vimrc defines `gd`/`gr`/`K` only in C/C++/Python buffers and `]e`/`[e` only where ALE lints. VSCodeVim remaps can't be limited to a filetype. Where no language provider exists, `gd`/`K` do nothing: there's no text-search `gd` and no `K` → `man` fallback.
- **Completion model.** In Vim, Tab/Ctrl-N *insert* the match, so typing on keeps it. In VS Code the item is only highlighted: you accept with Ctrl-Y, Enter, or a commit character such as `(`, and typing a space or letter drops it. Docs don't pop up by themselves: press Ctrl-Space once on a highlighted item, and the details pane stays open from then on.
- **Pairing.** auto-pairs paired quotes and backticks in every filetype, plus `"""`, `'''` and ```` ``` ````. VS Code pairs only what each language defines (Markdown gets no quotes or backticks). Space inside a pair (`( | )`) and skipping over spaces before a closer aren't available.
- **Opening above a comment line.** The local C comment extension supports Enter and `o`. VSCodeVim's `O` can strip the comment leader while adjusting indentation; use Enter or `o` to continue the comment.
- **Every missing `#include`.** clangd stops at the first missing header, because the error is fatal. The vimrc's extra check has no VS Code setting and would need a small extension.
- **Linter names.** `$source` is what each server reports (`clang`, `Ruff`, `Pylance`, `shellcheck`), not ALE's linter names. There's no lint-on-InsertLeave; servers re-check on every change.
- **Smaller ones.** TODO/FIXME/XXX are highlighted only in Python comments. The jumplist is shared by all editor groups ([VSCodeVim #8914](https://github.com/VSCodeVim/Vim/issues/8914)). The current line number can't be bold. ARM `.s` files open as RISC-V. Asm fences in Markdown aren't highlighted. `gd` has no open-in-tab form.

## Fallbacks

If an item marked *test* misbehaves:

| Problem | Fix |
| --- | --- |
| `gr`, `]e` or `[e` acts oddly | remove `":mark '", ` from that entry in `vim.normalModeKeyBindingsNonRecursive` |
| `]e`/`[e` move but don't land on the problem | remove `"closeMarkersNavigation"` from the entry; you then get VS Code's problem peek under the line (Esc closes it) |
| Enter after Tab does something strange | delete the Insert-mode `enter` → `acceptSelectedSuggestion` rule; Enter then always inserts a plain newline |
| Alt-Backspace misbehaves | delete the `alt+backspace` rule; VS Code's own `deleteWordLeft` takes over |

To undo everything, restore the `settings.json.backup.*` file next to `settings.json`, delete `keybindings.json`, and run the `defaults delete` command above.
