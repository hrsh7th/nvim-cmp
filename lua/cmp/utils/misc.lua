local misc = {}

---Return concatenated list
---@param list1 any[]
---@param list2 any[]
---@return any[]
misc.concat = function(list1, list2)
  local new_list = {}
  for _, v in ipairs(list1) do
    table.insert(new_list, v)
  end
  for _, v in ipairs(list2) do
    table.insert(new_list, v)
  end
  return new_list
end

---Get cursor before line
---@return string
misc.get_cursor_before_line = function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return string.sub(vim.api.nvim_get_current_line(), 1, cursor[2])
end

---Return current mode is insert-mode or not.
---@return boolean
misc.is_suitable_mode = function()
  local mode = vim.api.nvim_get_mode().mode
  return vim.tbl_contains({
    'i',
    'ic',
    'ix',
  }, mode)
end

---Merge two non-list tables recursively
---@param overrides table
---@param base table
---@return table
local function merge_tables(overrides, base)
  local new = {}
  for k, v in pairs(base) do
    new[k] = v
  end
  for k, v in pairs(overrides) do
    new[k] = misc.merge(v, new[k])
  end
  return new
end

--- Checks if value is a table that is not array-like. Empty tables are assumed
--- to be an object, unlike vim.tbl_islist.
---
---@generic T
---@param value T
---@return boolean
local function is_object_table(value)
  return (type(value) == 'table' and (vim.tbl_isempty(value) or not vim.tbl_islist(value)))
end

--- Merge two values recursively.
---
--- Overriding with an empty table will return base value if base value is also
--- a table.
---
---@generic T
---@param override T
---@param base T
---@return T
misc.merge = function(override, base)
  -- Assume empty tables are not lists
  local override_is_obj = is_object_table(override)
  local base_is_obj = is_object_table(base)

  if override_is_obj and base_is_obj then
    return merge_tables(override, base)
  elseif type(base) == 'function' and override == false then
    return nil
  elseif override == nil then
    return base
  else
    return override
  end
end

---Generate id for group name
misc.id = setmetatable({
  group = {},
}, {
  __call = function(_, group)
    misc.id.group[group] = misc.id.group[group] or vim.loop.now()
    misc.id.group[group] = misc.id.group[group] + 1
    return misc.id.group[group]
  end,
})

---Check the value is nil or not.
---@param v boolean
---@return boolean
misc.safe = function(v)
  if v == nil or v == vim.NIL then
    return nil
  end
  return v
end

---Treat 1/0 as bool value
---@param v boolean|"1"|"0"
---@param def boolean
---@return boolean
misc.bool = function(v, def)
  if misc.safe(v) == nil then
    return def
  end
  return v == true or v == 1
end

---Set value to deep object
---@param t table
---@param keys string[]
---@param v any
misc.set = function(t, keys, v)
  local c = t
  for i = 1, #keys - 1 do
    local key = keys[i]
    c[key] = misc.safe(c[key]) or {}
    c = c[key]
  end
  c[keys[#keys]] = v
end

---Copy table
---@generic T
---@param tbl T
---@return T
misc.copy = function(tbl)
  if type(tbl) ~= 'table' then
    return tbl
  end

  if vim.tbl_islist(tbl) then
    local copy = {}
    for i, value in ipairs(tbl) do
      copy[i] = misc.copy(value)
    end
    return copy
  end

  local copy = {}
  for key, value in pairs(tbl) do
    copy[key] = misc.copy(value)
  end
  return copy
end

---Safe version of vim.str_utfindex
---@param text string
---@param vimindex number
---@return number
misc.to_utfindex = function(text, vimindex)
  return vim.str_utfindex(text, math.max(0, math.min(vimindex - 1, #text)))
end

---Safe version of vim.str_byteindex
---@param text string
---@param utfindex number
---@return number
misc.to_vimindex = function(text, utfindex)
  for i = utfindex, 1, -1 do
    local s, v = pcall(function()
      return vim.str_byteindex(text, i) + 1
    end)
    if s then
      return v
    end
  end
  return utfindex + 1
end

---Mark the function as deprecated
misc.deprecated = function(fn, msg)
  local printed = false
  return function(...)
    if not printed then
      print(msg)
      printed = true
    end
    return fn(...)
  end
end

return misc
