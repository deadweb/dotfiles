"" Налаштування

runtime! debian.vim
syntax on

let g:mapleader="<"
let g:XkbSwitchEnabled = 1 " перемикає клавіатуру для української

" set number " вмикає нумерацію рядків
" set relativenumber
set clipboard=unnamedplus
set conceallevel=3 " функція згортання

" set keymap=ukrainian-jcukenwin
set langmap=йq,цw,уe,кr,еt,нy,гu,шi,щo,зp,х[,ї],фa,іs,вd,аf,пg,рh,оj,лk,дl,ж\\;,
  \є',ґ\\,яz,чx,сc,мv,иb,тn,ьm,б\\,,ю.,,ЙQ,ЦW,УE,КR,ЕT,НY,НY,ГU,ШI,ЩO,ЗP,Х{,Ї},ФA,
  \ІS,ВD,АF,ПG,РH,ОJ,ЛK,ДL,Ж\\:,Є\\",Ґ\|,ЯZ,ЧX,СC,МV,ИB,ТN,ЬM,Б\\<,Ю>,№#

set iminsert=0
set imsearch=0
set noswapfile
highlight lCursor guifg=NONE guibg=Cyan

set encoding=utf-8 " кодування UTF-8
set termencoding=utf-8                              " set terminal encoding
set fileencoding=utf-8                              " set save encoding
set fileencodings=utf8,koi8r,cp1251,cp866,ucs-2le   " список предполагаемых кодировок, в порядке предпочтения

set expandtab
set hlsearch
set ic " Ігнорувати написання великих чи малих букв при пошуку
set incsearch
set nocompatible
set nofoldenable
set shiftwidth=3
set smarttab
set spelllang=en_us
set spelllang=uk
set tabstop=3
set wrap linebreak nolist " перенос слів

set guifont=DroidSansMono\ Nerd\ Font:h16 " шрифт
set guioptions = "Відключаємо панелі прокрутки в GUI
" set showtabline = 0 "Відключаємо панель табів (віконця FTW)
"Сам по собі number показує праворуч номера рядків
"Relativenumber - нумерацію рядків щодо положення курсора
" set number relativenumber "А це гібридний варіант. Протестуйте все

au BufNewFile,BufFilePre,BufRead *.md set filetype=markdown
" au FileType vimwiki setlocal shiftwidth=6 noexpandtab

" Plugin
call plug#begin('~/.vim/plugged')

" Plug 'itchyny/lightline.vim'
Plug 'bling/vim-bufferline'
Plug 'ap/vim-css-color'
Plug 'airblade/vim-gitgutter'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'lyokha/vim-xkbswitch' " перемикає клавіатуру
Plug 'mattn/calendar-vim' " Календар
Plug 'michal-h21/vim-zettel'
Plug 'preservim/vim-markdown'
Plug 'ryanoasis/vim-devicons' " іконки
"Plug 'tools-life/taskwiki', { 'for': 'python' } " інтеграція taskwarrior
Plug 'vim-airline/vim-airline' " статус-бар
Plug 'vim-airline/vim-airline-themes' " теми статус-бару
Plug 'vimwiki/vimwiki' " vimwiki

call plug#end()

filetype on
filetype plugin on

" vimwiki
let g:vimwiki_filetymes = ['vimwiki']
" let g:vimwiki_filetypes = ['markdown'] " Нормально працює H1
" let g:vimwiki_global_ext = 0

" let g:vimwiki_list = [{'path': '~/Documents/wiki/',  'syntax': 'markdown', 'ext': '.md'}] "Використовувати в vimwiki формат Markdown за замовчуванням

let g:vimwiki_list = [{'path':'~/Documents/wiki','ext':'.md','syntax':'markdown'}]

     " let g:vimwiki_list = [{'path': '~/Documents/wiki',
"                      \ 'syntax': 'markdown', 'ext': '.md'}]

" let g:vimwiki_list = [{'path':'~/Documents/wiki/', 
"                        \ 'template_path': '~/Documents/vimwiki/templates/',
"                        \ 'template_default': 'def_template',
"                        \ 'template_ext': '.tpl'}]

let g:nv_search_paths = ['~/Documents/wiki/']
" let g:vimwiki_listsyms = '✗○◐●✓' " чекбокси
let g:vimwiki_list = [{'auto_diary_index': 1}] " автоматично генерує індекс щоденнику додаючі нові записи
let g:vimwiki_diary_months = {
         \ 1: 'Січень',
         \ 2: 'Лютий',
         \ 3: 'Березень',
         \ 4: 'Квітень',
         \ 5: 'Травень',
         \ 6: 'Червень',
         \ 7: 'Липень',
         \ 8: 'Серпень',
         \ 9: 'Вересень',
         \ 10: 'Жовтень',
         \ 11: 'Листопад',
         \ 12: 'Грудень',
         \ }
" let g:vimwiki_ext2syntax = {'md':'markdown', '.markdown':'markdown'}
" let g:vimwiki_markdown_link_ext = 1
" let g:taskwiki_markdown_syntax = 'markdown'
" let g:taskwiki_markdown_syntax = 'vimwiki'

" mappings
map <F5> :setlocal spell! spelllang=en_us<CR>
map <F6> :setlocal spell! spelllang=uk<CR>
map <C-t> :tabnew<CR>
map <C-q> :tabclose<CR>
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l
set t_Co=256

" fzf
map <C-f> :Files<CR>
map <S-f> :Rg<CR>


" Виділити текст 
map <C-a> <esc>ggVG<CR>
map <C-c> <esc>"*yG<CR>

" Прибрати результати пошуку
map <C-s> :noh<CR>

" Source a global configuration file if available
if filereadable("/etc/vim/vimrc.local")
  source /etc/vim/vimrc.local
endif

" Шаблон для записів щоденнику
au BufNewFile ~/Documents/wiki/diary/*.md
      \ call append(0,[
      \ "# " . split(expand('%:r'),'/')[-1], "",
      \ "## Зробити || +inbox",  "",
      \ "## Нотатки", "" ])

" open-browser.vim
let g:netrw_nogx = 1 " disable netrw's gx mapping.
nmap gx <Plug>(librewolf -P general --browser)
vmap gx <Plug>(Librewolf -P general --browser)

" lex tree
" let g:netrw_list_hide= '\(^\|\s\s\)\zs\.\S\+'
let g:netrw_liststyle= 3
let g:netrw_banner = 0 " прибирає банер
inoremap <C-b> <Esc>:Lex<cr>:vertical resize 30<cr>
nnoremap <C-b> <Esc>:Lex<cr>:vertical resize 30<cr>

" split line
highlight VertSplit cterm=NONE
:set fillchars+=vert:\|

" Calendar

let g:calendar_options = 'nornu'
" let g:calendar_navi_label = 'Назад,Сьогодні,Вперед'
let g:calendar_mruler = 'Cіч,Лют,Берез,Квіт,Трав,Черв,Лип,Серп,Верес,Жовт,Листоп,Груд'
let g:calendar_wruler = 'Нд Пн Вт Ср Чт Пт Сб'

map <C-c> <Esc>:Calendar<cr>

" Airline

let g:airline_powerline_fonts = 1 " вмикає підтримку Powerline шрифтів
let g:airline#extensions#xkblayout#enabled = 0
let g:airline_section_z = "\ue0a1:%l /%L Col:%c" "кастомна графа положення курсора
"let g:airline_section_z = airline#section#create(['windowswap', '%3p%% ', 'linenr', ':%3v'])
let g:Powerline_symbols = 'unicode' "Підтримка unicode
let g:airline_theme='dark'
let g:airline_left_sep=''
let g:airline_left_alt_sep = '|'
let g:airline_right_sep=''
"let g:airline_symbols.linenr = ''
"let g:airline_symbols.linenr = '☰'
let g:airline#extensions#bufferline#enabled = 1 " інтеграція powerline
let g:airline#extensions#fzf#enabled = 1 " інтеграція fzf
let g:airline#extensions#xkblayout#enabled = 1 " інтеграція xkblayout
let g:airline#extensions#whitespace#enabled = 0 " вимикає показ пробілів

" Tab navigation like Firefox

nnoremap <C-S-tab> :bprevious<CR>
nnoremap <C-tab>   :bnext<CR>

let g:python3_host_prog = '~/.pyenv/versions/neovim3/bin/python'
