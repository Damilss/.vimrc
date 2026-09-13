" AMOLED Black Shiny for Vim
" Source palette:
" ~/.vscode/extensions/rendinjast.amoled-black-0.1.0/
"   themes/amoled-dark-shiny-color-theme.json
"
" This is a complete, plugin-free vimrc.  Ordinary identifiers are left pink
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

" Alt-Backspace deletes the previous word in Insert mode.
inoremap <M-BS> <C-W>

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
highlight LineNr       guifg=#343434 guibg=#0E0E0E gui=NONE ctermfg=236 ctermbg=233 cterm=NONE
highlight CursorLineNr guifg=#757575 guibg=#343434 gui=bold ctermfg=243 ctermbg=236 cterm=bold
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
" The theme's comment is #6160A4AA.  #454572 is its opaque appearance over
" the editor's #0E0E0E background.
highlight VSComment     guifg=#454572 guibg=NONE gui=italic ctermfg=60  ctermbg=NONE cterm=italic
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
