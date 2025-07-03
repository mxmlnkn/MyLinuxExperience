" An example for a vimrc file.
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last change:	2014 Feb 05
"
" To use it, copy it to
"     for Unix and OS/2:  ~/.vimrc
"	      for Amiga:  s:.vimrc
"  for MS-DOS and Win32:  $VIM\_vimrc
"	    for OpenVMS:  sys$login:.vimrc

" When started as "evim", evim.vim will already have done these settings.
if v:progname =~? "evim"
  finish
endif

" Use Vim settings, rather than Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

" allow backspacing over everything in insert mode
set backspace=indent,eol,start

if has("vms")
  set nobackup		" do not keep a backup file, use versions instead
else
  set backup		" keep a backup file (restore to previous version)
  set undofile		" keep an undo file (undo changes after closing)
endif
set history=50		" keep 50 lines of command line history
set ruler		" show the cursor position all the time
set showcmd		" display incomplete commands
set incsearch		" do incremental searching

" For Win32 GUI: remove 't' flag from 'guioptions': no tearoff menu entries
" let &guioptions = substitute(&guioptions, "t", "", "g")

" Don't use Ex mode, use Q for formatting
map Q gq

" CTRL-U in insert mode deletes a lot.  Use CTRL-G u to first break undo,
" so that you can undo CTRL-U after inserting a line break.
inoremap <C-U> <C-G>u<C-U>

" C-home and C-end may only work in xterm
nnoremap <C-home> gg^
inoremap <C-home> <esc>gg^i
nnoremap <C-end> G$
inoremap <C-end> <esc>G$i
nnoremap <C-n>   :tabnew<cr>
inoremap <C-n>   <esc>:tabnew<cr><esc>i
nnoremap <C-o>   :tabnew<cr>:Explore<cr>   " open new tab with open file dialog
inoremap <C-o>   <esc>:tabnew<cr>:Explore<cr>i
nnoremap <C-w>   :close<cr>                " close tab except if it is last tab
inoremap <C-w>   <esc>:close<cr>i
nnoremap <Tab>   :tabnext<cr>
nnoremap <S-Tab> :tabprevious<cr>
nnoremap <C-s>   :w<cr>
inoremap <C-s>   <esc>:w<cr>i
"ctrl+z needed to move vim into background in terminal ...
"nnoremap <C-z>   u
"inoremap <C-z>   <esc>ui
inoremap <C-u>   <esc>ui
nnoremap <C-y>   :redo<cr>
inoremap <C-y>   <esc>:redo<cr>i
inoremap <S-Tab> <esc><<i
nnoremap <C-f>   /
inoremap <C-f>   <esc>/
nnoremap <C-d>   yyp
inoremap <C-d>   <esc>yypi
" Trim trailing whitespaces. Save and restore search buffer/register
" Also deactivate search highlighting of last search
nnoremap <C-t>   :let _searchisttmp=@/<Bar>:%s/\s\+$//<Bar>:let @/=_searchisttmp<Bar>:nohlsearch<cr>
inoremap <C-t>   <esc>:let _searchisttmp=@/<Bar>:%s/\s\+$//<Bar>:let @/=_searchisttmp<Bar>:nohlsearch<cr>i
" automatically delete trailing whitespaces on buffer write out
" autocmd BufWritePre * :%s/\s\+$//e
" Use w!! to save file using sudo
cmap w!! %!sudo tee > /dev/null %

" In many terminal emulators the mouse works just fine, thus enable it.
if has('mouse')
  set mouse-=a
endif

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif

" Only do this part when compiled with support for autocommands.
if has("autocmd")

  " Enable file type detection.
  " Use the default filetype settings, so that mail gets 'tw' set to 72,
  " 'cindent' is on in C files, etc.
  " Also load indent files, to automatically do language-dependent indenting.
  filetype plugin indent on
  au BufNewFile,BufRead *.ptx     set filetype=asm
  set tabstop=4
  set shiftwidth=4
  set expandtab
  set ignorecase   " ignore case when searching
  set number       " activate line numbers by default. turn off with 'set nonumber'

  " When pasting text autoindenting will make it look all wrong -.-
  " Therefore turn of autoindent with F10 before pasting or manually with ':set paste' and ':set nopaste'
  set pastetoggle=<F2>
  set undolevels=10000

  " Put these in an autocmd group, so that we can delete them easily.
  augroup vimrcEx
  au!

  " For all text files set 'textwidth' to 78 characters.
  autocmd FileType text setlocal textwidth=78

  " When editing a file, always jump to the last known cursor position.
  " Don't do it when the position is invalid or when inside an event handler
  " (happens when dropping a file on gvim).
  " Also don't do it when the mark is in the first line, that is the default
  " position when opening a file.
  autocmd BufReadPost *
    \ if line("'\"") > 1 && line("'\"") <= line("$") |
    \   exe "normal! g`\"" |
    \ endif

  augroup END

else

  set autoindent		" always set autoindenting on

endif " has("autocmd")

" Convenient command to see the difference between the current buffer and the
" file it was loaded from, thus the changes you made.
" Only define it when not defined already.
if !exists(":DiffOrig")
  command DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis
		  \ | wincmd p | diffthis
endif

set textwidth=0 wrapmargin=0

