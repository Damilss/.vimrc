# C example

A tiny dynamic array (`struct vec` in `vec.h`/`vec.c`) and a `main.c` that uses it. It is enough to exercise diagnostics, struct-member completion, navigation, and hover.

```bash
make            # cc -Wall -Wextra -Wpedantic -std=c17
./squares       # 10 squares, sum 385
make clean
make CC=gcc-15  # any other compiler
```

The committed code compiles without warnings with Apple clang 21 and GCC 15.

## Try the editor features

Open `vim main.c` from this directory.

1. **Diagnostics on unsaved edits.** Below `struct vec numbers = {0};` add a line:

   ```c
   int *oops = 3.5;
   ```

   Don't save. Within a moment the sign column shows an error, the line is underlined, and its message appears at the bottom when the cursor is on it. `]e` / `[e` jump between diagnostics, `:lopen` lists them, and `:ALEDetail` shows the full text.

   **Undo it** with `u` (or delete the line). The error clears. Don't save the broken version. If you did, `git checkout -- main.c` restores it.
2. **Struct member completion.** On a new line inside `main`, type `numbers.` and a menu offers `data`, `len`, `cap`. Use `Tab` to select and `Ctrl-Y` to accept. Then undo.
3. **Navigation.** Put the cursor on `vec_sum` and press `gd`; you land on its declaration in `vec.h`, or on the definition in `vec.c` once clangd has seen that file. `Ctrl-O` returns. On `len` in `numbers.len`, `gd` goes to the field. On `vec_free`, `gr` lists references.
4. **Hover.** `K` on `vec_push` shows its signature and comment in a popup.
5. **Pairing.** Type `(`, `[`, `{`, `"`, or `'`; the closer appears. Type the closer and you skip over it. Backspace inside an empty pair removes both. Typing `{` then Enter at the end of a line opens an indented block.
6. Build again with `make` to confirm the file is back to its working state.

## Telling clangd how a project builds

### `compile_flags.txt`: same flags for every file

This directory's `compile_flags.txt`:

```text
-Wall
-Wextra
-Wpedantic
-std=c17
```

clangd applies these flags to **every** source file below the directory that holds the file. In a real project it goes in the project root, next to the sources or the top-level Makefile. Keep it in sync with the flags you actually build with (here, the Makefile's `CFLAGS`). Add include paths relative to the root, e.g. `-Iinclude`, and defines like `-DDEBUG`.

It is the right tool for a small project where all files share the same flags. It is per-project; that's why none of these flags are in the vimrc. A C++ project gets its own file with e.g. `-std=c++20`.

### `compile_commands.json`: the next step

Use a compilation database once files need different flags (a library and its tests, mixed C and C++, generated headers) or the project uses a real build system. It lists the exact compile command for each file, and it lets clangd index the whole project in the background, so `gr` finds references in files you haven't opened.

Generate it; don't write it by hand:

```bash
# CMake
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON   # writes build/compile_commands.json

# Make or any other build: record the real compiler invocations
bear -- make                                           # writes ./compile_commands.json
```

clangd looks for `compile_commands.json` in each parent directory of the file you edit, and also in a `build/` subdirectory at each level. So `build/compile_commands.json` at the project root is found automatically. For any other build directory, symlink it: `ln -s out/compile_commands.json .`. You can also add a `.clangd` file with `CompileFlags: { CompilationDatabase: out }`.

The generated file contains absolute paths from your machine. **Don't commit it**; add `compile_commands.json` (and `build/`) to `.gitignore`. Regenerate it after changing build settings, then run `:ALEStopAllLSPs` in Vim so clangd reloads it.

References: [clangd: compile commands](https://clangd.llvm.org/design/compile-commands), [clangd: system headers](https://clangd.llvm.org/guides/system-headers).
