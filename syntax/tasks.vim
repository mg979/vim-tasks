" Tasks syntax
" Language:    Tasks
" Maintainer:  Chris Rolfs
" Last Change: Aug 7, 2015
" Version:	   0.1
" URL:         https://github.com/irrationalistic/vim-tasks

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'tasks'
endif

silent! syntax include @markdown syntax/markdown.vim
unlet! b:current_syntax

syn case match
syn sync fromstart

let b:regesc = '[]()?.*@='

function! s:CreateMatch(name, regex)
  exec 'syn match ' . a:name . ' "' . a:regex . '" contained'
endfunc


call s:CreateMatch('tMarker', '^\s*' . escape(g:TasksMarkerBase, b:regesc))
call s:CreateMatch('tMarkerCancelled', '^\s*' . escape(g:TasksMarkerCancelled, b:regesc))
call s:CreateMatch('tMarkerComplete', '^\s*' . escape(g:TasksMarkerDone, b:regesc))

exec 'syn match tAttribute          "' . g:TasksAttributeMarker . '\w\+\(([^)]*)\)\=" contained'
exec 'syn match tAttributeCompleted "' . g:TasksAttributeMarker . '\w\+\(([^)]*)\)\=" contained'
exec 'syn match tCriticalPriority   "' . g:TasksAttributeMarker . 'critical" contained'
exec 'syn match tHighPriority       "' . g:TasksAttributeMarker . 'high" contained'
exec 'syn match tLowPriority        "' . g:TasksAttributeMarker . 'low" contained'

syn region tTask start=/^\s*/ end=/$/ oneline keepend contains=tMarker,tAttribute,tCriticalPriority,tHighPriority,tLowPriority
exec 'syn region tTaskDone start="^[\s]*.*'.g:TasksAttributeMarker.'done" end=/$/ oneline contains=tMarkerComplete,tAttributeCompleted'
exec 'syn region tTaskCancelled start="^[\s]*.*'.g:TasksAttributeMarker.'cancelled" end=/$/ oneline contains=tMarkerCancelled,tAttributeCompleted'
syn match tProject "^\s*.*:$"

hi def link tMarker Comment
hi def link tMarkerComplete String
hi def link tMarkerCancelled Statement
hi def link tAttribute Special
hi def link tAttributeCompleted Function
hi def link tTaskDone Comment
hi def link tTaskCancelled Comment
hi def link tProject Constant
if has('nvim')
  hi def tCriticalPriority ctermbg=9 ctermfg=15 cterm=NONE guibg=#ff0000 guifg=#FFFFFF gui=NONE
  hi def tHighPriority ctermbg=208 ctermfg=0 cterm=NONE guibg=#ff8700 guifg=#000000 gui=NONE
  hi def tLowPriority ctermbg=186 ctermfg=0 cterm=NONE guibg=#dada93 guifg=#000000 gui=NONE
else
  hi def link tCriticalPriority ErrorMsg
  hi def link tHighPriority WarningMsg
  hi def link tLowPriority Type
endif
