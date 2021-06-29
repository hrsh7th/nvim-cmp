local global = {}

---Register function to name
---@param name string
---@param callback fun()
global.set = function(name, callback)
  local keys = vim.split(name, '.', true)

  local curr = _G
  for i = 1, #keys - 1 do
    local key = keys[i]
    curr[key] = curr[key] or {}
    curr = curr[key]
  end
  curr[keys[#keys]] = callback
end

return global
