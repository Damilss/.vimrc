" Interactive smoke test for the vimrc, run by scripts/smoke-test.sh.
"
" Vim runs inside a pseudo-terminal so its main loop, timers, autocommands,
" and ALE's clangd job behave as they do when you type.  Each step queues
" keys with feedkeys(), then polls until a condition holds or it times out.
" Buffers are never written; the example files are left untouched.

let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
let s:out = empty($VIMRC_SMOKE_OUT) ? s:root . '/smoke-results.txt' : $VIMRC_SMOKE_OUT
let s:results = []
let s:failed = 0
let s:steps = []
let s:i = -1

function! s:Report(ok, name, detail) abort
  call add(s:results, (a:ok ? 'ok    ' : 'FAIL  ') . a:name
        \ . (!a:ok && !empty(a:detail) ? '  -- ' . a:detail : ''))
  if !a:ok
    let s:failed = 1
  endif
endfunction

function! s:Finish() abort
  call add(s:results, s:failed ? 'RESULT: FAIL' : 'RESULT: PASS')
  call writefile(s:results, s:out)
  qa!
endfunction

" A step: run() starts it, until() is polled every 100 ms, then check()
" returns [ok, detail].  until() defaults to "keys done, back in Normal mode".
function! s:Add(name, run, check, ...) abort
  call add(s:steps, {'name': a:name, 'run': a:run, 'check': a:check,
        \ 'until': a:0 >= 1 ? a:1 : function('s:Idle'),
        \ 'timeout': a:0 >= 2 ? a:2 : 3000})
endfunction

function! s:Idle() abort
  return mode() ==# 'n' && !pumvisible()
endfunction

function! s:Next() abort
  let s:i += 1
  if s:i >= len(s:steps)
    call s:Finish()
    return
  endif
  let s:step = s:steps[s:i]
  let s:waited = 0
  try
    call s:step.run()
  catch
    call s:Report(0, s:step.name, v:exception)
    call timer_start(10, {-> s:Next()})
    return
  endtry
  call timer_start(100, function('s:Poll'))
endfunction

function! s:Poll(timer) abort
  try
    if !s:step.until() && s:waited < s:step.timeout
      let s:waited += 100
      call timer_start(100, function('s:Poll'))
      return
    endif
    let [l:ok, l:detail] = s:step.check()
    call s:Report(l:ok, s:step.name, l:detail)
  catch
    call s:Report(0, s:step.name, v:exception)
  endtry
  call s:Next()
endfunction

" The current buffer's loclist, or the given buffer's.
function! s:Loclist(...) abort
  return get(get(g:, 'ale_buffer_info', {}), a:0 ? a:1 : bufnr(''), {'loclist': []}).loclist
endfunction

function! s:ErrorsOn(lnum, ...) abort
  return filter(copy(call('s:Loclist', a:000)), 'v:val.type ==# "E" && v:val.lnum == a:lnum')
endfunction

function! s:Expect(expected) abort
  let l:actual = getline(1, '$')
  return [l:actual ==# a:expected, 'got ' . string(l:actual)]
endfunction

function! s:PreviewWindows() abort
  return filter(range(1, winnr('$')),
        \ 'getwinvar(v:val, "&filetype") =~# "^ale-preview" || getwinvar(v:val, "&buftype") ==# "quickfix"')
endfunction

" ---------- Loading and mappings (main.c) ----------
let s:main = bufnr('')

call s:Add('ALE loaded with clangd for C',
      \ {-> 0},
      \ {-> [exists(':ALEInfo') == 2 && map(ale#linter#Get('c'), 'v:val.name') ==# ['clangd'],
      \      'linters: ' . (exists('*ale#linter#Get') ? string(map(ale#linter#Get('c'), 'v:val.name')) : 'ALE missing')]},
      \ {-> 1})
call s:Add('completion enabled before ALE loaded',
      \ {-> 0},
      \ {-> [g:ale_completion_enabled == 1 && exists('#ALECompletionGroup'), 'ALECompletionGroup missing']},
      \ {-> 1})
call s:Add('C buffer maps gd gr K ]e [e to ALE',
      \ {-> 0},
      \ {-> [maparg('gd', 'n') =~# 'ALEGoToDefinition' && maparg('gr', 'n') =~# 'ALEFindReferences'
      \      && maparg('K', 'n') =~# 'ALEHover' && maparg(']e', 'n') =~# 'ALENextWrap'
      \      && maparg('[e', 'n') =~# 'ALEPreviousWrap', 'gd=' . maparg('gd', 'n')]},
      \ {-> 1})
" Ctrl-H is mapped only when Backspace (t_kb) is not ^H itself.
call s:Add('Ctrl-H still deletes a word (not taken by auto-pairs)',
      \ {-> 0},
      \ {-> [&t_kb ==# "\<C-H>"
      \      ? empty(maparg('<C-H>', 'i'))
      \      : maparg('<C-H>', 'i', 0, 1).rhs ==# '<C-W>' && !maparg('<C-H>', 'i', 0, 1).buffer,
      \      't_kb=' . strtrans(&t_kb) . ' ' . string(maparg('<C-H>', 'i', 0, 1))]},
      \ {-> 1})
call s:Add('Ctrl-Backspace key deletes a word',
      \ {-> 0},
      \ {-> [maparg('<C-BS>', 'i') ==# '<C-W>', string(maparg('<C-BS>', 'i', 0, 1))]},
      \ {-> 1})
call s:Add('Enter is handled by auto-pairs',
      \ {-> 0},
      \ {-> [maparg('<CR>', 'i') =~# 'AutoPairsReturn', maparg('<CR>', 'i')]},
      \ {-> 1})

" ---------- Diagnostics on unsaved edits ----------
call s:Add('unsaved type error is reported',
      \ {-> feedkeys("7Goint *oops = 3.5;\<Esc>", 't')},
      \ {-> [&modified && !empty(s:ErrorsOn(8)), 'loclist: ' . string(s:Loclist())]},
      \ {-> s:Idle() && !empty(s:ErrorsOn(8))}, 30000)
call s:Add('undo clears the error',
      \ {-> feedkeys('u', 't')},
      \ {-> [!&modified && empty(filter(copy(s:Loclist()), 'v:val.type ==# "E"')),
      \      'loclist: ' . string(s:Loclist())]},
      \ {-> s:Idle() && !&modified && empty(filter(copy(s:Loclist()), 'v:val.type ==# "E"'))}, 10000)
" clangd reports only the first missing header; the vimrc marks the rest,
" except inside #if blocks.  'n': auto-pairs would double the quotes.
call s:Add('every missing #include is reported, not just the first',
      \ {-> feedkeys("ggO#include \"nope1.h\"\<CR>#include \"nope2.h\"\<CR>"
      \      . "#if 0\<CR>#include \"nope3.h\"\<CR>#endif\<Esc>", 'nt')},
      \ {-> [!empty(s:ErrorsOn(1)) && !empty(s:ErrorsOn(2)) && empty(s:ErrorsOn(4)),
      \      'loclist: ' . string(s:Loclist())]},
      \ {-> s:Idle() && !empty(s:ErrorsOn(1)) && !empty(s:ErrorsOn(2))}, 30000)
" clangd reports line 1 itself.  The includes after a missing one that it
" does find (<stdio.h>, "vec.h") must not be marked.
function! s:IncludeMarks(...) abort
  return map(filter(copy(call('s:Loclist', a:000)), 'v:val.linter_name is# "includes"'), 'v:val.lnum')
endfunction
call s:Add('includes clangd finds after a missing one are not marked',
      \ {-> 0},
      \ {-> [s:IncludeMarks() ==# [2], 'includes marks: ' . string(s:IncludeMarks())]},
      \ {-> 1})
call s:Add('undo clears the missing #include errors',
      \ {-> feedkeys('u', 't')},
      \ {-> [!&modified && empty(filter(copy(s:Loclist()), 'v:val.type ==# "E"')),
      \      'loclist: ' . string(s:Loclist())]},
      \ {-> s:Idle() && !&modified && empty(filter(copy(s:Loclist()), 'v:val.type ==# "E"'))}, 10000)
" With no compile_commands.json, compile_flags.txt, or .clangd above the
" file, only clangd's own report shows.  Wait a while after it appears, so a
" second error would have had time to arrive.
function! s:HeldFor(cond, ms) abort
  if !a:cond()
    let s:held_since = []
    return 0
  endif
  if empty(get(s:, 'held_since', []))
    let s:held_since = reltime()
  endif
  return reltimefloat(reltime(s:held_since)) * 1000 >= a:ms
endfunction
call s:Add('outside a configured project only the first missing #include shows',
      \ {-> [execute('edit ' . fnameescape(tempname() . '.c')),
      \      feedkeys("i#include \"nope1.h\"\<CR>#include \"nope2.h\"\<Esc>", 'nt')]},
      \ {-> [!empty(s:ErrorsOn(1)) && empty(s:ErrorsOn(2)), 'loclist: ' . string(s:Loclist())]},
      \ {-> s:Idle() && s:HeldFor({-> !empty(s:ErrorsOn(1))}, 1500)}, 30000)
call s:Add('back to main.c',
      \ {-> execute('bwipe! | buffer ' . s:main)},
      \ {-> [bufnr('') == s:main, 'buffer ' . bufnr('')]},
      \ {-> 1})
" ALE says a check finished without saying which buffer it was for, so the
" marks must still reach main.c when another buffer is current by then.
" Open a window the moment ALE starts checking main.c, while clangd works.
function! s:SwitchWhenLintStarts() abort
  let s:switched = 0
  augroup smoke_switch
    autocmd!
    autocmd User ALELintPre ++once let s:switched = bufnr('') == s:main | new
  augroup END
  call feedkeys("ggO#include \"nope1.h\"\<CR>#include \"nope2.h\"\<Esc>", 'nt')
endfunction
call s:Add('every missing #include is marked after switching windows mid-check',
      \ function('s:SwitchWhenLintStarts'),
      \ {-> [s:switched && bufnr('') != s:main
      \      && !empty(s:ErrorsOn(1, s:main)) && !empty(s:ErrorsOn(2, s:main)),
      \      'switched: ' . s:switched . ', main.c loclist: ' . string(s:Loclist(s:main))]},
      \ {-> s:switched && !empty(s:ErrorsOn(1, s:main)) && !empty(s:ErrorsOn(2, s:main))}, 30000)
call s:Add('close that window and undo',
      \ {-> [execute('autocmd! smoke_switch'), execute('bwipe!'), feedkeys('u', 't')]},
      \ {-> [bufnr('') == s:main && !&modified && empty(filter(copy(s:Loclist()), 'v:val.type ==# "E"')),
      \      'buffer ' . bufnr('') . ', loclist: ' . string(s:Loclist())]},
      \ {-> s:Idle() && bufnr('') == s:main && !&modified
      \      && empty(filter(copy(s:Loclist()), 'v:val.type ==# "E"'))}, 10000)
" In a configured folder, but with clangd turned off for the buffer: the
" include check must not start clangd for it.  The filetype is set after
" b:ale_linters, so ALE never checks the buffer with clangd.
function! s:OpenWithoutClangd() abort
  let l:dir = tempname()
  call mkdir(l:dir, 'p')
  call writefile([], l:dir . '/compile_flags.txt')
  let s:connections = len(ale#lsp#GetConnections())
  new
  let b:ale_linters = ['cc']
  execute 'file ' . fnameescape(l:dir . '/off.c')
  setfiletype c
  call feedkeys("i#include \"nope1.h\"\<CR>#include \"nope2.h\"\<Esc>", 'nt')
endfunction
call s:Add('with clangd turned off for a buffer, the include check leaves it alone',
      \ function('s:OpenWithoutClangd'),
      \ {-> [get(b:, 'ale_linted', 0) > 0 && len(ale#lsp#GetConnections()) == s:connections
      \      && empty(filter(copy(s:Loclist()), 'v:val.linter_name is# "includes"')),
      \      'checked ' . get(b:, 'ale_linted', 0) . 'x, language servers ' . s:connections
      \      . ' -> ' . len(ale#lsp#GetConnections()) . ', loclist: ' . string(s:Loclist())]},
      \ {-> s:Idle() && s:HeldFor({-> get(b:, 'ale_linted', 0) > 0}, 1500)}, 30000)
call s:Add('close that buffer',
      \ {-> execute('bwipe!')},
      \ {-> [bufnr('') == s:main, 'buffer ' . bufnr('')]},
      \ {-> 1})
" In a configured folder, an #include inside a /* */ comment isn't marked:
" clangd ignores it.  Then turning clangd off for the buffer clears the
" marks it had.
function! s:OpenCommented() abort
  let l:dir = tempname()
  call mkdir(l:dir, 'p')
  call writefile([], l:dir . '/compile_flags.txt')
  call writefile(['#include "nope1.h"', '#include "nope2.h"', '/*', '#include "nope3.h"', '*/'],
        \ l:dir . '/commented.c')
  execute 'edit ' . fnameescape(l:dir . '/commented.c')
endfunction
call s:Add('an #include inside a /* */ comment is not marked',
      \ function('s:OpenCommented'),
      \ {-> [s:IncludeMarks() ==# [2], 'includes marks: ' . string(s:IncludeMarks())]},
      \ {-> s:Idle() && s:HeldFor({-> !empty(s:IncludeMarks())}, 1500)}, 30000)
call s:Add('turning clangd off for a buffer clears its marks',
      \ {-> [execute('let b:ale_linters = [''cc'']'), execute('ALELint')]},
      \ {-> [empty(s:IncludeMarks()), 'includes marks: ' . string(s:IncludeMarks())]},
      \ {-> s:Idle() && empty(s:IncludeMarks())}, 10000)
call s:Add('close that file',
      \ {-> execute('bwipe!')},
      \ {-> [bufnr('') == s:main, 'buffer ' . bufnr('')]},
      \ {-> 1})
" The ' in 1'000 is a digit separator, not a quote, so the /* after it
" still starts a comment.  C++, where clang agrees.
function! s:OpenDigitSeparator() abort
  let l:dir = tempname()
  call mkdir(l:dir, 'p')
  call writefile(['-std=c++17'], l:dir . '/compile_flags.txt')
  call writefile(['#include "nope1.h"', '#include "nope2.h"', 'int n = 1''000; /*',
        \ '#include "nope3.h"', '*/'], l:dir . '/separator.cpp')
  execute 'edit ' . fnameescape(l:dir . '/separator.cpp')
endfunction
call s:Add('a digit separator before a /* */ comment does not hide it',
      \ function('s:OpenDigitSeparator'),
      \ {-> [s:IncludeMarks() ==# [2], 'includes marks: ' . string(s:IncludeMarks())]},
      \ {-> s:Idle() && s:HeldFor({-> !empty(s:IncludeMarks())}, 1500)}, 30000)
" A header guard spelled #if !defined(X), with a blank line before its
" #define, is not an #if block.  Unsaved header in examples/c.
function! s:OpenGuardedHeader() abort
  call execute(['bwipe!', 'edit ' . fnameescape(s:root . '/examples/c/probe.h'), 'setlocal filetype=c'])
  call setline(1, ['#if !defined(PROBE_H)', '', '#define PROBE_H', '#include "nope1.h"',
        \ '#include "nope2.h"', '#endif'])
  ALELint
endfunction
call s:Add('includes inside an #if !defined() guard are all marked',
      \ function('s:OpenGuardedHeader'),
      \ {-> [!empty(s:ErrorsOn(4)) && s:IncludeMarks() ==# [5],
      \      'includes marks: ' . string(s:IncludeMarks()) . ', loclist: ' . string(s:Loclist())]},
      \ {-> s:Idle() && s:HeldFor({-> !empty(s:IncludeMarks())}, 1000)}, 10000)
" ALE runs clangd for a compound filetype too.  Drop the marks first, so
" only a new check can bring them back, and change the text, or clangd
" sends no new results.
call s:Add('a compound filetype (c.doxygen) gets the include check',
      \ {-> [ale#other_source#ShowResults(bufnr(''), 'includes', []), append('$', ''),
      \      execute(['setlocal filetype=c.doxygen', 'ALELint'])]},
      \ {-> [&filetype is# 'c.doxygen' && s:IncludeMarks() ==# [5],
      \      'filetype ' . &filetype . ', includes marks: ' . string(s:IncludeMarks())]},
      \ {-> s:Idle() && s:HeldFor({-> !empty(s:IncludeMarks())}, 500)}, 10000)
" Replies from clangd, faked: one about older text is ignored, an error or
" null one clears the marks.
function! s:FakeReplies() abort
  let l:Show = function('<SNR>' . getscriptinfo({'name': '/\.vimrc$'})[0].sid . '_ShowIncludes')
  let s:marks = []
  for l:reply in [[-1, {'result': v:null}], [0, {'error': {'code': -32603, 'message': 'x'}}],
        \ [0, {'result': []}], [0, {'result': v:null}]]
    call l:Show(bufnr(''), b:changedtick + l:reply[0], l:reply[1])
    call add(s:marks, s:IncludeMarks())
  endfor
endfunction
call s:Add('an error or null documentLink reply clears the marks, a stale one does not',
      \ function('s:FakeReplies'),
      \ {-> [s:marks ==# [[5], [], [5], []], 'includes marks after each reply: ' . string(s:marks)]},
      \ {-> 1})
" An edit after ALE sent clangd the text, before its results arrive: the
" links clangd then gives are for the old lines, so they must not be used.
" The long lint delay holds off the check of the new text.
function! s:EditWhileClangdWorks() abort
  call execute(['bwipe!', 'edit ' . fnameescape(s:root . '/examples/c/stale.c')])
  let b:ale_lint_delay = 5000
  call setline(1, ['#include "nope1.h"', '#include <stdio.h>', '#include "nope2.h"'])
  let s:mid_check = 0
  let s:linted = get(b:, 'ale_linted', 0)
  augroup smoke_stale
    autocmd!
    autocmd User ALELintPre ++once call timer_start(0, function('s:EditMidCheck'))
  augroup END
  ALELint
endfunction
function! s:EditMidCheck(timer) abort
  let s:mid_check = get(b:, 'ale_linted', 0) == s:linted
  call append(0, '')
endfunction
call s:Add('an edit during a check does not mark a found #include',
      \ function('s:EditWhileClangdWorks'),
      \ {-> [s:mid_check && getline(1) is# ''
      \      && empty(filter(s:IncludeMarks(), 'getline(v:val) =~# "stdio"')),
      \      'edited mid-check: ' . s:mid_check . ', includes marks: ' . string(s:IncludeMarks())]},
      \ {-> s:Idle() && s:HeldFor({-> get(b:, 'ale_linted', 0) > 0}, 1500)}, 4500)
call s:Add('close that file',
      \ {-> execute(['autocmd! smoke_stale', 'bwipe!', 'buffer ' . s:main])},
      \ {-> [bufnr('') == s:main && !&modified, 'buffer ' . bufnr('')]},
      \ {-> 1})

" ---------- Completion ----------
function! s:CompletionWords() abort
  return pumvisible() ? map(copy(complete_info(['items']).items), 'v:val.word') : []
endfunction
call s:Add('struct member completion after "numbers."',
      \ {-> feedkeys("7Gonumbers.", 't')},
      \ {-> [index(s:CompletionWords(), 'len') >= 0 && index(s:CompletionWords(), 'data') >= 0
      \      && index(s:CompletionWords(), 'cap') >= 0, 'menu: ' . string(s:CompletionWords())]},
      \ {-> pumvisible() && !empty(s:CompletionWords())}, 10000)
call s:Add('Tab selects in the menu, Ctrl-Y accepts',
      \ {-> feedkeys("\<Tab>\<C-Y>", 't')},
      \ {-> [getline(8) =~# '^\s*numbers\.\(data\|len\|cap\)$', 'line 8: ' . string(getline(8))]},
      \ {-> !pumvisible()}, 3000)
call s:Add('leave Insert mode and undo the completion test',
      \ {-> feedkeys("\<Esc>u", 't')},
      \ {-> [!&modified, 'buffer still modified']},
      \ {-> s:Idle() && !&modified})

" ---------- Navigation and hover ----------
call s:Add('gd on a function call jumps to vec.h/vec.c',
      \ {-> [search('vec_sum(&numbers)', 'w'), feedkeys('gd', 't')]},
      \ {-> [expand('%:t') =~# '^vec\.[ch]$' && getline('.') =~# 'vec_sum', expand('%:t') . ': ' . getline('.')]},
      \ {-> expand('%:t') =~# '^vec\.[ch]$'}, 10000)
call s:Add('gd on a struct member jumps to its field',
      \ {-> [execute('buffer ' . s:main), search('numbers\.\zslen', 'w'), feedkeys('gd', 't')]},
      \ {-> [expand('%:t') ==# 'vec.h' && getline('.') =~# 'size_t len;', expand('%:t') . ': ' . getline('.')]},
      \ {-> expand('%:t') ==# 'vec.h'}, 10000)
function! s:HoverShown() abort
  let l:shown = !empty(popup_list())
  call popup_clear()
  return [l:shown, 'no popup']
endfunction
call s:Add('K shows hover information in a popup',
      \ {-> [execute('buffer ' . s:main), search('vec_push(&numbers', 'w'), feedkeys('K', 't')]},
      \ function('s:HoverShown'),
      \ {-> !empty(popup_list())}, 10000)
call s:Add('gr lists references',
      \ {-> [search('vec_free(&numbers)', 'w'), feedkeys('gr', 't')]},
      \ {-> [!empty(s:PreviewWindows()), 'no references window']},
      \ {-> !empty(s:PreviewWindows())}, 10000)
call s:Add('close the references window',
      \ {-> [execute('pclose'), execute('cclose'), execute('buffer ' . s:main)]},
      \ {-> [bufnr('') == s:main, 'not back in main.c']},
      \ {-> 1})

" ---------- Pairing and Enter in a scratch C buffer ----------
function! s:Pair(name, keys, expected) abort
  call s:Add(a:name,
        \ {-> [execute('silent %delete _'), feedkeys(a:keys . "\<Esc>", 't')]},
        \ {-> s:Expect(a:expected)})
endfunction

call s:Add('open a scratch C buffer',
      \ {-> execute('edit ' . fnameescape(tempname() . '.c'))},
      \ {-> [&filetype ==# 'c' && maparg('(', 'i') =~# 'AutoPairs', 'ft=' . &filetype . ' (=' . maparg('(', 'i')]},
      \ {-> 1})
call s:Pair('( inserts ) and leaves the cursor between', 'ifoo(x', ['foo(x)'])
call s:Pair('typing ) skips the existing closer', 'ifoo(x)', ['foo(x)'])
call s:Pair('[ pairs', 'ia[0', ['a[0]'])
call s:Pair('{ pairs', 'i{x', ['{x}'])
call s:Pair('Backspace deletes an empty pair', "ifoo(\<BS>", ['foo'])
call s:Pair('double quotes pair', 'iputs("hi', ['puts("hi")'])
call s:Pair('typing " skips the closing quote', 'i"hi"', ['"hi"'])
call s:Pair('escaped quote inside a string', 'i"a\"b"', ['"a\"b"'])
call s:Pair('character literal', "ic = 'x'", ["c = 'x'"])
call s:Pair('apostrophe after a letter is not paired', "i// don't", ["// don't"])
call s:Pair('Enter between {} opens an indented block',
      \ "iint f(void) {\<CR>return 0;", ['int f(void) {', "\treturn 0;", '}'])
call s:Pair('Tab inserts a tab when no menu is open', "i\<Tab>x", ["\tx"])

" ---------- Syntax colors ----------
" Each scratch buffer opens in a split, so wiping it returns to the scratch
" C buffer with its window layout unchanged.
function! s:SynAt(lnum, pat) abort
  return synIDattr(synID(a:lnum, match(getline(a:lnum), a:pat) + 1, 1), 'name')
endfunction
function! s:Scratch(ext, lines) abort
  execute 'new ' . fnameescape(tempname() . a:ext)
  call setline(1, a:lines)
endfunction

call s:Add('open a scratch Swift buffer',
      \ {-> [execute('let [s:scratch_c, s:scratch_wins] = [bufnr(""), winnr("$")]'),
      \      s:Scratch('.swift', ['class func bar() {}', 'class var x: Int', 'class Foo {}'])]},
      \ {-> [&filetype ==# 'swift', 'ft=' . &filetype]},
      \ {-> 1})
call s:Add('Swift keywords after class are not type names',
      \ {-> 0},
      \ {-> [s:SynAt(1, 'func') ==# 'swiftFuncDefinition' && s:SynAt(2, 'var') ==# 'swiftVarDefinition',
      \      'func: ' . s:SynAt(1, 'func') . ', var: ' . s:SynAt(2, 'var')]},
      \ {-> 1})
call s:Add('Swift class name is a type name',
      \ {-> 0},
      \ {-> [s:SynAt(3, 'Foo') ==# 'VscSwiftTypeName', s:SynAt(3, 'Foo')]},
      \ {-> 1})
call s:Add('open a scratch assembly buffer',
      \ {-> [execute('bwipe!'),
      \      s:Scratch('.s', ['  .type main, @function', '  call puts@PLT', '  mov r0, r1  @ copy'])]},
      \ {-> [&filetype ==# 'asm', 'ft=' . &filetype]},
      \ {-> 1})
call s:Add('asm @function and puts@PLT are not comments',
      \ {-> 0},
      \ {-> [s:SynAt(1, '@') !=# 'asmComment' && s:SynAt(2, '@') !=# 'asmComment',
      \      '@function: ' . s:SynAt(1, '@') . ', @PLT: ' . s:SynAt(2, '@')]},
      \ {-> 1})
call s:Add('ARM @ comment is a comment',
      \ {-> 0},
      \ {-> [s:SynAt(3, '@') ==# 'asmComment', s:SynAt(3, '@')]},
      \ {-> 1})
call s:Add('closing the scratch buffers returns to the C buffer',
      \ {-> execute('bwipe!')},
      \ {-> [bufnr('') == s:scratch_c && winnr('$') == s:scratch_wins, 'buffer ' . bufnr('') . ', windows ' . winnr('$')]},
      \ {-> 1})

" ---------- Re-sourcing ----------
function! s:AutocmdCount(group, pattern) abort
  let l:out = execute('autocmd ' . a:group)
  return len(filter(split(l:out, "\n"), 'v:val =~# a:pattern'))
endfunction
function! s:CountAutocmds() abort
  return [s:AutocmdCount('vimrc_ale', 's:'), s:AutocmdCount('amoled_black_shiny_markdown', 's:')]
endfunction
function! s:SourceTwice() abort
  let s:autocmds_before = s:CountAutocmds()
  execute 'source ' . fnameescape(s:root . '/.vimrc')
  execute 'source ' . fnameescape(s:root . '/.vimrc')
endfunction
call s:Add('re-sourcing the vimrc twice does not duplicate autocmds',
      \ function('s:SourceTwice'),
      \ {-> [s:CountAutocmds() ==# s:autocmds_before && s:autocmds_before[0] > 0,
      \      'before ' . string(s:autocmds_before) . ', after ' . string(s:CountAutocmds())]},
      \ {-> 1})
call s:Add('ALE highlight links survive re-sourcing',
      \ {-> 0},
      \ {-> [synIDattr(synIDtrans(hlID('ALEErrorSign')), 'name') ==# 'DiagnosticError',
      \      synIDattr(synIDtrans(hlID('ALEErrorSign')), 'name')]},
      \ {-> 1})
call s:Add('gd keeps its default in a non-language-server buffer',
      \ {-> execute('enew! | setfiletype text')},
      \ {-> [empty(maparg('gd', 'n')), maparg('gd', 'n')]},
      \ {-> 1})

call s:Add('no errors in :messages',
      \ {-> 0},
      \ {-> [execute('messages') !~# '\<E\d\+:', execute('messages')]},
      \ {-> 1})

" Hard stop in case something hangs.
call timer_start(180000, {-> [s:Report(0, 'watchdog', 'test timed out'), s:Finish()]})
call timer_start(500, {-> s:Next()})
