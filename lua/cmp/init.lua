local core = require('cmp.core')
local source = require('cmp.source')
local config = require('cmp.config')
local autocmd = require('cmp.autocmd')

local cmp = {}

---Expose types
for k, v in pairs(require('cmp.types.cmp')) do
  cmp[k] = v
end
cmp.lsp = require('cmp.types.lsp')
cmp.vim = require('cmp.types.vim')

---Export mapping
cmp.mapping = require('cmp.mapping')

---Register completion sources
---@param name string
---@param s cmp.Source
---@return number
cmp.register_source = function(name, s)
  local src = source.new(name, s)
  core.register_source(src)
  return src.id
end

---Unregister completion source
---@param id number
cmp.unregister_source = function(id)
  core.unregister_source(id)
end

---@type cmp.Setup
cmp.setup = setmetatable({
  global = function(c)
    config.set_global(c)
  end,
  buffer = function(c)
    config.set_buffer(c, vim.api.nvim_get_current_buf())
  end,
}, {
  __call = function(self, c)
    self.global(c)
  end,
})

---Handle events
autocmd.subscribe('InsertEnter', function()
  core.prepare()
  core.on_change('InsertEnter')
end)

autocmd.subscribe('TextChanged', function()
  core.on_change('TextChanged')
end)

autocmd.subscribe('InsertLeave', function()
  core.reset()
end)

return cmp
