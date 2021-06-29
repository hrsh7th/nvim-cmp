local binary = {}

---Insert item to list to suitable index
---@param list any[]
---@param item any
---@param func fun(a: any, b: any): "1"|"-1"|"0"
binary.insert = function(list, item, func)
  table.insert(list, binary.search(list, item, func), item)
end

---Search suitable index from list
---@param list any[]
---@param item any
---@param func fun(a: any, b: any): "1"|"-1"|"0"
---@return number
binary.search = function(list, item, func)
  local s = 1
  local e = #list
  while s <= e do
    local idx = math.floor((e + s) / 2)
    local cmp = func(item, list[idx])
    if cmp > 0 then
      s = idx + 1
    elseif cmp < 0 then
      e = idx - 1
    else
      return idx + 1
    end
  end
  return s
end

return binary

