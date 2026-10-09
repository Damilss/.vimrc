# Keybindings

Every mapping the vimrc defines or that the plugins add, verified with `maparg()` in `tests/smoke.vim` and `:verbose imap` on macOS.

## Existing (unchanged)

| Mode | Key | Action |
| --- | --- | --- |
| Insert | `Alt-Backspace` (`<M-BS>`) | Delete previous word (`<C-W>`), for macOS terminals |
| Insert | `Ctrl-H` (`<C-H>`, Ctrl-Backspace on Linux) | Delete previous word (`<C-W>`) |

## Language server (buffer-local)

Defined only in buffers whose filetype has a language server: C and C++ always, Python only when `pyright-langserver` is installed. They are also defined only when ALE is loaded. Everywhere else these keys keep Vim's defaults.

| Mode | Key | Action | Vim default it replaces in those buffers |
| --- | --- | --- | --- |
| Normal | `gd` | `:ALEGoToDefinition` | go to local declaration (text search) |
| Normal | `gr` | `:ALEFindReferences`: list in a preview window (`Enter` opens one, `t` opens in a tab, `q` closes) | `gr{char}`: virtual-replace one character |
| Normal | `K` | `:ALEHover` (type and docs popup) | `keywordprg` lookup (`man` for C) |

`Ctrl-O` jumps back after `gd`. `:ALEGoToDefinition -split` / `-vsplit` / `-tab` open it elsewhere.

With only a `compile_flags.txt`, clangd knows the files you have opened in this session. For example, `gr` on `vec_free` in `examples/c` lists the calls in `main.c` and only includes `vec.c` once that file has been opened. A `compile_commands.json` lets clangd index the whole project in the background (see [examples/c/README.md](../examples/c/README.md)).

## Diagnostics (buffer-local)

Defined in C, C++, sh, Python, Java, Markdown, text, and git commit buffers when ALE is loaded.

| Mode | Key | Action |
| --- | --- | --- |
| Normal | `]e` | `:ALENextWrap`: next diagnostic, wrapping to the top |
| Normal | `[e` | `:ALEPreviousWrap`: previous diagnostic, wrapping to the bottom |

`]e`/`[e` have no Vim default.

## Grammar fixes (buffer-local)

Defined in Markdown, text, and git commit buffers when ALE is loaded and grammar checking is on (see the README's [Grammar checking](../README.md#grammar-checking)).

| Mode | Key | Action | Vim default it replaces in those buffers |
| --- | --- | --- | --- |
| Normal | `z=` | On an underlined mistake: replace it with the model's suggestion, as one undo step, and echo what changed | spelling suggestions, which it still shows wherever there is no grammar fix |

Away from a grammar mistake, `z=` is Vim's own spelling-suggestion list when `spell` is on (`:setlocal spell`), and otherwise says "No grammar suggestion here". `]s`/`[s`/`zg` are untouched.

## Completion (global)

| Mode | Key | Menu open | Menu closed |
| --- | --- | --- | --- |
| Insert | `Tab` | next suggestion | inserts a Tab, as before |
| Insert | `Shift-Tab` | previous suggestion | sends `<S-Tab>`, as before |
| Insert | `Ctrl-Y` | accept (Vim built-in) | (built-in: copy character from line above) |
| Insert | `Ctrl-E` | close menu, restore typed text (built-in) | (built-in: copy character from line below) |
| Insert | `Ctrl-N` / `Ctrl-P` | next / previous (built-in) | start keyword completion (built-in) |

In C/C++ buffers ALE opens the menu by itself while you type an identifier, or right after `.` or `->`. Nothing is selected or inserted until you press Tab, Ctrl-N, or an arrow key. Typing on, or pressing Enter, never takes a suggestion.

Enter does **not** accept completions. It stays a newline, handled by auto-pairs, so brace expansion always works. This was decided deliberately to avoid two competing Enter mappings.

**Header insertion:** when a suggestion comes from a header the file doesn't include yet, clangd can add the `#include` as part of accepting it. This is ALE's `g:ale_completion_autoimport`, on by default, combined with clangd's `--header-insertion=iwyu`. With a `compile_flags.txt` project, clangd mostly suggests symbols from headers you've already included, so this is rare. To turn it off, add this to the vimrc's Plugins section:

```vim
let g:ale_c_clangd_options = '--header-insertion=never'
let g:ale_cpp_clangd_options = '--header-insertion=never'
```

## Pairing (auto-pairs, buffer-local in every buffer)

| Mode | Key | Behavior |
| --- | --- | --- |
| Insert | `(` `[` `{` `"` `'` `` ` `` | Insert the pair, cursor between |
| Insert | `)` `]` `}` `"` `'` | If the next character is that closer, move past it instead of inserting another |
| Insert | `Backspace` | Between an empty pair, delete both |
| Insert | `Enter` | Between `{}`, put `}` on its own line and indent the cursor line using your indent settings (C: `cindent`, one tab) |
| Insert | `Space` | Between a pair, insert a space on both sides: `( | )` |

Quotes are not paired after a letter or digit (`don't` stays `don't`). An escaped quote (`\"`) inside a string is inserted literally.

Disabled on purpose, because they clash with terminal Vim or with your mappings:

| auto-pairs default | Why disabled | To turn back on (before `plug#end()`) |
| --- | --- | --- |
| `Ctrl-H` = Backspace | Would override your Ctrl-H delete-word mapping | (leave off) |
| `Alt-P` toggle, `Alt-E` fast-wrap, `Alt-N` jump, `Alt-B` back-insert | Terminal Vim sees Alt+key as an 8-bit character (`Alt-E` arrives as `å`), so these would swallow typed characters | `let g:AutoPairsShortcutFastWrap = '<M-e>'` etc. |
| `Alt-(`, `Alt-)`, … move-character keys | Same as above (`©`, `§`, … would be swallowed) | `let g:AutoPairsMoveCharacter = "()[]{}\"'"` |
| Multi-line close (typing `)` jumps to a `)` on a later line) | Surprising in C; VS Code only skips on the same line | `let g:AutoPairsMultilineClose = 1` |

To pause pairing temporarily, run `:call AutoPairsToggle()`.

## Checking a key yourself

```vim
:verbose imap <CR>
:verbose imap <Tab>
:verbose imap <S-Tab>
:verbose imap <C-H>
:verbose nmap gd
:verbose nmap z=
```

`verbose` shows which file defined the mapping. Lines from `~/.vim/plugged/auto-pairs/...` are auto-pairs. Lines from `.vimrc` are yours.
