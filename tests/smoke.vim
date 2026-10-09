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

function! s:Loclist() abort
  return get(get(g:, 'ale_buffer_info', {}), bufnr(''), {'loclist': []}).loclist
endfunction

function! s:ErrorsOn(lnum) abort
  return filter(copy(s:Loclist()), 'v:val.type ==# "E" && v:val.lnum == a:lnum')
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
call s:Add('Ctrl-H still deletes a word (not taken by auto-pairs)',
      \ {-> 0},
      \ {-> [maparg('<C-H>', 'i', 0, 1).rhs ==# '<C-W>' && !maparg('<C-H>', 'i', 0, 1).buffer,
      \      string(maparg('<C-H>', 'i', 0, 1))]},
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

" ---------- Grammar checking (fake Ollama started by smoke-test.sh) ----------
function! s:GrammarItems() abort
  return filter(copy(s:Loclist()), 'v:val.linter_name ==# "grammar"')
endfunction

function! s:GrammarLines() abort
  return map(s:GrammarItems(), 'v:val.lnum')
endfunction

if !empty($VIMRC_SMOKE_GRAMMAR_HOST)
  let g:vimrc_grammar_host = $VIMRC_SMOKE_GRAMMAR_HOST

  call s:Add('open a scratch Markdown buffer with the grammar linter',
        \ {-> execute('edit! ' . fnameescape(tempname() . '.md'))},
        \ {-> [&filetype ==# 'markdown' && map(ale#linter#Get('markdown'), 'v:val.name') ==# ['grammar']
        \      && get(b:, 'ale_lint_delay') == 1000 && maparg('z=', 'n') =~# 'GrammarFix'
        \      && maparg(']e', 'n') =~# 'ALENextWrap',
        \      'ft=' . &filetype . ' linters=' . string(map(ale#linter#Get(&filetype), 'v:val.name'))
        \      . ' z=' . maparg('z=', 'n')]},
        \ {-> 1})
  call s:Add('a misspelling is underlined after a pause',
        \ {-> feedkeys("iI want a grammer checker.\<Esc>", 't')},
        \ {-> [len(s:GrammarItems()) == 1 && s:GrammarItems()[0].col == 10
        \      && s:GrammarItems()[0].end_col == 16 && s:GrammarItems()[0].type ==# 'E',
        \      'loclist: ' . string(s:Loclist())]},
        \ {-> s:Idle() && !empty(s:GrammarItems())}, 15000)
  call s:Add('z= on the word applies the fix',
        \ {-> [cursor(1, 12), feedkeys('z=', 't')]},
        \ {-> s:Expect(['I want a grammar checker.'])})
  call s:Add('u restores the original',
        \ {-> feedkeys('u', 't')},
        \ {-> s:Expect(['I want a grammer checker.'])})
  call s:Add('z= away from an issue changes nothing',
        \ {-> [cursor(1, 1), feedkeys('z=', 't')]},
        \ {-> s:Expect(['I want a grammer checker.'])})
  call s:Add('words in a fenced code block are not checked',
        \ {-> [setline(1, ['Prose definately.', '', '```', 'grammer', '```']),
        \      feedkeys("G\<Esc>", 't')]},
        \ {-> [s:GrammarLines() ==# [1] && s:GrammarItems()[0].text =~# 'definately',
        \      'loclist: ' . string(s:Loclist())]},
        \ {-> s:Idle() && !empty(filter(s:GrammarItems(), 'v:val.text =~# "definately"'))}, 15000)

  let s:commit_dir = tempname()
  call mkdir(s:commit_dir, 'p')
  call s:Add('git commit comment lines are not checked',
        \ {-> [execute('edit! ' . fnameescape(s:commit_dir . '/COMMIT_EDITMSG')),
        \      setline(1, ['fix: a definately better subject', '', '# grammer in a comment']),
        \      feedkeys("\<Esc>", 't')]},
        \ {-> [&filetype ==# 'gitcommit' && s:GrammarLines() ==# [1],
        \      'ft=' . &filetype . ' loclist: ' . string(s:Loclist())]},
        \ {-> s:Idle() && !empty(s:GrammarItems())}, 15000)
  call s:Add('plain text uses the grammar linter',
        \ {-> execute('enew! | setfiletype text')},
        \ {-> [map(ale#linter#Get('text'), 'v:val.name') ==# ['grammar'] && maparg('z=', 'n') =~# 'GrammarFix',
        \      string(map(ale#linter#Get('text'), 'v:val.name'))]},
        \ {-> 1})
endif

" ---------- Re-sourcing ----------
function! s:AutocmdCount(group, pattern) abort
  let l:out = execute('autocmd ' . a:group)
  return len(filter(split(l:out, "\n"), 'v:val =~# a:pattern'))
endfunction
function! s:CountAutocmds() abort
  return [s:AutocmdCount('vimrc_ale', 's:'), s:AutocmdCount('amoled_black_shiny_markdown', 's:'),
        \ s:AutocmdCount('vimrc_grammar', 's:')]
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
