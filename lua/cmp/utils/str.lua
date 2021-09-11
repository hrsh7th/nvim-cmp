local char = require('cmp.utils.char')
local pattern = require('cmp.utils.pattern')

local str = {}

local INVALID_CHARS = {}
INVALID_CHARS[string.byte("'")] = true
INVALID_CHARS[string.byte('"')] = true
INVALID_CHARS[string.byte('=')] = true
INVALID_CHARS[string.byte('$')] = true
INVALID_CHARS[string.byte('(')] = true
INVALID_CHARS[string.byte('[')] = true
INVALID_CHARS[string.byte(' ')] = true
INVALID_CHARS[string.byte('\t')] = true
INVALID_CHARS[string.byte('\n')] = true
INVALID_CHARS[string.byte('\r')] = true

local PAIR_CHARS = {}
PAIR_CHARS[string.byte('[')] = string.byte(']')
PAIR_CHARS[string.byte('(')] = string.byte(')')
PAIR_CHARS[string.byte('<')] = string.byte('>')

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

---Remove suffix
---@param text string
---@param suffix string
---@return string
str.remove_suffix = function(text, suffix)
  if #text < #suffix then
    return text
  end

  local i = 0
  while i < #suffix do
    if string.byte(text, #text - i) ~= string.byte(suffix, #suffix - i) then
      return text
    end
    i = i + 1
  end
  return string.sub(text, 1, -#suffix - 1)
end

---strikethrough
---@param text string
---@return string
str.strikethrough = function(text)
  local r = pattern.regex('.')
  local buffer = ''
  while text ~= '' do
    local s, e = r:match_str(text)
    if not s then
      break
    end
    buffer = buffer .. string.sub(text, s, e) .. '̶'
    text = string.sub(text, e + 1)
  end
  return buffer
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
str.get_word = function(text, stop_char)
  local valids = {}
  local has_valid = false
  for idx = 1, #text do
    local c = string.byte(text, idx)
    local invalid = INVALID_CHARS[c] and not (valids[c] and stop_char ~= c)
    if has_valid and invalid then
      return string.sub(text, 1, idx - 1)
    end
    valids[c] = true
    if PAIR_CHARS[c] then
      valids[PAIR_CHARS[c]] = true
    end
    has_valid = has_valid or not invalid
  end
  return text
end

---Get character length.
---@param text string
---@param s number
---@param e number
---@return number
str.chars = function(text, s, e)
  return vim.fn.strchars(string.sub(text, s, e))
end

---Oneline
---@param text string
---@return string
str.oneline = function(text)
  for i = 1, #text do
    if string.byte(text, i) == string.byte('\n', 1) then
      return string.sub(text, 1, i - 1)
    end
  end
  return text
end

---Escape special chars
---@param text string
---@param chars string[]
---@return string
str.escape = function(text, chars)
  table.insert(chars, '\\')
  local escaped = {}
  local i = 1
  while i <= #text do
    local c = string.sub(text, i, i)
    if vim.tbl_contains(chars, c) then
      table.insert(escaped, '\\')
      table.insert(escaped, c)
    else
      table.insert(escaped, c)
    end
    i = i + 1
  end
  return table.concat(escaped, '')
end

return str
