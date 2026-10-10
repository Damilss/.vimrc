" AMOLED Black Shiny for Vim
" Source palette:
" ~/.vscode/extensions/rendinjast.amoled-black-0.1.0/
"   themes/amoled-dark-shiny-color-theme.json
"
" The theme and editing settings need no plugins.  The optional ALE and
" auto-pairs plugins (see the Plugins section and README.md) add language
" server diagnostics, completion, and bracket pairing; without them installed
" the rest of this file works unchanged.  Ordinary identifiers are left pink
" by default because Vim's regex syntax engine does not classify every local
" variable the way VS Code's semantic highlighter does.  Set the following to
" 0 before sourcing this file if you prefer the theme's #EEEEEE source fallback:
"   let g:amoled_black_shiny_pink_normal = 0

" ---------- Core editing ----------
filetype plugin indent on

set background=dark
set number
set cursorline

if exists('+termguicolors')
  set termguicolors
endif

" Alt-Backspace deletes the previous word in Insert mode for macOS
" Control-Backspace deletes previous word in Inser mode for linux (debian)
inoremap <M-BS> <C-W>
inoremap <C-H> <C-W>

" Ask Vim's built-in syntax files for richer highlighting.
let g:java_highlight_all = 1
let g:java_highlight_functions = 'style'
let g:java_highlight_generics = 1
let g:c_functions = 1
let g:c_function_pointers = 1
let g:python_constant_highlight = 1

" Syntax-highlight the fenced languages used in this setup.  Unknown or
" unlabelled fences retain the theme's purple Markdown code-block color.
if !exists('g:markdown_fenced_languages')
  let g:markdown_fenced_languages = [
        \ 'c', 'cpp', 'java', 'python', 'swift',
        \ 'bash=sh', 'shell=sh', 'zsh=sh',
        \ 'asm', 'assembly=asm', 'riscv=asm', 'arm=asm', 'aarch64=asm'
        \ ]
endif

" ---------- Plugins ----------
" vim-plug loads two plugins from ~/.vim/plugged:
"   ALE         diagnostics, completion, and navigation via language servers
"   auto-pairs  matching (), [], {}, quotes; skip/delete/Enter inside pairs
" Install them with scripts/install.sh.  If ~/.vim/autoload/plug.vim is
" missing, this section does nothing and ordinary editing is unaffected.
let s:repo_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h')

" ALE reads these when it loads, so they must be set before plug#end().
let g:ale_completion_enabled = 1
" Only the linters listed here run; other filetypes are left alone.
let g:ale_linters_explicit = 1
let g:ale_linters = extend(get(g:, 'ale_linters', {}), {
      \ 'c': ['clangd'],
      \ 'cpp': ['clangd'],
      \ 'sh': ['shellcheck'],
      \ 'python': ['ruff', 'pyright'],
      \ 'java': ['javac'],
      \ }, 'keep')
" Check while typing (after a short pause), on leaving Insert mode, and on
" save.  Nothing is fixed or reformatted automatically.
let g:ale_lint_on_text_changed = 'always'
let g:ale_lint_on_insert_leave = 1
let g:ale_lint_on_save = 1
let g:ale_fix_on_save = 0
let g:ale_sign_column_always = 1
let g:ale_echo_msg_format = '[%linter%] %severity%: %s'
let g:ale_virtualtext_cursor = 'current'
" :ALEHover and :ALEDetail open a popup instead of the message line.
let g:ale_floating_preview = 1

" clangd: an explicit g:ale_c_clangd_executable / g:ale_cpp_clangd_executable
" wins; then PATH (Xcode's /usr/bin/clangd on macOS, apt's clangd on Debian);
" then Homebrew LLVM, which is keg-only and so not on PATH.  Brew is asked at
" most once per Vim session.
function! s:FindClangd() abort
  if executable('clangd')
    return 'clangd'
  endif
  if has('mac') && executable('brew')
    let l:prefix = trim(system('brew --prefix llvm 2>/dev/null'))
    if v:shell_error == 0 && executable(l:prefix . '/bin/clangd')
      return l:prefix . '/bin/clangd'
    endif
  endif
  return ''
endfunction

if !exists('s:clangd')
  let s:clangd = s:FindClangd()
endif
if !empty(s:clangd)
  let g:ale_c_clangd_executable = get(g:, 'ale_c_clangd_executable', s:clangd)
  let g:ale_cpp_clangd_executable = get(g:, 'ale_cpp_clangd_executable', s:clangd)
endif

" ALE only starts clangd once it finds a project root (compile_commands.json,
" .git, Makefile, CMakeLists.txt, configure).  Without one it silently shows
" nothing, so fall back to the file's own directory.
function! s:ClangdRoot(buffer) abort
  let l:root = ale#c#FindProjectRoot(a:buffer)
  return empty(l:root) ? fnamemodify(bufname(a:buffer), ':p:h') : l:root
endfunction
let g:ale_root = extend(get(g:, 'ale_root', {}),
      \ {'clangd': function('s:ClangdRoot')}, 'keep')

" clangd reports only the first missing header in the #include block at the
" top of a file: clang treats a missing header as fatal and reports nothing
" more in that pass.  In projects that give clangd their settings
" (compile_commands.json, compile_flags.txt, or .clangd), ask it which
" includes it resolved after its results arrive and mark every other one, as
" VS Code does.  Elsewhere any include that needs an include path would look
" missing, so clangd's own report is left as it is.  Includes inside #if
" blocks are left alone: an inactive include looks the same as a missing one.
let s:showing_includes = 0

" {lnum: [col, end_col, name]} for each #include outside #if blocks.  An
" include guard (#ifndef X, then #define X) doesn't count as a block.
function! s:IncludeLines(buffer) abort
  let l:lines = getbufline(a:buffer, 1, '$')
  let l:blocks = []
  let l:includes = {}
  for l:lnum in range(1, len(l:lines))
    let l:line = l:lines[l:lnum - 1]
    if l:line !~# '^\s*#'
      continue
    elseif l:line =~# '^\s*#\s*if\(n\=def\)\=\>'
      let l:guard = matchstr(l:line, '^\s*#\s*ifndef\s\+\zs\w\+')
      call add(l:blocks, empty(l:blocks) && !empty(l:guard)
            \ && get(l:lines, l:lnum, '') =~# '^\s*#\s*define\s\+' . l:guard . '\>'
            \ ? 'guard' : 'if')
    elseif l:line =~# '^\s*#\s*endif\>'
      if !empty(l:blocks)
        call remove(l:blocks, -1)
      endif
    elseif index(l:blocks, 'if') < 0 && l:line =~# '^\s*#\s*include\s*[<"]'
      let l:col = match(l:line, '[<"]') + 1
      let l:name = matchstr(l:line, '[^>"]*', l:col)
      let l:includes[l:lnum] = [l:col, l:col + len(l:name) + 1, l:name]
    endif
  endfor
  return l:includes
endfunction

function! s:ShowIncludes(buffer, tick, response) abort
  if !bufexists(a:buffer) || getbufvar(a:buffer, 'changedtick') != a:tick
        \ || type(get(a:response, 'result')) != v:t_list
    return
  endif
  " Lines whose include clangd resolved, or already reported itself.
  let l:skip = {}
  for l:link in a:response.result
    let l:skip[l:link.range.start.line + 1] = 1
  endfor
  for l:item in ale#engine#GetLoclist(a:buffer)
    if l:item.linter_name is# 'clangd' && (get(l:item, 'code', '') is# 'pp_file_not_found'
          \ || l:item.text =~# 'file not found')
      let l:skip[l:item.lnum] = 1
    endif
  endfor
  let l:loclist = []
  for [l:lnum, l:include] in items(s:IncludeLines(a:buffer))
    if !has_key(l:skip, l:lnum)
      call add(l:loclist, {'lnum': str2nr(l:lnum), 'col': l:include[0],
            \ 'end_col': l:include[1], 'type': 'E',
            \ 'text': printf("'%s' file not found", l:include[2])})
    endif
  endfor
  " Showing results fires ALELintPost again; don't ask clangd a second time.
  let s:showing_includes = 1
  try
    call ale#other_source#ShowResults(a:buffer, 'includes', l:loclist)
  finally
    let s:showing_includes = 0
  endtry
endfunction

function! s:HasClangdConfig(buffer) abort
  return !empty(ale#c#FindCompileCommands(a:buffer)[1])
        \ || !empty(ale#path#FindNearestFile(a:buffer, 'compile_flags.txt'))
        \ || !empty(ale#path#FindNearestFile(a:buffer, '.clangd'))
endfunction

function! s:CheckIncludes(buffer) abort
  if s:showing_includes || getbufvar(a:buffer, '&filetype') !~# '^c\(pp\)\=$'
        \ || !s:HasClangdConfig(a:buffer)
    return
  endif
  try
    call ale#lsp_linter#SendRequest(a:buffer, 'clangd',
          \ [0, 'textDocument/documentLink',
          \  {'textDocument': {'uri': ale#util#ToURI(expand('#' . a:buffer . ':p'))}}],
          \ function('s:ShowIncludes', [a:buffer, getbufvar(a:buffer, 'changedtick')]))
  catch
    " clangd isn't a linter for this buffer.
  endtry
endfunction

augroup vimrc_clangd_includes
  autocmd!
  autocmd User ALELintPost call s:CheckIncludes(bufnr(''))
augroup END

" auto-pairs: keep pair insertion, skipping, Backspace, and Enter, but not
" the extra keys it would take over in terminal Vim:
"   <C-h> is the Ctrl-Backspace mapping above.
"   Meta keys arrive as 8-bit characters (<M-e> is 'å', <M-)> is '©'), so its
"   Meta shortcuts would swallow those characters while typing.
let g:AutoPairsMapCh = 0
let g:AutoPairsShortcutToggle = ''
let g:AutoPairsShortcutFastWrap = ''
let g:AutoPairsShortcutJump = ''
let g:AutoPairsShortcutBackInsert = ''
let g:AutoPairsMoveCharacter = ''
" Typing a closer skips only an existing closer on the same line.
let g:AutoPairsMultilineClose = 0

if !empty(globpath(&runtimepath, 'autoload/plug.vim'))
  call plug#begin('~/.vim/plugged')
  Plug 'dense-analysis/ale', { 'tag': 'v4.0.0' }
  Plug 'jiangmiao/auto-pairs', { 'commit': '39f06b873a8449af8ff6a3eee716d3da14d63a76' }
  call plug#end()
endif

" ---------- Reset inherited colors ----------
syntax enable
highlight clear
if exists('syntax_on')
  syntax reset
endif

" ---------- Editor interface ----------
if get(g:, 'amoled_black_shiny_pink_normal', 1)
  highlight Normal guifg=#FF478D guibg=#0E0E0E gui=NONE ctermfg=204 ctermbg=233 cterm=NONE
else
  highlight Normal guifg=#EEEEEE guibg=#0E0E0E gui=NONE ctermfg=255 ctermbg=233 cterm=NONE
endif

highlight Cursor       guifg=#0E0E0E guibg=#FFFFFF gui=NONE ctermfg=233 ctermbg=15  cterm=NONE
highlight CursorLine   guifg=NONE    guibg=#343434 gui=NONE ctermfg=NONE ctermbg=236 cterm=NONE
highlight CursorColumn guifg=NONE    guibg=#242424 gui=NONE ctermfg=NONE ctermbg=235 cterm=NONE
" The theme's line numbers (#343434, 1.5:1 on #0E0E0E) vanish on dimmer
" screens such as a Raspberry Pi monitor.  Same gray, lifted to ~7:1; the
" current line's number uses the theme's #EEEEEE source color (~11:1).
highlight LineNr       guifg=#9E9E9E guibg=#0E0E0E gui=NONE ctermfg=247 ctermbg=233 cterm=NONE
highlight CursorLineNr guifg=#EEEEEE guibg=#343434 gui=bold ctermfg=255 ctermbg=236 cterm=bold
highlight SignColumn   guifg=#6160A4 guibg=#0E0E0E gui=NONE ctermfg=61  ctermbg=233 cterm=NONE
highlight FoldColumn   guifg=#6160A4 guibg=#0E0E0E gui=NONE ctermfg=61  ctermbg=233 cterm=NONE
highlight Folded       guifg=#999999 guibg=#0E0E0E gui=italic ctermfg=246 ctermbg=233 cterm=italic
highlight ColorColumn  guifg=NONE    guibg=#242424 gui=NONE ctermfg=NONE ctermbg=235 cterm=NONE
" #3793E033 composited over #0E0E0E, since Vim does not accept alpha here.
highlight Visual       guifg=NONE    guibg=#162938 gui=NONE ctermfg=NONE ctermbg=235 cterm=NONE
highlight VisualNOS    guifg=NONE    guibg=#242424 gui=NONE ctermfg=NONE ctermbg=235 cterm=NONE
highlight Search       guifg=#0E0E0E guibg=#FFB638 gui=NONE ctermfg=233 ctermbg=215 cterm=NONE
highlight IncSearch    guifg=#0E0E0E guibg=#FF478D gui=bold ctermfg=233 ctermbg=204 cterm=bold
highlight MatchParen   guifg=#FFFFFF guibg=#343434 gui=bold ctermfg=15  ctermbg=236 cterm=bold
highlight Pmenu        guifg=#999999 guibg=#0E0E0E gui=NONE ctermfg=246 ctermbg=233 cterm=NONE
highlight PmenuSel     guifg=#FFFFFF guibg=#343434 gui=bold ctermfg=15  ctermbg=236 cterm=bold
highlight PmenuSbar    guifg=NONE    guibg=#242424 gui=NONE ctermfg=NONE ctermbg=235 cterm=NONE
highlight PmenuThumb   guifg=NONE    guibg=#757575 gui=NONE ctermfg=NONE ctermbg=243 cterm=NONE
highlight StatusLine   guifg=#FFFFFF guibg=#343434 gui=bold ctermfg=15  ctermbg=236 cterm=bold
highlight StatusLineNC guifg=#757575 guibg=#242424 gui=NONE ctermfg=243 ctermbg=235 cterm=NONE
highlight TabLine      guifg=#757575 guibg=#0E0E0E gui=NONE ctermfg=243 ctermbg=233 cterm=NONE
highlight TabLineSel   guifg=#FFFFFF guibg=#0E0E0E gui=bold ctermfg=15  ctermbg=233 cterm=bold
highlight TabLineFill  guifg=#343434 guibg=#0E0E0E gui=NONE ctermfg=236 ctermbg=233 cterm=NONE
highlight VertSplit    guifg=#343434 guibg=#0E0E0E gui=NONE ctermfg=236 ctermbg=233 cterm=NONE
highlight WinSeparator guifg=#343434 guibg=#0E0E0E gui=NONE ctermfg=236 ctermbg=233 cterm=NONE
highlight NonText      guifg=#343434 guibg=#0E0E0E gui=NONE ctermfg=236 ctermbg=233 cterm=NONE
highlight Whitespace   guifg=#242424 guibg=NONE    gui=NONE ctermfg=235 ctermbg=NONE cterm=NONE
highlight EndOfBuffer  guifg=#0E0E0E guibg=#0E0E0E gui=NONE ctermfg=233 ctermbg=233 cterm=NONE
highlight Directory    guifg=#6CC7F6 guibg=NONE    gui=NONE ctermfg=81  ctermbg=NONE cterm=NONE
highlight WildMenu     guifg=#FFFFFF guibg=#343434 gui=bold ctermfg=15  ctermbg=236 cterm=bold

highlight DiffAdd    guifg=#5BC266 guibg=#0E0E0E gui=NONE ctermfg=71  ctermbg=233 cterm=NONE
highlight DiffDelete guifg=#E1270E guibg=#0E0E0E gui=NONE ctermfg=160 ctermbg=233 cterm=NONE
highlight DiffChange guifg=#FBCC43 guibg=#0E0E0E gui=NONE ctermfg=221 ctermbg=233 cterm=NONE
highlight DiffText   guifg=#FFFFFF guibg=#343434 gui=bold ctermfg=15  ctermbg=236 cterm=bold

" ---------- Exact syntax palette ----------
" The theme's comment is #6160A4AA (opaque #454572 over #0E0E0E), which is
" too dim to read.  Same indigo hue, lifted to ~5:1 contrast on #0E0E0E.
highlight VSComment     guifg=#7F7EC0 guibg=NONE gui=italic ctermfg=103 ctermbg=NONE cterm=italic
highlight VSKeyword     guifg=#FFB638 guibg=NONE gui=NONE   ctermfg=215 ctermbg=NONE cterm=NONE
highlight VSVariable    guifg=#FF478D guibg=NONE gui=NONE   ctermfg=204 ctermbg=NONE cterm=NONE
highlight VSFunction    guifg=#28A9FF guibg=NONE gui=NONE   ctermfg=39  ctermbg=NONE cterm=NONE
highlight VSStorage     guifg=#14E5D4 guibg=NONE gui=italic ctermfg=44  ctermbg=NONE cterm=italic
highlight VSString      guifg=#42DD76 guibg=NONE gui=NONE   ctermfg=78  ctermbg=NONE cterm=NONE
highlight VSType        guifg=#A95EFF guibg=NONE gui=NONE   ctermfg=135 ctermbg=NONE cterm=NONE
highlight VSNumber      guifg=#FF7135 guibg=NONE gui=NONE   ctermfg=203 ctermbg=NONE cterm=NONE
highlight VSSelf        guifg=#FF7135 guibg=NONE gui=italic ctermfg=203 ctermbg=NONE cterm=italic
highlight VSDecorator   guifg=#E66DFF guibg=NONE gui=NONE   ctermfg=171 ctermbg=NONE cterm=NONE
highlight VSConstant    guifg=#D62C2C guibg=NONE gui=NONE   ctermfg=160 ctermbg=NONE cterm=NONE
highlight VSPunctuation guifg=#6160A4 guibg=NONE gui=NONE   ctermfg=61  ctermbg=NONE cterm=NONE
highlight VSSource      guifg=#EEEEEE guibg=NONE gui=NONE   ctermfg=255 ctermbg=NONE cterm=NONE
highlight VSTodo        guifg=#FFB638 guibg=NONE gui=bold   ctermfg=215 ctermbg=NONE cterm=bold
highlight VSError       guifg=#E1270E guibg=#0E0E0E gui=bold ctermfg=160 ctermbg=233 cterm=bold
highlight VSWarning     guifg=#FF453A guibg=#0E0E0E gui=bold ctermfg=203 ctermbg=233 cterm=bold

" Markdown has a `text.html.markdown` root scope, so ordinary prose uses the
" editor foreground rather than the pink variable foreground used for code.
highlight VSMarkdownText       guifg=#999999 guibg=#0E0E0E gui=NONE        ctermfg=246 ctermbg=233  cterm=NONE
highlight VSMarkdownHeading    guifg=#FFB638 guibg=NONE    gui=NONE        ctermfg=215 ctermbg=NONE cterm=NONE
highlight VSMarkdownLink       guifg=#28A9FF guibg=NONE    gui=NONE        ctermfg=39  ctermbg=NONE cterm=NONE
highlight VSMarkdownBold       guifg=#28A9FF guibg=NONE    gui=bold        ctermfg=39  ctermbg=NONE cterm=bold
highlight VSMarkdownItalic     guifg=#28A9FF guibg=NONE    gui=italic      ctermfg=39  ctermbg=NONE cterm=italic
highlight VSMarkdownBoldItalic guifg=#28A9FF guibg=NONE    gui=bold,italic ctermfg=39  ctermbg=NONE cterm=bold,italic
highlight VSMarkdownQuote      guifg=#28A9FF guibg=NONE    gui=italic      ctermfg=39  ctermbg=NONE cterm=italic
highlight VSMarkdownCode       guifg=#A95EFF guibg=NONE    gui=NONE        ctermfg=135 ctermbg=NONE cterm=NONE
highlight VSMarkdownStrike     guifg=#999999 guibg=NONE    gui=strikethrough ctermfg=246 ctermbg=NONE cterm=strikethrough
highlight VSMarkdownHtmlAttr   guifg=#FFB638 guibg=NONE    gui=italic      ctermfg=215 ctermbg=NONE cterm=italic

function! s:VSLink(target, groups) abort
  for l:group in split(a:groups)
    execute 'highlight! link ' . l:group . ' ' . a:target
  endfor
endfunction

" Standard groups shared by Vim's syntax files.
call s:VSLink('VSComment',     'Comment SpecialComment')
call s:VSLink('VSKeyword',     'Statement Conditional Repeat Keyword Exception StorageClass')
call s:VSLink('VSType',        'Type Structure Typedef Title')
call s:VSLink('VSFunction',    'Function Label Underlined')
call s:VSLink('VSVariable',    'Identifier')
call s:VSLink('VSString',      'String Character')
call s:VSLink('VSConstant',    'Constant Boolean')
call s:VSLink('VSNumber',      'Number Float')
call s:VSLink('VSStorage',     'PreProc Include PreCondit Define Macro Tag')
call s:VSLink('VSPunctuation', 'Operator Delimiter')
call s:VSLink('VSTodo',        'Todo')
call s:VSLink('VSError',       'Error ErrorMsg')
call s:VSLink('VSWarning',     'WarningMsg')

" C and C++.
call s:VSLink('VSType',        'cType cStructure cTypedef cppType cppStructure')
call s:VSLink('VSKeyword',     'cStatement cConditional cRepeat cStorageClass cppStatement cppAccess cppModifier cppExceptions cppStorageClass cppModule')
call s:VSLink('VSFunction',    'cFunction cFunctionPointer cLabel cUserLabel')
call s:VSLink('VSPunctuation', 'cOperator cppOperator cppCast cppRawStringDelimiter')

" Python.
call s:VSLink('VSKeyword',   'pythonStatement pythonConditional pythonRepeat pythonOperator pythonException pythonInclude pythonAsync')
call s:VSLink('VSType',      'pythonClass pythonType pythonExceptions')
call s:VSLink('VSFunction',  'pythonFunction pythonBuiltin')
call s:VSLink('VSDecorator', 'pythonDecorator pythonDecoratorName')
call s:VSLink('VSSelf',      'pythonClassVar')
call s:VSLink('VSVariable',  'pythonAttribute')

" Java.
call s:VSLink('VSKeyword',   'javaBranch javaConditional javaRepeat javaExceptions javaAssert javaStorageClass javaMethodDecl javaClassDecl javaScopeDecl javaConceptKind javaStatement')
call s:VSLink('VSType',      'javaType javaTypedef javaC_ javaI_ javaR_ javaE_ javaX_ javaLangObject')
call s:VSLink('VSFunction',  'javaFuncDef javaMethodRef javaLambdaDef javaGenericsC1')
call s:VSLink('VSDecorator', 'javaAnnotation javaAnnotationStart')
call s:VSLink('VSVariable',  'javaDocParam')
call s:VSLink('VSStorage',   'javaExternal javaDocParamTag javaDocReturnTag javaDocSeeTag javaDocThrowsTag')
call s:VSLink('VSPunctuation', 'javaOperator')
call s:VSLink('VSConstant',  'javaConstant javaBoolean')
call s:VSLink('VSNumber',    'javaNumber')

" Swift (groups from Vim's bundled swift.vim).
call s:VSLink('VSKeyword', 'swiftImport swiftKeyword swiftMultiwordKeyword swiftDefinitionModifier swiftInOutKeyword swiftFuncKeyword swiftFuncKeywordGeneral swiftFuncDefinition swiftTypeDefinition swiftMultiwordTypeDefinition swiftTypeAliasDefinition swiftVarDefinition swiftMutating swiftConstraint')
call s:VSLink('VSType', 'swiftCoreTypes swiftType swiftTypePair swiftTypeAliasName')
call s:VSLink('VSFunction', 'swiftTypeName swiftImportModule swiftImportComponent')
call s:VSLink('VSVariable', 'swiftVarName swiftImplicitVarName')
call s:VSLink('VSSelf', 'swiftIdentifierKeyword')
call s:VSLink('VSDecorator', 'swiftAttribute')
call s:VSLink('VSPunctuation', 'swiftOperator swiftLabel swiftCastOp swiftNilOps swiftTypeAliasValue swiftTypeDeclaration swiftTypeParameters swiftParamDelim')
call s:VSLink('VSConstant', 'swiftBoolean swiftNil')
call s:VSLink('VSNumber', 'swiftDecimal swiftHex swiftOct swiftBin swiftTupleIndexNumber')
call s:VSLink('VSStorage', 'swiftPreproc swiftScope')

" Bash / POSIX shell.
call s:VSLink('VSKeyword', 'shStatement shConditional shRepeat shLoop shSet bashStatement bashAdminStatement')
call s:VSLink('VSFunction', 'shFunction shFunctionKey shFunctionName shTouchCmd')
call s:VSLink('VSVariable', 'shVariable shSetList shShellVariables shDeref shDerefSimple shDerefVar shPosnParm bashSpecialVariables')
call s:VSLink('VSNumber', 'shNumber')
call s:VSLink('VSPunctuation', 'shOperator shDerefOp shDerefDelim shRedir shSetListDelim shSubShRegion shExprRegion shBracketExprDelim')

" YAML (.yml and .yaml).  Vim leaves plain and block scalars unlinked by
" default; VS Code scopes both as strings, so color them green here too.
call s:VSLink('VSComment', 'yamlComment yamlTodo')
call s:VSLink('VSKeyword', 'yamlMappingKey yamlFlowMappingKey yamlBlockMappingKey yamlBlockScalarHeader yamlAnchor yamlAlias')
call s:VSLink('VSStorage', 'yamlDirectiveName yamlTAGDirective yamlYAMLDirective')
call s:VSLink('VSString', 'yamlString yamlFlowString yamlFlowStringDelimiter yamlPlainScalar yamlBlockString')
call s:VSLink('VSConstant', 'yamlConstant yamlNull yamlBool yamlEscape yamlSingleEscape')
call s:VSLink('VSNumber', 'yamlInteger yamlFloat yamlTimestamp yamlYAMLVersion VscYamlBlockScalarIndent')
call s:VSLink('VSType', 'yamlNodeTag yamlTagHandle yamlTagPrefix VscYamlAnchorName')
call s:VSLink('VSVariable', 'VscYamlAliasName')
call s:VSLink('VSPunctuation', 'yamlDirective yamlMappingKeyStart yamlMappingMerge yamlKeyValueDelimiter yamlFlowIndicator yamlFlowMappingKeyStart yamlFlowMappingMerge yamlFlowMappingDelimiter yamlBlockMappingKeyStart yamlBlockMappingMerge yamlBlockMappingDelimiter yamlBlockCollectionItemStart VscYamlAnchorDelimiter VscYamlAliasDelimiter')
call s:VSLink('VSSource', 'yamlDocumentStart yamlDocumentEnd yamlReservedDirective')

function! s:VscYamlSyntax() abort
  " Match VS Code's nested scopes for &anchors and *aliases: purple sigils,
  " purple anchor names, and pink alias names.
  syntax match VscYamlAnchorDelimiter /&/ contained containedin=yamlAnchor
  syntax match VscYamlAnchorName /\%(&\)\@<=[^[:space:]\[\]{},]\+/ contained containedin=yamlAnchor
  syntax match VscYamlAliasDelimiter /\*/ contained containedin=yamlAlias
  syntax match VscYamlAliasName /\%(\*\)\@<=[^[:space:]\[\]{},]\+/ contained containedin=yamlAlias

  " VS Code treats a block scalar's indentation digit as numeric while the
  " |/> marker and +/- chomping indicator remain keyword-colored.
  syntax match VscYamlBlockScalarIndent /[1-9]/ contained containedin=yamlBlockScalarHeader
endfunction

augroup amoled_black_shiny_yaml
  autocmd!
  autocmd BufRead,BufNewFile *.yml,*.yaml setfiletype yaml
  autocmd FileType yaml call <SID>VscYamlSyntax()
augroup END

" Markdown.  These correspond directly to the theme's markup.* scopes.
call s:VSLink('VSMarkdownHeading', 'markdownH1 markdownH2 markdownH3 markdownH4 markdownH5 markdownH6 markdownHeadingRule markdownHeadingDelimiter markdownH1Delimiter markdownH2Delimiter markdownH3Delimiter markdownH4Delimiter markdownH5Delimiter markdownH6Delimiter')
call s:VSLink('VSMarkdownLink', 'markdownUrl markdownAutomaticLink htmlLink')
call s:VSLink('VSString', 'markdownLinkText markdownUrlTitle')
call s:VSLink('VSConstant', 'markdownFootnote markdownFootnoteDefinition markdownIdDeclaration markdownId')
call s:VSLink('VSPunctuation', 'markdownLinkDelimiter markdownLinkTextDelimiter markdownIdDelimiter markdownUrlDelimiter markdownUrlTitleDelimiter markdownRule')
call s:VSLink('VSMarkdownLink', 'markdownListMarker markdownOrderedListMarker')
call s:VSLink('VSMarkdownLink', 'VscMarkdownUnorderedText')
call s:VSLink('VSMarkdownQuote', 'markdownBlockquote VscMarkdownQuoteText')
call s:VSLink('VSMarkdownBold', 'markdownBold markdownBoldDelimiter')
call s:VSLink('VSMarkdownItalic', 'markdownItalic markdownItalicDelimiter')
call s:VSLink('VSMarkdownBoldItalic', 'markdownBoldItalic markdownBoldItalicDelimiter')
call s:VSLink('VSMarkdownStrike', 'markdownStrike markdownStrikeDelimiter')
call s:VSLink('VSMarkdownCode', 'markdownCode markdownCodeBlock markdownCodeDelimiter')
call s:VSLink('VSConstant', 'markdownEscape')
call s:VSLink('VSError', 'markdownError')

" Embedded HTML in Markdown follows the same VS Code token rules.
call s:VSLink('VSFunction', 'htmlTag htmlEndTag htmlTagName htmlSpecialTagName htmlMathTagName htmlSvgTagName')
call s:VSLink('VSMarkdownHtmlAttr', 'htmlArg')
call s:VSLink('VSString', 'htmlString htmlValue')
call s:VSLink('VSComment', 'htmlComment htmlCommentNested')

" Fences with these language names use their normal code palette.  Bare and
" unknown fences remain VSMarkdownCode, matching the theme's raw-block rule.
call s:VSLink('VSVariable', 'markdownHighlight_c markdownHighlight_cpp markdownHighlight_java markdownHighlight_python markdownHighlight_swift markdownHighlight_sh markdownHighlight_asm')

function! s:VscMarkdownSyntax() abort
  " VS Code scopes the paragraph inside an unordered list as blue and the
  " contents of a blockquote as blue italic; Vim normally marks only their
  " punctuation.  Fill those two gaps while retaining inline formatting.
  syntax region VscMarkdownUnorderedText
        \ matchgroup=markdownListMarker
        \ start="^\s*[-*+]\s\+" end="$"
        \ oneline keepend contains=@markdownInline contained
  syntax region VscMarkdownQuoteText
        \ matchgroup=markdownBlockquote
        \ start="^\s*\%(>\s*\)\+" end="$"
        \ oneline keepend contains=@markdownInline contained
  syntax cluster markdownBlock add=VscMarkdownUnorderedText,VscMarkdownQuoteText
endfunction

" Vim has no buffer-local Normal highlight, but 'wincolor' provides the exact
" behavior needed here: gray prose in Markdown and pink identifiers in code.
function! s:VscMarkdownWindowColor() abort
  if !exists('+wincolor')
    return
  endif

  if &l:filetype ==# 'markdown'
    if !exists('w:vsc_saved_wincolor')
      let w:vsc_saved_wincolor = &l:wincolor
    endif
    let &l:wincolor = 'VSMarkdownText'
  elseif exists('w:vsc_saved_wincolor')
    let &l:wincolor = w:vsc_saved_wincolor
    unlet w:vsc_saved_wincolor
  endif
endfunction

augroup amoled_black_shiny_markdown
  autocmd!
  autocmd FileType markdown call <SID>VscMarkdownSyntax()
  autocmd FileType,BufEnter,BufWinEnter * call <SID>VscMarkdownWindowColor()
augroup END

" ---------- RISC-V / ARM / AArch64 assembly ----------
" Vim identifies all .s/.S files as `asm`.  The first token in an assembly
" statement is therefore treated as an instruction for all three ISAs.  This
" also covers extension opcodes without maintaining a brittle mnemonic list.
call s:VSLink('VSKeyword',     'VscAsmInstruction')
call s:VSLink('VSVariable',    'VscAsmRegister')
call s:VSLink('VSFunction',    'VscAsmLabel asmLabel asmIdentifier')
call s:VSLink('VSStorage',     'asmDirective asmType asmInclude asmMacro')
call s:VSLink('VSKeyword',     'asmCond')
call s:VSLink('VSPunctuation', 'VscAsmOperator')

function! s:VscAssemblySyntax() abort
  syntax case ignore

  " Mnemonic at the start of a statement, optionally after a colon label.
  syntax match VscAsmInstruction
        \ /^\s*\%(\%([[:alpha:]_.$][[:alnum:]_.$]*\|\d\+\):\s*\)\?\zs[[:alpha:]_][[:alnum:]_.]*\ze\%(\s\|$\)/
  syntax match VscAsmInstruction
        \ /;\s*\zs[[:alpha:]_][[:alnum:]_.]*\ze\%(\s\|$\)/

  " Named, local (.Lfoo), and numeric (1:) labels.
  syntax match VscAsmLabel
        \ /^\s*\zs\%([[:alpha:]_.$][[:alnum:]_.$]*\|\d\+\)\ze:/

  " RISC-V integer/floating/vector registers and ABI aliases, plus ARM and
  " AArch64 general, SIMD, SVE, predicate, and common system registers.
  syntax match VscAsmRegister
        \ /\<\%(x\%([0-9]\|[12][0-9]\|3[01]\)\|w\%([0-9]\|[12][0-9]\|3[01]\)\|r\%([0-9]\|1[0-5]\)\|f\%([0-9]\|[12][0-9]\|3[01]\)\|v\%([0-9]\|[12][0-9]\|3[01]\)\|z\%([0-9]\|[12][0-9]\|3[01]\)\|q\%([0-9]\|[12][0-9]\|3[01]\)\|d\%([0-9]\|[12][0-9]\|3[01]\)\|p\%([0-9]\|1[0-5]\)\)\%([.][0-9]\+[bhsdq]\)\?\>/
  syntax match VscAsmRegister
        \ /\<\%(zero\|ra\|sp\|wsp\|gp\|tp\|fp\|lr\|pc\|xzr\|wzr\|t[0-6]\|s\%([0-9]\|1[01]\)\|a[0-7]\|ft\%([0-9]\|1[01]\)\|fs\%([0-9]\|1[01]\)\|fa[0-7]\|cpsr\|spsr\|apsr\|fpscr\|fpcr\|fpsr\|nzcv\|ffr\)\>/

  syntax match VscAsmOperator /[,(){}:+*\/%<>=!&|~^-]/
  syntax match VscAsmOperator /[\[\]]/
  syntax match VscAsmOperator /#/

  " Replace generic asm.vim's [#;!|] comment rule: it mistakes ARM #1
  " immediates and ! writeback for comments.
  syntax clear asmComment
  syntax region asmComment start="/\*" end="\*/" contains=asmTodo,@Spell
  syntax match asmComment "//.*$" contains=asmTodo,@Spell
  syntax match asmComment "@.*$" contains=asmTodo,@Spell
  syntax match asmComment "^\s*#.*$" contains=asmTodo,@Spell
  syntax match asmComment "\s\zs#\s.*$" contains=asmTodo,@Spell

  syntax case match
endfunction

augroup amoled_black_shiny_assembly
  autocmd!
  autocmd BufRead,BufNewFile *.riscv,*.rv setfiletype asm
  autocmd FileType asm call <SID>VscAssemblySyntax()
augroup END

" Modern diagnostic groups used by Vim plugins and Vim 9's LSP clients.
highlight DiagnosticError guifg=#E1270E guibg=NONE gui=NONE ctermfg=160 ctermbg=NONE cterm=NONE
highlight DiagnosticWarn  guifg=#FF453A guibg=NONE gui=NONE ctermfg=203 ctermbg=NONE cterm=NONE
highlight DiagnosticInfo  guifg=#6CC7F6 guibg=NONE gui=NONE ctermfg=81  ctermbg=NONE cterm=NONE
highlight DiagnosticHint  guifg=#5BC266 guibg=NONE gui=NONE ctermfg=71  ctermbg=NONE cterm=NONE
highlight DiagnosticUnderlineError guifg=NONE guibg=NONE gui=undercurl guisp=#E1270E cterm=underline
highlight DiagnosticUnderlineWarn  guifg=NONE guibg=NONE gui=undercurl guisp=#FF453A cterm=underline
highlight DiagnosticUnderlineInfo  guifg=NONE guibg=NONE gui=undercurl guisp=#6CC7F6 cterm=underline

" ALE only sets its own defaults for groups that do not exist yet, so these
" links win, and re-sourcing this file restores them after `highlight clear`.
call s:VSLink('DiagnosticUnderlineError', 'ALEError ALEStyleError')
call s:VSLink('DiagnosticUnderlineWarn',  'ALEWarning ALEStyleWarning')
call s:VSLink('DiagnosticUnderlineInfo',  'ALEInfo')
call s:VSLink('DiagnosticError', 'ALEErrorSign ALEStyleErrorSign ALEVirtualTextError ALEVirtualTextStyleError')
call s:VSLink('DiagnosticWarn',  'ALEWarningSign ALEStyleWarningSign ALEVirtualTextWarning ALEVirtualTextStyleWarning')
call s:VSLink('DiagnosticInfo',  'ALEInfoSign ALEVirtualTextInfo')

" ---------- Completion and language-server mappings ----------
" Tab / Shift-Tab move through an open completion menu and otherwise insert
" their usual characters.  Ctrl-Y accepts the selected item; Enter is left to
" newline and auto-pairs' brace expansion.
inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" Buffer-local, so gd, gr, and K keep Vim's meaning everywhere else.
function! s:AleLspMaps() abort
  if exists(':ALEHover') != 2
    return
  endif
  if &filetype ==# 'python' && !executable('pyright-langserver')
    return
  endif
  nnoremap <buffer> <silent> gd :ALEGoToDefinition<CR>
  nnoremap <buffer> <silent> gr :ALEFindReferences<CR>
  nnoremap <buffer> <silent> K  :ALEHover<CR>
  " Completion menu is shown but nothing is inserted or selected until
  " Tab / Ctrl-N, so typing and Enter are never hijacked.
  setlocal completeopt=menuone,noinsert,noselect
  if has('popupwin')
    setlocal completeopt+=popup
  endif
endfunction

function! s:AleDiagnosticMaps() abort
  if exists(':ALENextWrap') != 2
    return
  endif
  nnoremap <buffer> <silent> ]e :ALENextWrap<CR>
  nnoremap <buffer> <silent> [e :ALEPreviousWrap<CR>
endfunction

" Once per session, say why a C/C++ buffer has no diagnostics.
function! s:CHint() abort
  if exists('s:c_hint_shown')
    return
  endif
  let l:missing = []
  if exists(':ALEInfo') != 2
    call add(l:missing, 'ALE plugin')
  endif
  if !executable(get(g:, 'ale_c_clangd_executable', 'clangd'))
    call add(l:missing, 'clangd')
  endif
  if empty(l:missing)
    return
  endif
  let s:c_hint_shown = 1
  echohl WarningMsg
  echomsg 'vimrc: no C/C++ diagnostics (missing ' . join(l:missing, ', ')
        \ . '). Run: ' . fnameescape(s:repo_dir . '/scripts/doctor.sh')
  echohl None
endfunction

augroup vimrc_ale
  autocmd!
  autocmd FileType c,cpp,python call s:AleLspMaps()
  autocmd FileType c,cpp,sh,python,java call s:AleDiagnosticMaps()
  autocmd FileType c,cpp call s:CHint()
  " ALE has no per-buffer lint-on-change switch; javac is slow, so wait for
  " a longer pause before checking Java.
  autocmd FileType java let b:ale_lint_delay = 1500
augroup END
