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


---Generate id for group name
misc.id = setmetatable({
  group = {}
}, {
  __call = function(_, group)
    misc.id.group[group] = misc.id.group[group] or 0
    misc.id.group[group] = misc.id.group[group] + 1
    return misc.id.group[group]
  end
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

return misc
