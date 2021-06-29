local misc = {}

---Merge list2's values to list1
---@param list1 any[]
---@param list2 any[]
---@return any[]
misc.merge = function(list1, list2)
  for _, v in ipairs(list2) do
    table.insert(list1, v)
  end
  return list1
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

return misc
