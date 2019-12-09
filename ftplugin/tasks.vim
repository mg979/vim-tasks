" Tasks plugin
" Language:    Tasks
" Maintainer:  Chris Rolfs
" Last Change: Aug 7, 2015
" Version:	   0.1
" URL:         https://github.com/irrationalistic/vim-tasks

if exists("b:loaded_tasks")
  finish
endif
let b:loaded_tasks = 1

" MAPPINGS
nnoremap <buffer> <leader>n :call <sid>NewTask(1)<cr>
nnoremap <buffer> <leader>N :call <sid>NewTask(-1)<cr>
nnoremap <buffer> <leader>d :call <sid>TaskComplete()<cr>
nnoremap <buffer> <leader>D :call <sid>TasksDue(0)<cr>
nnoremap <buffer> <leader>x :call <sid>TaskCancel()<cr>
nnoremap <buffer> <leader>a :call <sid>TasksArchive()<cr>

inoremap    <buffer> <CR> <c-r>=<sid>TasksCr()<cr>
inoreabbrev <buffer> due <c-r>=<sid>TasksDue(1)<cr>

" GLOBALS

" Helper for initializing defaults
" (https://github.com/scrooloose/nerdtree/blob/master/plugin/NERD_tree.vim#L39)
fun! s:initVariable(var, value)
  if !exists(a:var)
    exec 'let ' . a:var . ' = ' . "'" . substitute(a:value, "'", "''", "g") . "'"
    return 1
  endif
  return 0
endfun

if exists('g:loaded_mucomplete')
  let b:mucomplete_wordlist           = ['@critical', '@high', '@low', '@due']
  let b:mucomplete_chain              = ['list', 'keyn']
  let g:mucomplete#can_complete       = get(g:, 'mucomplete#can_complete', {})
  let g:mucomplete#can_complete.tasks = {'list': { t -> t =~# g:TasksAttributeMarker }}

  if !exists('#MUcompleteAuto')
    imap <buffer> @ @<Plug>(MUcompleteFwd)
  endif
endif

call s:initVariable('g:TasksMarkerBase', '☐')
call s:initVariable('g:TasksMarkerDone', '✔')
call s:initVariable('g:TasksMarkerCancelled', '✘')
call s:initVariable('g:TasksDateFormat', '%Y-%m-%d %H:%M')
call s:initVariable('g:TasksAttributeMarker', '@')
call s:initVariable('g:TasksArchiveSeparator', '＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿')

let b:regesc = '[]()?.*@='

" LOCALS
let s:regProject   = '^\s*.*:$'
let s:regMarker    = join([escape(g:TasksMarkerBase, b:regesc), escape(g:TasksMarkerDone, b:regesc), escape(g:TasksMarkerCancelled, b:regesc)], '\|')
let s:regDue       = g:TasksAttributeMarker . 'due'
let s:regDone      = g:TasksAttributeMarker . 'done'
let s:regCancelled = g:TasksAttributeMarker . 'cancelled'
let s:regAttribute = g:TasksAttributeMarker . '\w\+\(([^)]*)\)\='
let s:dateFormat   = g:TasksDateFormat

fun! s:TasksCr()
  let ln = getline('.')
  let cr = pumvisible() ? "\<c-e>\<cr>" : "\<cr>"
  if match(ln, '\w\+:$') >= 0
    return cr."  ".g:TasksMarkerBase.' '
  elseif match(ln, g:TasksMarkerBase) >= 0
    return cr.g:TasksMarkerBase.' '
  else
    return cr
  endif
endfun

fun! s:Trim(input_string)
  return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfun

fun! s:TasksDue(insert)
  let days = get(g:, 'TasksDueDays', 10)
  let time = localtime() + days * 24 * 60 * 60
  let hour = get(g:, 'TasksDueHour', '12:00')
  if a:insert
    return "due ".strftime("%Y %b %d", time)." ".hour
  endif
  exe "normal! A @due ".strftime("%Y %b %d", time)." ".hour
endfun

fun! s:NewTask(direction)
  let line = getline('.')
  let isMatch = match(line, s:regProject)
  let text = g:TasksMarkerBase . ' '

  if a:direction == -1
    exec 'normal O' . text
  else
    exec 'normal o' . text
  endif

  if isMatch > -1
    exec 'normal >>'
  endif

  startinsert!
endfun

fun! s:set_line_marker(marker)
  " if there is a marker, swap it out.
  " If there is no marker, add it in at first non-whitespace
  let line = getline('.')
  let markerMatch = match(line, s:regMarker)
  if markerMatch > -1
    call cursor(line('.'), markerMatch + 1)
    exec 'normal R' . a:marker
  endif
endfun

fun! s:add_attribute(name, value)
  " at the end of the line, insert in the attribute:
  let attVal = ''
  if a:value != ''
    let attVal = '(' . a:value . ')'
  endif
  exec 'normal A ' . g:TasksAttributeMarker . a:name . attVal
endfun

fun! s:remove_attribute(name)
  " if the attribute exists, remove it
  let rline = getline('.')
  if a:name == 'due'
    let regex = g:TasksAttributeMarker . 'due \d\+\s\w\+\s\d\+\s\d\+:\d\+'
  else
    let regex = g:TasksAttributeMarker . a:name . '\(([^)]*)\)\='
  endif
  let attStart = match(rline, regex)
  if attStart > -1
    let attEnd = matchend(rline, regex)
    let diff = (attEnd - attStart) + 1
    call cursor(line('.'), attStart)
    exec 'normal ' . diff . 'dl'
  endif
endfun

fun! s:get_projects()
  " read from current line upwards, seeking all project matches
  " and adding them to a list
  let lineNr = line('.') - 1
  let results = []
  while lineNr > 0
    let match = matchstr(getline(lineNr), s:regProject)
    if len(match)
      call add(results, s:Trim(strpart(match, 0, len(match) - 1)))
      if indent(lineNr) == 0
        break
      endif
    endif
    let lineNr = lineNr - 1
  endwhile
  return reverse(results)
endfun

fun! s:TaskComplete()
  let line = getline('.')
  let isMatch = match(line, s:regMarker)
  let doneMatch = match(line, s:regDone)
  let cancelledMatch = match(line, s:regCancelled)
  let dueMatch = match(line, s:regDue)

  if isMatch > -1
    if doneMatch > -1
      " this task is done, so we need to remove the marker and the
      " @done/@project
      call s:set_line_marker(g:TasksMarkerBase)
      call s:remove_attribute('done')
      call s:remove_attribute('project')
    else
      if cancelledMatch > -1
        " this task was previously cancelled, so we need to swap the marker
        " and just remove the @cancelled first
        call s:remove_attribute('cancelled')
        call s:remove_attribute('project')
      endif
      if dueMatch > -1
        " remove the @due marker
        call s:remove_attribute('due')
        call s:remove_attribute('project')
      endif
      " swap out the marker, add the @done, find the projects and add @project
      let projects = s:get_projects()
      call s:set_line_marker(g:TasksMarkerDone)
      call s:add_attribute('done', strftime(s:dateFormat))
      call s:add_attribute('project', join(projects, ' / '))
    endif
  endif
endfun

fun! s:TaskCancel()
  let line = getline('.')
  let isMatch = match(line, s:regMarker)
  let doneMatch = match(line, s:regDone)
  let cancelledMatch = match(line, s:regCancelled)

  if isMatch > -1
    if cancelledMatch > -1
      " this task is done, so we need to remove the marker and the
      " @done/@project
      call s:set_line_marker(g:TasksMarkerBase)
      call s:remove_attribute('cancelled')
      call s:remove_attribute('project')
    else
      if doneMatch > -1
        " this task was previously cancelled, so we need to swap the marker
        " and just remove the @cancelled first
        call s:remove_attribute('done')
        call s:remove_attribute('project')
      endif
      " swap out the marker, add the @done, find the projects and add @project
      let projects = s:get_projects()
      call s:set_line_marker(g:TasksMarkerCancelled)
      call s:add_attribute('cancelled', strftime(s:dateFormat))
      call s:add_attribute('project', join(projects, ' / '))
    endif
  endif
endfun

fun! s:TasksArchive()
  " go over every line. Compile a list of all cancelled or completed items
  " until the end of the file is reached or the archive project is
  " detected, whicheved happens first.
  let archiveLine = -1
  let completedTasks = []
  let lineNr = 0
  while lineNr < line('$')
    let line = getline(lineNr)
    let doneMatch = match(line, s:regDone)
    let cancelledMatch = match(line, s:regCancelled)
    let projectMatch = matchstr(line, s:regProject)

    if doneMatch > -1 || cancelledMatch > -1
      call add(completedTasks, [lineNr, s:Trim(line)])
    endif

    if projectMatch > -1 && s:Trim(line) == 'Archive:'
      let archiveLine = lineNr
      break
    endif

    let lineNr = lineNr + 1
  endwhile

  if archiveLine == -1
    " no archive found yet, so let's stick one in at the very bottom
    exec '%s#\($\n\s*\)\+\%$##'
    exec 'normal Go'
    exec 'normal o' . g:TasksArchiveSeparator
    exec 'normal oArchive:'
    let archiveLine = line('.')
  endif

  call cursor(archiveLine, 0)

  for [lineNr, line] in completedTasks
    exec 'normal o' . line
    if indent(line('.')) == 0
      exec 'normal >>'
    endif
  endfor

  for [lineNr, line] in reverse(completedTasks)
    call cursor(lineNr, 0)
    exec 'normal "_dd'
  endfor
endfun
