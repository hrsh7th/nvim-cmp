local _

local alpha = {}
_ = string.gsub('abcdefghijklmnopqrstuvwxyz', '.', function(char)
  alpha[string.byte(char)] = true
end)

local ALPHA = {}
_ = string.gsub('ABCDEFGHIJKLMNOPQRSTUVWXYZ', '.', function(char)
  ALPHA[string.byte(char)] = true
end)

local digit = {}
_ = string.gsub('1234567890', '.', function(char)
  digit[string.byte(char)] = true
end)

local white = {}
_ = string.gsub(' \t\n', '.', function(char)
  white[string.byte(char)] = true
end)

local char = {}

---@param byte integer
---@return boolean
char.is_upper = function(byte)
  return ALPHA[byte]
end

---@param byte integer
---@return boolean
char.is_alpha = function(byte)
  return alpha[byte] or ALPHA[byte]
end

---@param byte integer
---@return boolean
char.is_digit = function(byte)
  return digit[byte]
end

---@param byte integer
---@return boolean
char.is_white = function(byte)
  return white[byte]
end

---@param byte integer
---@return boolean
char.is_symbol = function(byte)
  return not (char.is_alnum(byte) or char.is_white(byte))
end

---@param byte integer
---@return boolean
char.is_printable = function(byte)
  return string.match(string.char(byte), '^%c$') == nil
end

---@param byte integer
---@return boolean
char.is_alnum = function(byte)
  return char.is_alpha(byte) or char.is_digit(byte)
end

---@param text string
---@param index integer
---@return boolean
char.is_semantic_index = function(text, index)
  if index <= 1 then
    return true
  end

  local prev, curr = string.byte(text, index - 1, index)

  if not ALPHA[prev] and ALPHA[curr] then
    return true
  end
  -- symbol or white == not alnum
  if not (alpha[curr] or ALPHA[curr] or digit[curr]) then
    return true
  end
  if not (alpha[prev] or ALPHA[prev]) and (alpha[curr] or ALPHA[curr]) then
    return true
  end
  if not digit[prev] and digit[curr] then
    return true
  end
  return false
end

---@param text string
---@param current_index integer
---@return integer
char.get_next_semantic_index = function(text, current_index)
  for i = current_index + 1, #text do
    if char.is_semantic_index(text, i) then
      return i
    end
  end
  return #text + 1
end

-- byte -> lowercased byte (identity for non A-Z).
local LOWER = {}
for b = 0, 255 do
  LOWER[b] = ALPHA[b] and (b + 32) or b
end

---Ignore case match
---@param byte1 integer
---@param byte2 integer
---@return boolean
char.match = function(byte1, byte2)
  return LOWER[byte1] == LOWER[byte2]
end

return char
