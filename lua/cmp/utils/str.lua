local char = require'cmp.utils.char'

local str = {}

local INVALID_CHARS = {}
INVALID_CHARS[string.byte(' ')] = true
INVALID_CHARS[string.byte('=')] = true
INVALID_CHARS[string.byte('$')] = true
INVALID_CHARS[string.byte('(')] = true
INVALID_CHARS[string.byte('"')] = true
INVALID_CHARS[string.byte("'")] = true
INVALID_CHARS[string.byte("\n")] = true
INVALID_CHARS[string.byte("\t")] = true

---Return if specified text has prefix or not
---@param text string
---@param prefix string
---@return boolean
str.has_prefix = function(text, prefix)
  if #text < #prefix then
    return false
  end
  for i = 1, #prefix do
    if not char.match(string.byte(text, i), string.byte(prefix, i)) then
      return false
    end
  end
  return true
end

---omit
---@param text string
---@param width number
---@return string
str.omit = function(text, width)
  if width == 0 then
    return ''
  end

  if not text then
    text = ''
  end
  if #text > width then
    return string.sub(text, 1, width + 1) .. '...'
  end
  return text
end

---trim
---@param text string
---@return string
str.trim = function(text)
  local s = 1
  for i = 1, #text do
    if not char.is_white(string.byte(text, i)) then
      s = i
      break
    end
  end

  local e = #text
  for i = #text, 1, -1 do
    if not char.is_white(string.byte(text, i)) then
      e = i
      break
    end
  end
  if s == 1 and e == #text then
    return text
  end
  return string.sub(text, s, e)
end

---get_word
---@param text string
---@return string
str.get_word = function(text)
  local has_valid = false
  for idx = 1, #text do
    local invalid = INVALID_CHARS[string.byte(text, idx)]
    if has_valid and invalid then
      return string.sub(text, 1, idx - 1)
    end
    has_valid = has_valid or not invalid
  end
  return text
end

---make_byte_map
---@param text string
---@return table<number, boolean>
str.make_byte_map = function(text)
  local has_symbol = false
  local map = {}
  for i = 1, #text do
    local byte = string.byte(text, i)
    map[byte] = true
    has_symbol = has_symbol or char.is_symbol(byte)
  end
  return map, has_symbol
end

return str


