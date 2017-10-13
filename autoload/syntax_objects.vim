" Helper Functions {{{
function! s:find_start_group(line, col, group_name, ignore_current)
  return s:search_group(a:line, a:col, a:group_name, -1, a:ignore_current)
endfunction

function! s:find_end_group(line, col, group_name, ignore_current)
  return s:search_group(a:line, a:col, a:group_name, 1, a:ignore_current)
endfunction

function! s:debug(...)
  let d = v:false

  if d
    echo join(a:000, ' ')
  endif
endfunction

function! s:get_groups_at_position(line, col)
  " return the lower case version of this. Really no reason not to
  return map(synstack(a:line, a:col), { index, val -> tolower(synIDattr(val, 'name')) })
endfunction

function! syntax_objects#groups_at_cursor()
  return s:get_groups_at_position(line('.'), col('.'))
endfunction

" }}}

""
" @param direction: +1 for forwards, -1 for backwards
function! s:search_group(line, col, group_name, direction, ignore_current)
  let group = tolower(a:group_name)

  let found = v:false

  let current_line = a:line
  let current_col = a:col

  let end_line = a:direction == 1 ? line('$') + 1 : 0

  " {{{ Ignore Current
  if a:ignore_current && std#list#contains(s:get_groups_at_position(current_line, current_col), group)
    call s:debug('Checking for ignore current...', current_line, current_col)
    let ignore_break = v:false

    while current_line != end_line && current_line > 0
      let end_col = a:direction == 1 ? col([current_line, '$']) + 1 : 0
      while current_col != end_col && current_col > 0
        if std#list#contains(s:get_groups_at_position(current_line, current_col), group)
          call s:debug('Still contains item...', printf('{"line": %s, "col": %s}', current_line, current_col))
          let current_col = current_col + a:direction
        else
          call s:debug(printf('Setting ignore break with {"line": %s, "col": %s}', current_line, current_col))
          let ignore_break = v:true
          break
        endif
      endwhile

      if ignore_break
        break
      endif

      let current_line = current_line + 1
      let current_col = a:direction == 1 ? 1 : col([current_line, '$'])
    endwhile

    call s:debug('current_line', current_line, 'current_col', current_col)
  endif
  " }}}

  while current_line != end_line && current_line > 0
    let end_col = a:direction == 1 ? col([current_line, '$']) + 1 : 0
    while current_col != end_col && current_col > 0
      let syntax_list = s:get_groups_at_position(current_line, current_col)

      call s:debug(current_line, current_col, syntax_list)

      if !empty(syntax_list) || found
        if index(syntax_list, group) >= 0
          if !found
            let found = v:true
          endif
        else
          if found
            " Handle some end of line shenanigans
            if current_col == (a:direction == 1 ? 0 : col([current_line, '$']))
              call s:debug('End of line:', current_line, current_col)
              let current_line = current_line - a:direction
              let current_col = a:direction == 1 ? col([current_line, '$']) : 0
            endif

            call s:debug(printf('Dir: %s | Current: %s, %s | End: %s, %s',
                  \ a:direction, current_line, current_col, end_line, end_col))

            return [current_line, current_col - a:direction]
          endif
        endif
      endif

      let current_col = current_col + a:direction
    endwhile

    let current_line = current_line + a:direction
    let current_col = a:direction == 1 ? 1 : col([current_line, '$'])
  endwhile

  if found
    if a:direction == 1
      return [line('$'), col([line('$'), '$')]
    else
      return [1, 1]
    endif
  endif

  return [-1, -1]
endfunction

""
" @param arg_group  (string): The name of the syntax group you want to find
" @param options    [Optional](dict): How do you want this to work? :)
"   @key 'direction' (int): [Default = 1]
"       -1: Search behind location
"       0:  Only search where we are right now
"       1:  Search forward of location
"
"   @key 'ignore_current' (bool): [Default = v:false]
"       v:true:     If you're on a match right now, ignore that
"       v:false:    Don't ignore a match if you're on one right now
"
" @param line       [Optional](int)
" @param column     [Optional](int)
"
" Return { 'start': {'line', 'col'}, 'end': {'line', 'col'} }
"   or v:null if no valid answers
function! syntax_objects#get_group(arg_group, ...) abort
  let group = tolower(a:arg_group)

  let options = get(a:000, 0, {})
  let options.direction = get(options, 'direction', 1)
  let options.ignore_current = get(options, 'ignore_current', v:false)

  let current_line = get(a:000, 1, line('.'))
  let current_column = get(a:000, 2, col('.'))

  let current_groups = s:get_groups_at_position(current_line, current_column)

  let pos = {}
  let pos.start = {}
  let pos.finish = {}

  if !options.ignore_current || (options.direction == 0)
    if std#list#contains(current_groups, group)
      let [pos.start.line, pos.start.col] =
            \ s:find_start_group(current_line, current_column, group, v:false)

      let [pos.finish.line, pos.finish.col] =
            \ s:find_end_group(current_line, current_column, group, v:false)

      return pos
    endif
  endif

  " We were looking for a current one, but we didn't find it.
  " So return our non-answer
  if options.direction == 0
    return v:null
  endif

  " Search to the right.
  if options.direction == 1
    " Find the end of the group first
    call s:debug('Searching forward for end')
    let [pos.finish.line, pos.finish.col] =
          \ s:find_end_group(current_line, current_column, group, options.ignore_current)

    " Find the start of that group after that
    call s:debug('Searching forward for start')
    let [pos.start.line, pos.start.col] =
          \ s:find_start_group(pos.finish.line, pos.finish.col, group, v:false)

    if std#list#contains([pos.start.line, pos.start.col, pos.finish.line, pos.finish.col], -1)
      return v:null
    endif

    return pos
  endif

  " Search to the left.
  if options.direction == -1
    " Find the start of the group
    call s:debug('Searching backward for start')
    let [pos.start.line, pos.start.col] =
          \ s:find_start_group(current_line, current_column, group, options.ignore_current)

    " And use that to find the end of the group
    call s:debug('Searching backward for end')
    let [pos.finish.line, pos.finish.col] =
          \ s:find_end_group(pos.start.line, pos.start.col, group, v:false)

    if std#list#contains([pos.start.line, pos.start.col, pos.finish.line, pos.finish.col], -1)
      return v:null
    endif

    return pos
  endif

  " Return nothing if we didn't have anything good happen now
  return v:null
endfunction

""
" Move to a location based on a group
function! syntax_objects#move_to_group(group, ...) abort
  let options = get(a:000, 0, {})
  let options.location_key = get(options, 'location_key', 'start')
  let options.direction = get(options, 'direction', 1)
  let options.ignore_current = get(options, 'ignore_current', v:false)

  let location = syntax_objects#get_group(a:group, options)

  if type(location) != v:t_dict && location == v:null
    return v:null
  endif

  if !has_key(location, options.location_key)
    return v:null
  endif

  call cursor(location[options.location_key].line, location[options.location_key].col)

  return v:true
endfunction

" nnoremap <leader>te :echo syntax_objects#get_group('cType')<CR>
" nnoremap <leader>pe :echo s:find_start_group(line('.'), col('.'), 'cType')<CR>
" nnoremap <leader>to :echo s:find_end_group(line('.'), col('.'), 'cOperator')<CR>
" nnoremap <leader>po :echo s:find_start_group(line('.'), col('.'), 'cOperator')<CR>
