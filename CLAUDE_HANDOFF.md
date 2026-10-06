> **Original task requirements, kept for reference.** Implementation finished
> 2026-10-06 on macOS. What was actually done, decisions that differ from this
> text, and test results are in
> [docs/implementation-status.md](docs/implementation-status.md). Debian runtime
> validation is still pending.

# Codex handoff: extend Emilio's existing Vim configuration

## Task

Inspect and extend my existing repository at <https://github.com/damilss/.vimrc>. Plan the changes from the actual repository, then implement and validate the setup on my current macOS machine. Prepare scripts and complete documentation for Debian 13 Trixie so I can install it later without returning to the original chat.

I like real terminal Vim. I want the live C/C++ diagnostics, semantic completion, and automatic quote/bracket closing that I use in VS Code. Preserve my existing editor preferences and configuration. Keep editor settings centralized in the existing vimrc where practical.

This handoff and its companion README were prepared without access to the repository. **No existing repository settings, plugins, filenames, or installation behavior have been verified.** Inspect them yourself. The README is a draft, not evidence about the current setup and not a replacement to apply blindly.

## Working context and scope

- I am on macOS now. I also develop on Debian 13 Trixie.
- I will not open or connect to my Linux machines during this work.
- My current focus is C: pointers, structs, dynamic arrays, headers, tests, and GCC/Clang builds. Support C++ without imposing C compilation flags on it.
- Use actual Vim and Vimscript; a switch to Neovim, Lua configuration, or VS Code is outside this task.
- Prefer a small plugin set. ALE plus clangd and a pairing plugin are the intended additions.
- Implement the repo files and perform ordinary local setup and validation under the terminal session's permissions. If a package installation needs interactive authentication or a GUI installer, prepare the exact command and explain the remaining manual step.
- Prepare Linux scripts and docs locally. Do not SSH into Linux machines or claim Linux runtime testing occurred.
- Do not commit or push changes unless I separately request it. Report the resulting diff and any remaining manual checks.

## Phase 1: inspect before editing

Use an existing local checkout if available. Check `pwd`, `git status`, and the remote URL before modifying anything. If no checkout exists, clone into a clearly identified local directory without overwriting an unrelated directory. Honor applicable `AGENTS.md` instructions and preserve unrelated uncommitted changes.

Inspect:

1. The actual vimrc entry point and all files it sources.
2. Existing settings, comments, language autocmds, mappings, and plugins.
3. Plugin manager and installation scripts, if present.
4. How the active `~/.vimrc` relates to the repository: regular file, symlink, or wrapper that sources a file.
5. The active Vim binary, its version, and features needed for asynchronous plugins (`+job`, `+channel`, `+timers`).
6. Homebrew, LLVM/clangd, compiler, Command Line Tools, and SDK availability.
7. Existing C diagnostics/completion engines and pairing plugins that could overlap.

Create a short plan based on what you find. Record existing features in the README before presenting them as facts. Reuse compatible existing plugins and manager instead of installing duplicate functionality. If a mapping or indentation preference conflicts with the earlier chat examples, the real configuration is the baseline.

If the repo cannot be accessed, use a verified local checkout if one is available. Otherwise request its contents instead of inventing a configuration. Continue independent prerequisite checks while resolving access.

## Phase 2: integrate editor functionality

Preferred components:

| Component | Preferred source | Requirement |
| --- | --- | --- |
| Diagnostics and LSP client | `dense-analysis/ale` | Asynchronous C/C++ diagnostics and navigation |
| C/C++ language server | clangd from LLVM | Completion, symbols, type analysis, and errors/warnings |
| Automatic pairing | `jiangmiao/auto-pairs` | Pair insertion, deletion, skipping, and brace Enter handling |
| Plugin installation | Existing manager, otherwise vim-plug | Repeatable setup on both operating systems |

Verify current upstream documentation for the installed versions. If an existing equivalent already provides a requested feature, keep it and document the choice. Avoid introducing another LSP client or completion engine alongside ALE without a concrete need.

### ALE setup

- Enable ALE's built-in semantic completion with `g:ale_completion_enabled = 1` **before ALE loads**. Plugin startup order matters.
- Configure clangd as the C and C++ linter while preserving existing settings for other filetypes. Merge existing dictionaries deliberately rather than replacing them wholesale.
- Avoid simultaneous GCC/Clang external linters and clangd for C/C++ unless there is an intentional, documented reason.
- Provide diagnostics while editing and after save/insert exit. For ALE's configurable lint events, prefer `g:ale_lint_on_text_changed = 'always'`, with insert-leave and save enabled, if compatible with the existing setup. LSP diagnostic timing also depends on clangd and ALE document updates; verify behavior on unsaved edits.
- Keep output readable in terminal Vim: diagnostic signs, line highlights or messages, and a usable location list.
- Do not add automatic formatting or fix-on-save as an unrelated feature.
- Leave normal compilation and testing intact. clangd uses Clang analysis and need not emit exactly the same warnings as GCC.

### Executable discovery across platforms

First inspect existing configuration and working executables. Prefer a user-supplied executable override, then a suitable executable on PATH, and use Homebrew's LLVM path when necessary on macOS.

- Resolve Homebrew locations dynamically with `brew --prefix llvm`; support both Intel and Apple Silicon.
- Verify the actual ALE options for C and C++ executable overrides, such as `g:ale_c_clangd_executable` and `g:ale_cpp_clangd_executable`, before using them.
- Quote paths properly and cache discovery if invoking Homebrew from Vimscript. Do not run Homebrew repeatedly on every buffer event.
- Do not require a global PATH change that replaces Apple's `clang` just to locate clangd.
- On Debian, the normal `clangd` executable from apt should work.
- If clangd or plugins are missing, keep ordinary editing usable and provide a useful doctor/setup message.

### Navigation and completion mappings

Prefer the following bindings when they do not replace an existing custom mapping:

| Mode | Key | Action |
| --- | --- | --- |
| Normal | `gd` | `:ALEGoToDefinition` |
| Normal | `gr` | `:ALEFindReferences` |
| Normal | `K` | `:ALEHover` |
| Normal | `]e` | `:ALENextWrap` |
| Normal | `[e` | `:ALEPreviousWrap` |
| Insert with completion menu | `Tab` | Next completion |
| Insert with completion menu | `Shift-Tab` | Previous completion |
| Insert with completion menu | `Ctrl-Y` | Accept completion |

Prefer C/C++ buffer-local mappings in an idempotent augroup if practical, so `K` and `gd` retain their usual behavior in unrelated buffers. Clear/redefine your own autocmds safely when re-sourcing the vimrc. Use direct ALE commands for diagnostic navigation, or verified plugin mappings.

Outside a completion menu, preserve Tab and existing Shift-Tab behavior. The previous chat used Ctrl-H as a Shift-Tab fallback; do not carry over that unexpected deletion behavior. Keep native completion acceptance available. Check automatic-import/header insertion behavior and document what the chosen configuration does.

### Pairing and Enter handling

Support `()`, `[]`, `{}`, double quotes, and single quotes. Check these cases:

- Typing an opener inserts a closer and leaves the cursor between them.
- Typing the existing closer advances past it without duplication.
- Backspace between an empty pair handles both characters appropriately.
- Enter inside empty braces produces a properly indented block using my existing indentation settings.
- C character literals and quoted strings remain practical, including escaped quotes.

**Do not blindly combine two independent Enter mappings.** auto-pairs installs buffer-local mappings and may override a global expression mapping depending on startup order. Default to `Ctrl-Y` for completion acceptance and leave Enter to pairing/newline behavior. If implementing Enter-to-accept, integrate it using the installed plugin's supported mechanism and verify both completion and brace expansion.

Inspect actual buffer mappings with `:verbose imap <CR>`, `:verbose imap <Tab>`, and `:verbose imap <S-Tab>`. Avoid relying on terminal Option/Meta shortcuts as the only way to use a feature on macOS.

## Phase 3: implement repeatable setup scripts

Reuse existing scripts if they fulfill these roles. Otherwise create:

| Proposed script | Behavior |
| --- | --- |
| `scripts/setup-macos.sh` | Check macOS, Homebrew and Command Line Tools; install missing dependencies; run shared installation |
| `scripts/setup-debian.sh` | Check Debian/Linux suitability, install apt dependencies, then run shared installation |
| `scripts/install.sh` | Back up and connect the actual tracked vimrc, bootstrap manager if needed, install plugins |
| `scripts/doctor.sh` | Read-only checks and actionable failure messages |

Requirements:

- Safe to rerun. Reuse the correct symlink and installed manager; do not repeatedly back up an already-correct installation.
- Back up displaced regular files or different symlinks without changing their targets. Preserve unrelated contents of `~/.vim`.
- Print backup paths and provide exact rollback instructions.
- Run from any working directory and support spaces in repo/home paths.
- Use macOS-compatible shell syntax and utilities; macOS's bundled Bash is old. Avoid Bash 4-only constructs and GNU-only flags unless dependencies are explicit.
- Detect the actual vimrc filename. Do not assume the GitHub repository name proves the configuration filename.
- Resolve repository paths from the script location. Avoid fragile instructions that clone the directory into the same path intended for the `~/.vimrc` file.
- Fetch plugin-manager files over HTTPS with failure detection and atomic installation. Keep package installation in setup scripts rather than Vim startup.
- Do not execute the shared installer as root. Use sudo only for the apt operations, keeping personal files user-owned.
- Do not silently install Homebrew via a remote shell pipeline. If unavailable, give the official installation prerequisite and let the user complete it.
- On macOS, use Homebrew Vim and LLVM; verify that the selected Vim is the Homebrew binary.
- On Debian, plan for `vim clangd git curl build-essential`. Check package availability at implementation time instead of pinning an unverified version.
- If using vim-plug, install plugins against the intended vimrc synchronously. Check installation results, not just a zero exit from a command that later quits Vim. Provide the manual `:PlugInstall` fallback.
- Avoid interactive prompts for routine repeat installation. If a conflict requires a decision, explain the exact affected path.
- `doctor.sh` must inspect the intended Vim/configuration, the plugin manager and plugins, required Vim features, executable resolution, and compiler/SDK availability. Missing required components should give a nonzero status. Keep optional checks distinguishable.

Linux scripts should be prepared now but not executed on the Mac. Do not add Docker or another large dependency just to simulate Debian; syntax checks and careful review are useful, but do not prove Debian runtime behavior.

## Phase 4: persist full documentation in the repository

Update the existing README in place, respecting its filename/case. Use the supplied `README.md` as a scaffold only after reconciling it with the actual repository.

The finished README must explain both existing configuration and new features. Include actual keybindings, dependencies, install commands, project flags, diagnostics commands, plugin management, and rollback. Remove unverified inventory placeholders and replace proposed script names with the files you implemented.

Create or update these focused documents:

- `docs/setup-macos.md`: prerequisites, installation from an existing checkout or fresh clone, Vim selection, clangd resolution, SDK/header troubleshooting, validation, and rollback.
- `docs/setup-debian.md`: exact later installation sequence using the same repo, apt dependencies, validation, and rollback.
- `docs/keybindings.md`: verified existing and new mappings, their modes, and any displaced default behavior.
- `docs/troubleshooting.md`: `:ALEInfo`, missing manager/plugins, PATH problems, missing headers, compile database discovery, diagnostic timing, completion, and mapping conflicts.
- `docs/implementation-status.md`: completed work, actual validation results, outstanding manual steps, and Debian runtime validation marked pending.

Keep this handoff in the repo as well, and clearly distinguish its original task requirements from final implementation status. Do not leave the supplied README's draft status in place after verifying and implementing everything it describes.

## Phase 5: include a small project example

Add `examples/c/` with a correct, minimal C program, a struct member completion opportunity, at least one callable function for navigation, a simple build command or Makefile, and `compile_flags.txt` containing:

```text
-Wall
-Wextra
-Wpedantic
-std=c17
```

Include instructions to introduce a temporary type error and then undo it. Keep the committed working example compilable. Do not enable sanitizers or extra tools just to demonstrate editor setup.

Explain that `compile_flags.txt` belongs in each real project's root and assumes common flags across its source files. Teach `compile_commands.json` as the next step for differing per-file flags or larger builds. Explain how to generate it with CMake or appropriate build tooling and how clangd discovers a database in a build directory.

Do not copy the example's C flags into the global vimrc or a global clangd config. Avoid committing generated compile databases with machine-specific absolute paths. On macOS, resolve SDK/header issues from the real toolchain and logs rather than hardcoding local SDK paths in the shared repo.

## Phase 6: validate and report

Use checks appropriate to these changes; no large test framework is necessary.

1. Validate shell syntax using a shell compatible with the supported systems. Use ShellCheck if it is already available, or explain that it was not run.
2. Source the intended vimrc in noninteractive Vim and inspect errors without hiding missing-function or plugin failures.
3. Exercise script path handling and backup/idempotence behavior in an isolated temporary HOME using local fixtures; do not modify the real home for a simulation or install packages into it.
4. Install and validate the setup on this Mac within the terminal session's permissions. Record which Vim and clangd binaries were used.
5. Build the correct C example using the real compiler and documented flags.
6. Confirm clangd's project analysis with `clangd --check` or equivalent diagnostics using the example's build flags. A temporary intentional error should be detected; the corrected example should clear it.
7. Validate real ALE attachment and unsaved diagnostics, struct member completion, navigation, hover, pairing, deletion/skipping, and brace indentation. Headless config loading alone does not establish these behaviors. Automate meaningful interaction checks where feasible; list any checks requiring me to try them in interactive Vim.
8. Verify that re-sourcing the config does not duplicate autocmds, and ordinary editing works when optional dependencies are unavailable.
9. Review the diff for unrelated changes, machine-specific paths, broken existing bindings, and inaccurate documentation.
10. Mark Debian package installation and interactive runtime testing pending. Distinguish reviewed/syntax-checked scripts from actually tested setup.

Finish with a concise explanation of what changed, which checks passed, the exact command to launch the configured Vim on my Mac, and the future Debian command sequence. Identify actual blockers or remaining manual checks. Do not stop after producing a plan when implementation can proceed.

## Reference sources

Consult official project docs and help for the versions actually installed:

- [ALE](https://github.com/dense-analysis/ale)
- [ALE help](https://github.com/dense-analysis/ale/blob/master/doc/ale.txt)
- [auto-pairs](https://github.com/jiangmiao/auto-pairs)
- [vim-plug](https://github.com/junegunn/vim-plug)
- [vim-plug CLI installation tips](https://github.com/junegunn/vim-plug/wiki/tips)
- [clangd installation](https://clangd.llvm.org/installation.html)
- [clangd compile commands](https://clangd.llvm.org/design/compile-commands)
- [clangd system headers](https://clangd.llvm.org/guides/system-headers)
- [Homebrew](https://brew.sh/)
- [Debian package search](https://packages.debian.org/)
