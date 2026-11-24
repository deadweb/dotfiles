set noswapfile
set paste
set clipboard=unnamedplus " Використовувати системний буфер за замовчуванням
syntax on           " увімкнути підсвічування синтаксису
set background=dark " якщо темна тема терміналу, або light для світлої
colorscheme desert  " обрана колірна схема

call plug#begin('~/.vim/plugged')

Plug 'joshdick/onedark.vim'

call plug#end()

syntax on
set background=dark
colorscheme onedark

if has("termguicolors")
	  set termguicolors
endif

hi Normal guibg=#2d2d2d guifg=#dcdcdc
hi Comment guifg=#a0a0a0
hi Keyword guifg=#c678dd
hi Function guifg=#61afef
hi String guifg=#98c379

" Перемикає режив вставки для вставки без форматування
let &t_SI .= "\<Esc>[?2004h"
let &t_EI .= "\<Esc>[?2004l"

inoremap <special> <expr> <Esc>[200~ XTermPasteBegin()

function! XTermPasteBegin()
  set pastetoggle=<Esc>[201~
  set paste
  return ""
endfunction

