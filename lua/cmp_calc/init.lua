local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = function()
  return { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ' ', '+', '-', '/', '*', ')' }
end

source.complete = function(self, request, callback)
  local r = vim.regex([[\%(\d\+\%(\.\d\+\)\?\|+\|\-\|/\|\*\|%\|\^\|(\|)\)\%(\d\+\%(\.\d\+\)\?\|+\|\-\|/\|\*\|%\|\^\|(\|)\|\s\+\)*$]])
  local s = r:match_str(request.context.cursor_before_line)
  if not s then
    return callback()
  end
  local input = string.sub(request.context.cursor_before_line, s + 1)

  -- Ignore if input has no math operators.
  if string.match(input, '^[%s%d%.]*$') ~= nil then
    return callback()
  end

  -- Analyze column count and program script.
  local program, delta = self:_analyze(input)
  if not program then
    return callback()
  end

  -- Ignore if failed to interpret to Lua.
  local m = load(('return (%s)'):format(program))
  if type(m) ~= 'function' then
    return callback()
  end
  local status, value = pcall(function()
    return '' .. m()
  end)

  -- Ignore if return values is not a number.
  if not status then
    return callback()
  end

  callback({
    items = {
      {
        word = self:_trim_right(program) .. ' = ' .. value,
        label = self:_trim_right(program) .. ' = ' .. value,
        textEdit = {
          range = {
            start = {
              line = request.context.cursor.row - 1,
              character = s + delta,
            },
            ['end'] = {
              line = request.context.cursor.row - 1,
              character = request.context.cursor.col - 1,
            },
          },
          newText = value,
        },
      },
    },
    isIncomplete = true,
  })
end

source._analyze = function(_, input)
  local stack = {}
  local unmatched_paren_count = 0
  local o = string.byte('(')
  local c = string.byte(')')
  for i = #input, 1, -1 do
    if string.byte(input, i) == c then
      table.insert(stack, ')')
    elseif string.byte(input, i) == o then
      if #stack > 0 then
        table.remove(stack, #stack)
      else
        unmatched_paren_count = unmatched_paren_count + 1
      end
    end
  end

  local program = input
  while true do
    local fixed_program = string.gsub(program, '^%s*%(', '')
    if fixed_program ~= program then
      unmatched_paren_count = unmatched_paren_count - 1
      program = fixed_program
    else
      break
    end
  end

  -- invalid math expression.
  if unmatched_paren_count > 0 then
    return nil, nil
  end

  return program, #input - #program
end

source._trim_right = function(_, text)
  return string.gsub(text, '%s*$', '')
end

return source
