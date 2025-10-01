set noswapfile
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

