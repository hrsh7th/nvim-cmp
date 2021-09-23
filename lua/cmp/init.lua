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

---Export default config presets.
cmp.config = {}
cmp.config.compare = require('cmp.config.compare')

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
    keymap.feedkeys(keymap.t('<C-e>'), 'n')
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

---Show status
cmp.status = function()
  vim.cmd([[doautocmd InsertEnter]])

  local kinds = {}
  kinds.available = {}
  kinds.unavailable = {}
  kinds.installed = {}
  kinds.invalid = {}
  local names = {}
  for _, s in pairs(core.sources) do
    names[s.name] = true

    if config.get_source_config(s.name) then
      if s:is_available() then
        table.insert(kinds.available, s:get_debug_name())
      else
        table.insert(kinds.unavailable, s:get_debug_name())
      end
    else
      table.insert(kinds.installed, s:get_debug_name())
    end
  end
  for _, s in ipairs(config.get().sources) do
    if not names[s.name] then
      table.insert(kinds.invalid, s.name)
    end
  end

  if #kinds.available > 0 then
    vim.api.nvim_echo({ { '\n', 'Normal' } }, false, {})
    vim.api.nvim_echo({ { '# ready source names\n', 'Special' } }, false, {})
    for _, name in ipairs(kinds.available) do
      vim.api.nvim_echo({ { ('- %s\n'):format(name), 'Normal' } }, false, {})
    end
  end

  if #kinds.unavailable > 0 then
    vim.api.nvim_echo({ { '\n', 'Normal' } }, false, {})
    vim.api.nvim_echo({ { '# unavailable source names\n', 'Comment' } }, false, {})
    for _, name in ipairs(kinds.unavailable) do
      vim.api.nvim_echo({ { ('- %s\n'):format(name), 'Normal' } }, false, {})
    end
  end

  if #kinds.installed > 0 then
    vim.api.nvim_echo({ { '\n', 'Normal' } }, false, {})
    vim.api.nvim_echo({ { '# unused source names\n', 'WarningMsg' } }, false, {})
    for _, name in ipairs(kinds.installed) do
      vim.api.nvim_echo({ { ('- %s\n'):format(name), 'Normal' } }, false, {})
    end
  end

  if #kinds.invalid > 0 then
    vim.api.nvim_echo({ { '\n', 'Normal' } }, false, {})
    vim.api.nvim_echo({ { '# unknown source names\n', 'ErrorMsg' } }, false, {})
    for _, name in ipairs(kinds.invalid) do
      vim.api.nvim_echo({ { ('- %s\n'):format(name), 'Normal' } }, false, {})
    end
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
  -- Avoid unexpected mode detection (mode() function will returns `normal mode` on the InsertEnter event.)
  vim.schedule(function()
    if config.enabled() then
      core.prepare()
      core.on_change('InsertEnter')
    end
  end)
end)

autocmd.subscribe('TextChanged', function()
  if config.enabled() then
    core.on_change('TextChanged')
  end
end)

autocmd.subscribe('InsertLeave', function()
  core.reset()
end)

return cmp
