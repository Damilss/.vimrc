# C Comment Continuation (Local)

A declarative VS Code extension that adds ` * ` after Enter inside `/* ... */`
and `/** ... */` comments in C, C++, and CUDA C++. It also applies to VSCodeVim's
`o`, which uses VS Code's Insert Line Below command.

VSCodeVim's `O` adjusts the inserted text back to the current line's indentation
and can remove the comment leader. Use Enter or `o` for comment continuation.

It has no executable code, dependencies, or language server. Keep clangd enabled
and `C_Cpp.intelliSenseEngine` disabled. The last two rules preserve VS Code's
built-in control-statement outdent and inline `//` splitting behavior.

To install manually, copy this directory to
`~/.vscode/extensions/emilio-local.c-comment-continuation-0.1.0`, then run
**Developer: Reload Window**. Remove that directory to uninstall.

`editor.autoIndent` must be `advanced` or `full` (the default).

Continuation lines preserve 2–256 spaces after `*`, including when the
line contains only the leader and padding. Other lines retain the existing
comment continuation rules. These declarative rules work with Enter and
VSCodeVim’s `o`; reload the VS Code window after updating the extension.
