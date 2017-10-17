" File: autoload/syntax_objects.vim
" Author: TJ DeVries

" Helper Functions {{{
function! s:debug(...)
  let d = v:false

  if d
    echo join(a:000, ' ')
  endif
endfunction

" Return the lower case version of the names of ids, so that we can search by them
function! s:get_groups_at_position(line, col)
  return luaeval(
        \ 'require("syntax_objects.init").get_groups_at_position(_A.line, _A.col)',
        \ {'line': a:line, 'col': a:col }
        \ )
endfunction

function! syntax_objects#groups_at_cursor()
  return s:get_groups_at_position(line('.'), col('.'))
endfunction

" }}}

""
" @param direction: +1 for forwards, -1 for backwards
function! s:search_group(line, col, group_name, direction, ignore_current)
  let args = {}
  let args.line = a:line
  let args.col = a:col
  let args.group = a:group_name
  let args.options = {
        \ 'direction': a:direction,
        \ 'ignore_current': a:ignore_current,
        \ 'fast': v:true,
        \ }

  return luaeval(
        \ 'require("syntax_objects.init").search_group(_A.line, _A.col, _A.group, _A.options)',
        \ args
        \ )
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

  let current_line = get(a:000, 1, line('.'))
  let current_column = get(a:000, 2, col('.'))

  return luaeval('require("syntax_objects.init").get_group(_A.group, _A.options, _A.line, _A.col)',
        \ {
          \ 'group': group,
          \ 'options': options,
          \ 'line': current_line,
          \ 'col': current_column,
        \ })
endfunction

""
" Move to a location based on a group
function! syntax_objects#move_to_group(group, ...) abort
  let options = get(a:000, 0, {})
  let options.fast = get(options, 'fast', 'start')
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
