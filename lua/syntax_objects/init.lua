-- Set up {{{
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
  if array[value] ~= nil then
    return true
  else
    return false
  end
end

local ternary = function(cond, t, f)
  if cond then
    return t
  else
    return f
  end
end

local lazy_ternary = function(cond, func_true, func_false)
  local func_ref
  local func_args

  if cond then
    if type(func_true) ~= 'table' then return func_true end
    func_ref = table.remove(func_true, 1)
    func_args = func_true
  else
    if type(func_false) ~= 'table' then return func_true end
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

local debug = function(s, ...)
  local __debug = true
  if __debug then
    print(string.format(s, ...))
  end
end
-- }}}

local plugin = {}

plugin.get_groups_at_position = function(line, col)
  -- TODO: Also handling things like "synIDtrans"?
  -- debug('checking position: %s %s', line, col)
  return table.map(call_func('synstack', {line, col}), function(val)
    return string.lower(call_func('synIDattr', {val, 'name'}))
  end)
end

plugin.in_group = function(group, line, column)
  return table.contains(plugin.get_groups_at_position(line, column), group)
end

plugin.search_group = function(line, column, arg_group, direction, ignore_current, early_quit)
  if early_quit then
    debug('todo')
  end

  local group = string.lower(arg_group)

  local found = false
  local ignore_break = false
  local end_line = lazy_ternary(direction == 1, lazy_func('line', {'$'}), -1) + 1

  if ignore_current and plugin.in_group(group, line, column) then
    while line ~= end_line and line > 0 do
      local end_column = lazy_ternary(direction == 1, lazy_func('col', { {line, '$'} }) + 1, 0)
      debug('Ignore current checking: %s, %s. End (line, column): %s, %s', line, column, end_line, end_column)

      while column ~= end_column and column > 0 do

        if plugin.in_group(group, line, column) then
          column = column + direction
        else
          ignore_break = true
          break
        end
      end

      if ignore_break then break end

      line = line + direction
      column = lazy_ternary(direction == 1, 1, lazy_func('col', { {line, '$'} }))
    end
  end

  while line ~= end_line and line > 0 do
    local end_column = ternary(direction == 1, call_func('col', { {line, '$'} }) + 1, 0)

    debug('Regular checking: %s, %s. End (line, column): %s, %s', line, column, end_line, end_column)
    while column ~= end_column and column > 0 do
      local syntax_list = plugin.get_groups_at_position(line, column)

      if table.contains(syntax_list, group) then
        found = true
      elseif found then
        if column == lazy_ternary(direction == 1, 0, lazy_func('col', { {line, '$'} })) then
          line = line - direction
          column = lazy_ternary(direction == 1, lazy_func('col', { {line, '$'} }), 0)
        end
        return {line, column}
      end

      column = column + direction
    end
  end

  if found then
    if direction == 1 then
      local quit_line = call_func('line', {'$'})
      return {quit_line, call_func('col', {quit_line, '$'})}
    else
      return {1, 1}
    end
  end

  return {-1, -1}
end

plugin.search_backward = function(line, column, group, ignore_current, early_quit)
  return plugin.search_group(line, column, group, -1, ignore_current, early_quit)
end

plugin.search_forward = function(line, column, group, ignore_current, early_quit)
  return plugin.search_group(line, column, group, 1, ignore_current, early_quit)
end

plugin.get_group = function(arg_group, ...)
  local group = string.lower(arg_group)

  return { group, ...}
end

return plugin
