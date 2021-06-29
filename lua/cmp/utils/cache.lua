---@class cmp.utils.Cache
---@field public entries any
local cache = {}

cache.new = function()
  local self = setmetatable({}, { __index = cache })
  self.entries = {}
  return self
end

---Get cache value
---@param key string
---@return any|nil
cache.get = function(self, key)
  if self.entries[key] ~= nil then
    return self.entries[key]
  end
  return nil
end

---Set cache value explicitly
---@param key string
---@param value any
cache.set = function(self, key, value)
  self.entries[key] = value
end

---Ensure value by callback
---@param key string
---@param callback fun(): any
cache.ensure = function(self, key, callback)
  local value = self:get(key)
  if value == nil then
    self:set(key, callback())
  end
  return self:get(key)
end

return cache

