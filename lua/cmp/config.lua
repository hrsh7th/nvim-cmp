local cache = require('cmp.utils.cache')

---@class cmp.Config
---@field public g cmp.ConfigSchema
local config = {}

---@type cmp.Cache
config.cache = cache.new()

---@type cmp.ConfigSchema
config.global = require('cmp.config.global')

---@type table<number, cmp.ConfigSchema>
config.buffers = {}

---Set configuration for global.
---@param c cmp.ConfigSchema
config.set_global = function(c)
  for k, v in pairs(c) do
    config.global[k] = v
  end
  config.global.revision = config.global.revision or 1
  config.global.revision = config.global.revision + 1
end

---Set configuration for buffer
---@param c cmp.ConfigSchema
---@param bufnr number|nil
config.set_buffer = function(c, bufnr)
  config.buffers[bufnr] = c
  config.buffers[bufnr].revision = config.buffers[bufnr].revision or 1
  config.buffers[bufnr].revision = config.buffers[bufnr].revision + 1
end

---@return cmp.ConfigSchema
config.get = function()
  local global = config.global
  local buffer = config.buffers[vim.api.nvim_get_current_buf()] or { revision = 1 }
  return config.cache:ensure({ 'get', global.revision or 0, buffer.revision or 0 }, function()
    local c = {}
    for k, v in pairs(buffer) do
      c[k] = v
    end
    for k, v in pairs(global) do
      if c[k] == nil then
        c[k] = v
      end
    end
    return c
  end)
end

---Return source option
---@param name string
---@return table
config.get_source_option = function(name)
  local global = config.global
  local buffer = config.buffers[vim.api.nvim_get_current_buf()] or { revision = 1 }
  return config.cache:ensure({ 'get_source_config', global.revision or 0, buffer.revision or 0, name }, function()
    local c = config.get()
    for _, s in ipairs(c.sources) do
      if s.name == name then
        if type(s.opts) == "table" then
          return s.opts
        end
        return {}
      end
    end
    return nil
  end)
end

return config
