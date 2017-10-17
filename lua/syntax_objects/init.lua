-- Set up {{{
local debug = function(s, ...)
  local __debug = false
  if __debug then
    print(string.format(s, ...))
  end
end

-- luacheck: globals table.map
-- Set up some useful items for me
table.map = function(array, func)
  local new_array = {}

  for index, value in ipairs(array) do
    new_array[index] = func(value)
  end

  return new_array
end

-- luacheck: globals table.contains
table.contains = function(array, value)
  for _, v in ipairs(array) do
    if v == value then
      return true
    end
  end

  return false
end

-- luacheck: globals table.default
table.default = function(array, key, value)
  if array[key] == nil then
    array[key] = value
  end
end

local lazy_ternary = function(cond, func_true, func_false)
  local func_ref
  local func_args

  if cond then
    if type(func_true) ~= 'table' then
      -- debug('f true (%s): %s %s', type(func_true), func_true, 'not a table')
      return func_true
    end
    func_ref = table.remove(func_true, 1)
    func_args = func_true
  else
    if type(func_false) ~= 'table' then
      -- debug('f false (%s): %s, %s', type(func_false), func_false, 'not a table')
      return func_false
    end
    func_ref = table.remove(func_false, 1)
    func_args = func_false
  end

  if type(func_ref) ~= 'function' then
    return func_ref
  end

  return func_ref(unpack(func_args))
end

local call_func = function(...) return vim.api.nvim_call_function(...) end
local lazy_func = function(...) return { call_func, ... } end

-- }}}
local plugin = {}
-- Used to keep track of how many items we've checked.
plugin.count = 0

plugin.get_groups_at_position = function(line, col) -- {{{1
  -- TODO: Also handling things like "synIDtrans"?
  -- debug('checking position: %s %s', line, col)
  return table.map(call_func('synstack', {line, col}), function(val)
    return string.lower(call_func('synIDattr', {val, 'name'}))
  end)
end

plugin.in_group = function(group, line, column) -- {{{1
  return table.contains(plugin.get_groups_at_position(line, column), group)
end

plugin.search_group = function(line, column, arg_group, options) -- {{{1
  plugin.count = 0

  local direction = options.search_direction
  local ignore_current = options.ignore_current
  local early_quit = options.fast

  if early_quit then
    debug('todo')
  end

  local group = string.lower(arg_group)

  local found = false
  local end_line = lazy_ternary(direction == 1, lazy_func('line', {'$'}), 1) + direction

  -- {{{2 Handle ignore current
  if ignore_current and plugin.in_group(group, line, column) then
    local ignore_break = false

    while line ~= end_line and line > 0 do
      local end_column = lazy_ternary(
        direction == 1
          , lazy_func('col', { {line, '$'} })
          , 1
        ) + direction

      while column ~= end_column and column > 0 do

        if plugin.in_group(group, line, column) then
          column = column + direction
        else
          ignore_break = true
          break
        end

        column = column + direction
      end

      if ignore_break then break end

      line = line + direction
      column = lazy_ternary(
        direction == 1
          , 1
          , lazy_func('col', { {line, '$'} })
        )
    end
  end

  -- {{{2 Main Checking
  while line ~= end_line and line > 0 do
    local end_column = lazy_ternary(
      direction == 1
        , lazy_func('col', { {line, '$'} })
        , 1
      ) + direction

    while column ~= end_column and column > 0 do
      plugin.count = plugin.count + 1

      if not options.force and plugin.count > 1000 then
        return {-1, -1}
      end

      if plugin.in_group(group, line, column) then
        found = true
      elseif found then
        if column == lazy_ternary(
            direction == 1
              , 0
              , lazy_func('col', { {line, '$'} })
            ) then
          line = line - direction
          column = lazy_ternary(
            direction == 1
              , lazy_func('col', { {line, '$'} })
              , 0
            )
        end

        return {line, column - direction}
      end

      column = column + direction
    end

    line = line + direction
    column = lazy_ternary(
      direction == 1,
        1,
        lazy_func('col',{ {line, '$'} })
      )
  end

  if found then
    if direction == 1 then
      local quit_line = call_func('line', {'$'})
      return {quit_line, call_func('col', {quit_line, '$'})}
    else
      return {1, 1}
    end
  end

  debug('Could not find anything: %s, %s', line, column)
  return {-1, -1}
end

plugin.search_backward = function(line, column, group, options) -- {{{1
  options.search_direction = -1

  return plugin.search_group(line, column, group, options)
end

plugin.search_forward = function(line, column, group, options) -- {{{1
  options.search_direction = 1

  return plugin.search_group(line, column, group, options)
end


local update_position_forward = function(position, line, column, group, options) -- {{{1
  local result = plugin.search_forward(
    line,
    column,
    group,
    options
  )
  position.finish.line = result[1]
  position.finish.col = result[2]
end

local update_position_backward = function(position, line, column, group, options) -- {{{1
  local result = plugin.search_backward(
    line,
    column,
    group,
    options
  )
  debug('Searching backwards, result: %s, %s', result[1], result[2])
  position.start.line = result[1]
  position.start.col = result[2]
end

local is_invalid_search = function(position) --- {{{1
  if table.contains(
    {position.start.line, position.start.col, position.finish.line, position.finish.col},
    -1
    ) then
    return true
  else
    return false
  end
end

plugin.get_group = function(arg_group, options, start_line, start_column) -- {{{1
  local group = string.lower(arg_group)

  table.default(options, 'direction', 1)
  table.default(options, 'ignore_current', false)
  table.default(options, 'fast', false)
  table.default(options, 'force', false)

  local position = {
    start = {},
    finish = {},
  }

  if not options.ignore_current or (options.direction == 0) then
    if plugin.in_group(group, start_line, start_column) then
      debug('Searching within current match...')

      -- TODO: I don't really want to have to write the "update_position_***" functions twice

      -- If we want only the fastest result and we're going forward,
      -- just return the forward result
      local current_options = { unpack(options) }
      current_options.ignore_current = false
      if options.fast == 'finish' then
        position.start = nil
        update_position_forward(position, start_line, start_column, group, current_options)
        return position
      end

      -- If we want only the fastest result and we're going backward,
      -- just return the backward result
      if options.fast == 'start' then
        update_position_backward(position, start_line, start_column, group, current_options)
        position.finish = nil
        return position
      end

      update_position_forward(position, start_line, start_column, group, current_options)
      update_position_backward(position, start_line, start_column, group, current_options)

      return position
    end
  end

  -- We didn't find anything and we wanted the current item.
  -- Return nil
  if options.direction == 0 then
    return nil
  end

  -- Search to the right
  if options.direction == 1 then
    debug('Searching to the right')

    update_position_forward(position, start_line, start_column, group, options)

    if options.fast == 'finish' then
      position.start = nil
      return position
    end

    local backward_options = { unpack(options) }
    backward_options.ignore_current = false
    update_position_backward(position, position.finish.line, position.finish.col, group, backward_options)

    if is_invalid_search(position) then return nil end

    return position
  end

  -- Search to the left
  if options.direction == -1 then
    debug('Searching to the left')

    update_position_backward(position, start_line, start_column, group, options)

    if options.fast == 'start' then
      position.finish = nil
      return position
    end

    local forward_options = { unpack(options) }
    forward_options.ignore_current = false
    update_position_forward(position, position.start.line, position.start.col, group, forward_options)

    if is_invalid_search(position) then return nil end

    return position
  end

  return nil
end -- }}}

return plugin
