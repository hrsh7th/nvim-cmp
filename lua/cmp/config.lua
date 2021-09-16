local cache = require('cmp.utils.cache')
local misc = require('cmp.utils.misc')

---@class cmp.Config
---@field public g cmp.ConfigSchema
local config = {}

---@type cmp.Cache
config.cache = cache.new()

---@type cmp.ConfigSchema
config.global = require('cmp.config.default')()

---@type table<number, cmp.ConfigSchema>
config.buffers = {}

---Set configuration for global.
---@param c cmp.ConfigSchema
config.set_global = function(c)
  config.global = misc.merge(c, config.global)
  config.global.revision = config.global.revision or 1
  config.global.revision = config.global.revision + 1
end

---Set configuration for buffer
---@param c cmp.ConfigSchema
---@param bufnr number|nil
config.set_buffer = function(c, bufnr)
  local revision = (config.buffers[bufnr] or {}).revision or 1
  config.buffers[bufnr] = c
  config.buffers[bufnr].revision = revision + 1
end

---@return cmp.ConfigSchema
config.get = function()
  local global = config.global
  local buffer = config.buffers[vim.api.nvim_get_current_buf()] or { revision = 1 }
  return config.cache:ensure({ 'get', global.revision or 0, buffer.revision or 0 }, function()
    return misc.merge(buffer, global)
  end)
end

---Return cmp is enabled or not.
config.enabled = function()
  local enabled = config.get().enabled
  if type(enabled) == 'function' then
    enabled = enabled()
  end
  return enabled and string.sub(vim.api.nvim_get_mode().mode, 1, 1) == 'i'
end

---Return source config
---@param name string
---@return cmp.SourceConfig
config.get_source_config = function(name)
  local global = config.global
  local buffer = config.buffers[vim.api.nvim_get_current_buf()] or { revision = 1 }
  return config.cache:ensure({ 'get_source_config', global.revision or 0, buffer.revision or 0, name }, function()
    local c = config.get()
    for _, s in ipairs(c.sources) do
      if s.name == name then
        if type(s.opts) ~= 'table' then
          s.opts = {}
        end
        return s
      end
    end
    return nil
  end)
end

return config
