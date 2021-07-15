local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.complete = function(self, request, callback)
  local r = vim.regex([[\d\+\%(\.\d\+\)\?\%(\s\+\|\d\+\%(\.\d\+\)\?\|+\|\-\|/\|\*\|%\|\^\|(\|)\)\+\s*$]])
  local s = r:match_str(request.context.cursor_before_line)
  if not s then
    return callback()
  end
  local input = string.sub(request.context.cursor_before_line, s + 1)

  -- Ignore if input has no math operators.
  if string.match(input, '^[%s%d%.]*$') ~= nil then
    return callback()
  end

  -- Ignore if failed to interpret to Lua.
  local m = load(('return (%s)'):format(input))
  if type(m) ~= 'function' then
    return callback()
  end
  local status, value = pcall(function()
    return '' .. m()
  end)

  -- Ignore if return values is not number.
  if not status then
    return callback()
  end

  callback({
    items = {
      {
        label = self:_trim(input),
        filterText = input,
        textEdit = {
          range = {
            start = {
              line = request.context.cursor.row - 1,
              character = s,
            },
            ['end'] = {
              line = request.context.cursor.row - 1,
              character = request.context.cursor.col - 1,
            },
          },
          newText = value,
        },
      },
      {
        label = self:_trim(input) .. ' = ' .. value,
        filterText = input,
        textEdit = {
          range = {
            start = {
              line = request.context.cursor.row - 1,
              character = s,
            },
            ['end'] = {
              line = request.context.cursor.row - 1,
              character = request.context.cursor.col - 1,
            },
          },
          newText = self:_trim(input) .. ' = ' .. value,
        },
      },
    },
    isIncomplete = true,
  })
end

source._trim = function(_, text)
  text = string.gsub(text, '^%s*', '')
  text = string.gsub(text, '%s*$', '')
  return text
end

return source
