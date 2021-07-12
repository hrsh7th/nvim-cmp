local core = require('cmp.core')
local source = require('cmp.source')
local config = require('cmp.config')
local debug = require('cmp.utils.debug')

local cmp = {}

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

---Receive vim autocmds
---@param name string
cmp._on_event = function(name)
  debug.log('')
  debug.log('----------------------------------------------------------------------------------------------------')
  if vim.fn.getchar(1) ~= 0 then
    debug.log('ignore', name)
    return
  else
    debug.log('adopt', name)
  end
  if name == 'InsertEnter' then
    core.autocomplete()
  elseif name == 'TextChanged' then
    core.autocomplete()
  elseif name == 'CompleteChanged' then
    core.select()
  elseif name == 'InsertLeave' then
    core.reset()
  end
end

---Internal expand snippet function.
---TODO: It should be removed when we remove `autoload/cmp.vim`.
---@param args cmp.SnippetExpansionParams
cmp._expand_snippet = function(args)
  return config.get().snippet.expand(args)
end

return cmp
