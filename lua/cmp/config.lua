local cache = require('cmp.utils.cache')
local misc = require('cmp.utils.misc')
local api = require('cmp.utils.api')

---@class cmp.Config
---@field public g cmp.ConfigSchema
local config = {}

---@type cmp.Cache
config.cache = cache.new()

---@type cmp.ConfigSchema
config.global = require('cmp.config.default')()

---@type table<number, cmp.ConfigSchema>
config.buffers = {}

---@type table<string, cmp.ConfigSchema>
config.cmdline = {}

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

---Set configuration for cmdline
config.set_cmdline = function(c, type)
  local revision = (config.cmdline[type] or {}).revision or 1
  config.cmdline[type] = c
  config.cmdline[type].revision = revision + 1
end

---@return cmp.ConfigSchema
config.get = function()
  local global = config.global
  if api.is_cmdline_mode() then
    local type = vim.fn.getcmdtype()
    local cmdline = config.cmdline[type] or { revision = 1, sources = {} }
    return config.cache:ensure({ 'get_cmdline', type, global.revision or 0, cmdline.revision or 0 }, function()
      return misc.merge(cmdline, global)
    end)
  else
    local bufnr = vim.api.nvim_get_current_buf()
    local buffer = config.buffers[bufnr] or { revision = 1 }
    return config.cache:ensure({ 'get_buffer', bufnr, global.revision or 0, buffer.revision or 0 }, function()
      return misc.merge(buffer, global)
    end)
  end
end

---Return cmp is enabled or not.
config.enabled = function()
  local enabled = config.get().enabled
  if type(enabled) == 'function' then
    enabled = enabled()
  end
  return enabled and api.is_suitable_mode()
end

---Return source config
---@param name string
---@return cmp.SourceConfig
config.get_source_config = function(name)
  local bufnr = vim.api.nvim_get_current_buf()
  local global = config.global
  local buffer = config.buffers[bufnr] or { revision = 1 }
  return config.cache:ensure({ 'get_source_config', bufnr, global.revision or 0, buffer.revision or 0, name }, function()
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
