" ~/.vimrc

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

" ---------- Reset inherited colors ----------
syntax enable
highlight clear
if exists('syntax_on')
  syntax reset
endif

" ---------- Editor interface ----------
" Pink is the normal foreground so unclassified variables match VS Code.
highlight Normal       guifg=#EC578D guibg=#0E0E0E gui=NONE ctermfg=204 ctermbg=233 cterm=NONE
highlight Cursor       guifg=#0E0E0E guibg=#FFFFFF gui=NONE ctermfg=233 ctermbg=15  cterm=NONE
highlight CursorLine   guifg=NONE    guibg=#343434 gui=NONE ctermfg=NONE ctermbg=236 cterm=NONE
highlight LineNr       guifg=#343434 guibg=#0E0E0E gui=NONE ctermfg=236 ctermbg=233 cterm=NONE
highlight CursorLineNr guifg=#F4B953 guibg=#343434 gui=bold ctermfg=215 ctermbg=236 cterm=bold
highlight SignColumn   guifg=#6160A0 guibg=#0E0E0E gui=NONE ctermfg=61  ctermbg=233 cterm=NONE
highlight ColorColumn  guifg=NONE    guibg=#242424 gui=NONE ctermfg=NONE ctermbg=235 cterm=NONE
highlight Visual       guifg=NONE    guibg=#464570 gui=NONE ctermfg=NONE ctermbg=60  cterm=NONE
highlight Search       guifg=#0E0E0E guibg=#F4B953 gui=NONE ctermfg=233 ctermbg=215 cterm=NONE
highlight IncSearch    guifg=#0E0E0E guibg=#EC578D gui=bold ctermfg=233 ctermbg=204 cterm=bold
highlight MatchParen   guifg=#FFFFFF guibg=#6160A0 gui=bold ctermfg=15  ctermbg=61  cterm=bold
highlight Pmenu        guifg=#BBBBBB guibg=#242424 gui=NONE ctermfg=250 ctermbg=235 cterm=NONE
highlight PmenuSel     guifg=#FFFFFF guibg=#464570 gui=bold ctermfg=15  ctermbg=60  cterm=bold
highlight StatusLine   guifg=#FFFFFF guibg=#343434 gui=bold ctermfg=15  ctermbg=236 cterm=bold
highlight StatusLineNC guifg=#6160A0 guibg=#242424 gui=NONE ctermfg=61  ctermbg=235 cterm=NONE
highlight VertSplit    guifg=#343434 guibg=#0E0E0E gui=NONE ctermfg=236 ctermbg=233 cterm=NONE
highlight WinSeparator guifg=#343434 guibg=#0E0E0E gui=NONE ctermfg=236 ctermbg=233 cterm=NONE
highlight NonText      guifg=#343434 guibg=#0E0E0E gui=NONE ctermfg=236 ctermbg=233 cterm=NONE
highlight EndOfBuffer  guifg=#0E0E0E guibg=#0E0E0E gui=NONE ctermfg=233 ctermbg=233 cterm=NONE

" Keep the diff colors from the original vimrc.
highlight DiffAdd    ctermbg=22  guibg=#005F00
highlight DiffDelete ctermbg=52  guibg=#5F0000
highlight DiffChange ctermbg=58  guibg=#5F5F00
highlight DiffText   ctermbg=100 guibg=#878700

" ---------- Syntax palette ----------
highlight VSComment  guifg=#464570 guibg=NONE gui=italic ctermfg=60  ctermbg=NONE cterm=italic
highlight VSGold     guifg=#F4B953 guibg=NONE gui=italic ctermfg=215 ctermbg=NONE cterm=italic
highlight VSPink     guifg=#EC578D guibg=NONE gui=NONE   ctermfg=204 ctermbg=NONE cterm=NONE
highlight VSBlue     guifg=#54A7F8 guibg=NONE gui=NONE   ctermfg=75  ctermbg=NONE cterm=NONE
highlight VSType     guifg=#54A7F8 guibg=NONE gui=italic ctermfg=75  ctermbg=NONE cterm=italic
highlight VSAqua     guifg=#6BE2D4 guibg=NONE gui=NONE   ctermfg=80  ctermbg=NONE cterm=NONE
highlight VSOrange   guifg=#EE7A46 guibg=NONE gui=italic ctermfg=209 ctermbg=NONE cterm=italic
highlight VSMagenta  guifg=#CC76D1 guibg=NONE gui=NONE   ctermfg=176 ctermbg=NONE cterm=NONE
highlight VSPurple   guifg=#9F62F7 guibg=NONE gui=NONE   ctermfg=135 ctermbg=NONE cterm=NONE
highlight VSOperator guifg=#6160A0 guibg=NONE gui=NONE   ctermfg=61  ctermbg=NONE cterm=NONE
highlight VSError    guifg=#FF5F5F guibg=#0E0E0E gui=bold ctermfg=203 ctermbg=233 cterm=bold

function! s:VscLink(target, groups) abort
  for l:group in split(a:groups)
    execute 'highlight! link ' . l:group . ' ' . a:target
  endfor
endfunction

" Standard groups shared by Vim syntax files.
call s:VscLink('VSComment',  'Comment')
call s:VscLink('VSGold',     'Statement Conditional Repeat Keyword Exception StorageClass Todo')
call s:VscLink('VSType',     'Type')
call s:VscLink('VSBlue',     'Function Underlined')
call s:VscLink('VSPink',     'Identifier')
call s:VscLink('VSPurple',   'Constant Number Boolean Float Structure Typedef Label')
call s:VscLink('VSAqua',     'String Character PreProc Include PreCondit SpecialComment Tag')
call s:VscLink('VSOrange',   'Special SpecialChar Define Macro Debug')
call s:VscLink('VSOperator', 'Operator')
call s:VscLink('VSMagenta',  'Delimiter')
call s:VscLink('VSError',    'Error ErrorMsg WarningMsg')

" Bash, C, C++, Python, Java, and assembly refinements.
call s:VscLink('VSGold', 'cStructure cTypedef cppStructure cppAccess pythonClass javaClassDecl javaScopeDecl javaConceptKind javaMethodDecl asmCond')
call s:VscLink('VSType', 'cType cppType javaType javaC_ asmType')
call s:VscLink('VSBlue', 'cFunction pythonBuiltin pythonFunction javaFuncDef javaLangObject shFunctionOne shFunctionTwo shFunctionThree shFunctionFour')
call s:VscLink('VSPurple', 'pythonExceptions javaI_ asmLabel')
call s:VscLink('VSPink', 'javaDocParam shShellVariables shSetList shDeref shDerefSimple asmIdentifier')
call s:VscLink('VSAqua', 'pythonDecorator pythonDecoratorName javaAnnotation javaDocParamTag javaDocReturnTag javaDocSeeTag javaDocThrowsTag asmDirective')

call s:VscLink('VSOrange', 'pythonClassVar javaTypedef')

" ---------- RV32 / RARS ----------
" Vim's generic asm syntax does not classify RISC-V opcodes or registers.
function! s:VscRiscvSyntax() abort
  syntax keyword VscRiscvInstruction
        \ lui auipc jal jalr beq bne blt bge bltu bgeu
        \ lb lh lw lbu lhu sb sh sw
        \ addi slti sltiu xori ori andi slli srli srai
        \ add sub sll slt sltu xor srl sra or and
        \ fence ecall ebreak
        \ mul mulh mulhsu mulhu div divu rem remu
        \ csrrw csrrs csrrc csrrwi csrrsi csrrci
        \ nop li mv not neg seqz snez sltz sgtz
        \ beqz bnez blez bgez bltz bgtz bgt ble bgtu bleu
        \ b j jr ret call tail la lla

  syntax match VscRiscvRegister
        \ /\<\%(x\%([0-9]\|[12][0-9]\|3[01]\)\|zero\|ra\|sp\|gp\|tp\|t[0-6]\|s\%([0-9]\|1[01]\)\|a[0-7]\|fp\)\>/

  syntax match VscRiscvInstruction /\<fence\.i\>/

  highlight! link VscRiscvInstruction VSGold
  highlight! link VscRiscvRegister VSBlue
endfunction

augroup vscode_sampled_riscv
  autocmd!
  autocmd FileType asm,riscv call <SID>VscRiscvSyntax()
augroup END
