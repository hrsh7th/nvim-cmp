local core = require('cmp.core')
local keymap = require('cmp.utils.keymap')
local source = require('cmp.source')
local config = require('cmp.config')
local autocmd = require('cmp.utils.autocmd')

local cmp = {}

---Expose types
for k, v in pairs(require('cmp.types.cmp')) do
  cmp[k] = v
end
cmp.lsp = require('cmp.types.lsp')
cmp.vim = require('cmp.types.vim')

---Export mapping
cmp.mapping = require('cmp.config.mapping')

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

---Invoke completion manually
cmp.complete = function()
  core.complete(core.get_context({ reason = cmp.ContextReason.Manual }))
  return true
end

---Close current completion
cmp.close = function()
  if vim.fn.pumvisible() == 1 then
    core.reset()
    return true
  else
    return false
  end
end

---Abort current completion
cmp.abort = function()
  if vim.fn.pumvisible() == 1 then
    keymap.feedkeys(keymap.t('<C-e>'), 'n', function()
      core.reset()
    end)
    return true
  else
    return false
  end
end

---Select next item if possible
cmp.select_next_item = function()
  if vim.fn.pumvisible() == 1 then
    vim.api.nvim_feedkeys(keymap.t('<C-n>'), 'n', true)
    return true
  else
    return false
  end
end

---Select prev item if possible
cmp.select_prev_item = function()
  if vim.fn.pumvisible() == 1 then
    vim.api.nvim_feedkeys(keymap.t('<C-p>'), 'n', true)
    return true
  else
    return false
  end
end

---Scrolling documentation window if possible
cmp.scroll_docs = function(delta)
  if core.menu.float:is_visible() then
    core.menu.float:scroll(delta)
    return true
  else
    return false
  end
end

---Confirm completion
cmp.confirm = function(option)
  option = option or {}
  local e = core.menu:get_selected_entry() or (option.select and core.menu:get_first_entry() or nil)
  if e then
    core.confirm(e, {
      behavior = option.behavior,
    }, function()
      core.complete(core.get_context({ reason = cmp.ContextReason.TriggerOnly }))
    end)
    return true
  else
    return false
  end
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
