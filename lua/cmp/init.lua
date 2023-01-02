local core = require('cmp.core')
local source = require('cmp.source')
local config = require('cmp.config')
local autocmd = require('cmp.utils.autocmd')
local keymap = require('cmp.utils.keymap')
local misc = require('cmp.utils.misc')
local async = require('cmp.utils.async')
local Keymap = require('cmp.kit.Vim.Keymap')
local AsyncTask = require('cmp.kit.Async.AsyncTask')

local cmp = {}

cmp.core = core.new()

---Expose types
for k, v in pairs(require('cmp.types.cmp')) do
  cmp[k] = v
end
cmp.lsp = require('cmp.types.lsp')
cmp.vim = require('cmp.types.vim')

---Expose event
cmp.event = cmp.core.event

---Export mapping for special case
cmp.mapping = require('cmp.config.mapping')

---Export default config presets
cmp.config = {}
cmp.config.disable = misc.none
cmp.config.compare = require('cmp.config.compare')
cmp.config.sources = require('cmp.config.sources')
cmp.config.mapping = require('cmp.config.mapping')
cmp.config.window = require('cmp.config.window')

---Sync waiting filter process.
---@generic T: fun(...: any[]): any
---@param callback T
---@return T
cmp.sync = function(callback)
  return function(...)
    cmp.core.filter:sync(1000)
    if callback then
      return callback(...)
    end
  end
end

---Suspend completion.
---@return fun()
cmp.suspend = function()
  return cmp.core:suspend()
end

---Register completion sources
---@param name string
---@param s cmp.CustomSource
---@return integer
cmp.register_source = function(name, s)
  local src = source.new(name, s)
  cmp.core:register_source(src)
  return src.id
end

---Unregister completion source
---@param id integer
cmp.unregister_source = function(id)
  cmp.core:unregister_source(id)
end

---Get current configuration.
---@return cmp.ConfigSchema
cmp.get_config = function()
  return require('cmp.config').get()
end

---Invoke completion manually
---@param option cmp.CompleteParams
cmp.complete = cmp.sync(function(option)
  option = option or {}
  config.set_onetime(option.config)
  cmp.core:complete(cmp.core:get_context({ reason = option.reason or cmp.ContextReason.Manual }))
end)

---Complete common string in current entries.
---@return cmp.kit.Async.AsyncTask boolean
cmp.complete_common_string = cmp.sync(function()
  return cmp.core:complete_common_string()
end)

---Return view is visible or not.
---@return boolean
cmp.visible = cmp.sync(function()
  return cmp.core.view:visible() or vim.fn.pumvisible() == 1
end)

---Get current selected entry or nil
---@return cmp.Entry?
cmp.get_selected_entry = cmp.sync(function()
  return cmp.core.view:get_selected_entry()
end)

---Get current active entry or nil
---@return cmp.Entry?
cmp.get_active_entry = cmp.sync(function()
  return cmp.core.view:get_active_entry()
end)

---Get current all entries
---@return cmp.Entry[]
cmp.get_entries = cmp.sync(function()
  return cmp.core.view:get_entries()
end)

---Close current completion
---@return cmp.kit.Async.AsyncTask
cmp.close = cmp.sync(function()
  return AsyncTask.resolve():next(function()
    if cmp.core.view:visible() then
      return cmp.core.view:close()
    end
  end)
end)

---Abort current completion
---@return cmp.kit.Async.AsyncTask
cmp.abort = cmp.sync(function()
  return AsyncTask.resolve():next(function()
    if cmp.core.view:visible() then
      return cmp.core.view:abort():next(cmp.core:suspend())
    end
  end)
end)

---Select next item if possible
---@param option? cmp.SelectOption
---@return cmp.kit.Async.AsyncTask
cmp.select_next_item = cmp.sync(function(option)
  option = option or {}
  option.behavior = option.behavior or cmp.SelectBehavior.Insert
  option.count = option.count or 1

  return AsyncTask.resolve():next(function()
    if cmp.core.view:visible() then
      return cmp.core.view:select_next_item(option):next(cmp.core:suspend())
    elseif vim.fn.pumvisible() == 1 then
      if option.behavior == cmp.SelectBehavior.Insert then
        return Keymap.send(keymap.t(string.rep('<C-n>', option.count)), 'in')
      else
        return Keymap.send(keymap.t(string.rep('<Down>', option.count)), 'in')
      end
    end
  end)
end)

---Select prev item if possible
---@param option? cmp.SelectOption
---@return cmp.kit.Async.AsyncTask
cmp.select_prev_item = cmp.sync(function(option)
  option = option or {}
  option.behavior = option.behavior or cmp.SelectBehavior.Insert
  option.count = option.count or 1

  return AsyncTask.resolve():next(function()
    if cmp.core.view:visible() then
      return cmp.core.view:select_prev_item(option):next(cmp.core:suspend())
    elseif vim.fn.pumvisible() == 1 then
      if option.behavior == cmp.SelectBehavior.Insert then
        return Keymap.send(keymap.t(string.rep('<C-p>', option.count)), 'in')
      else
        return Keymap.send(keymap.t(string.rep('<Up>', option.count)), 'in')
      end
    end
  end)
end)

---Scrolling documentation window if possible
---@param delta integer
cmp.scroll_docs = cmp.sync(function(delta)
  if cmp.core.view.docs_view:visible() then
    cmp.core.view:scroll_docs(delta)
  end
end)

---Confirm completion
---@param option? cmp.ConfirmOption
---@return cmp.kit.Async.AsyncTask boolean
cmp.confirm = cmp.sync(function(option)
  option = option or {}
  option.select = option.select or false
  option.behavior = option.behavior or cmp.get_config().confirmation.default_behavior or cmp.ConfirmBehavior.Insert

  return AsyncTask.resolve():next(function()
    if cmp.core.view:visible() then
      local e = cmp.core.view:get_selected_entry()
      if not e and option.select then
        e = cmp.core.view:get_first_entry()
      end
      if e then
        return cmp.core:confirm(e, {
          behavior = option.behavior,
        }):next(function()
          cmp.core:complete(cmp.core:get_context({ reason = cmp.ContextReason.TriggerOnly }))
        end)
      end
    elseif vim.fn.pumvisible() == 1 then
      local index = vim.fn.complete_info({ 'selected' }).selected
      if index == -1 and option.select then
        index = 0
      end
      if index ~= -1 then
        vim.api.nvim_select_popupmenu_item(index, true, true, {})
      end
    end
  end)
end)

---Show status
cmp.status = function()
  local kinds = {}
  kinds.available = {}
  kinds.unavailable = {}
  kinds.installed = {}
  kinds.invalid = {}
  local names = {}
  for _, s in pairs(cmp.core.sources) do
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
  ---@param c cmp.ConfigSchema
  global = function(c)
    config.set_global(c)
  end,
  ---@param filetype string
  ---@param c cmp.ConfigSchema
  filetype = function(filetype, c)
    config.set_filetype(c, filetype)
  end,
  ---@param c cmp.ConfigSchema
  buffer = function(c)
    config.set_buffer(c, vim.api.nvim_get_current_buf())
  end,
  ---@param type ':'|'/'|'?'
  ---@param c cmp.ConfigSchema
  cmdline = function(type, c)
    config.set_cmdline(c, type)
  end,
}, {
  ---@param self unknown
  ---@param c cmp.ConfigSchema
  __call = function(self, c)
    self.global(c)
  end,
})

local on_insert_enter = function()
  if config.enabled() then
    cmp.config.compare.scopes:update()
    cmp.config.compare.locality:update()
    cmp.core:prepare()
    cmp.core:on_change('InsertEnter')
  end
end
autocmd.subscribe({ 'InsertEnter' }, async.debounce_next_tick_by_keymap(on_insert_enter)) -- Debouncing is needed to solve InsertEnter's mode problem.
autocmd.subscribe({ 'CmdlineEnter' }, on_insert_enter)

local on_text_changed = function()
  if config.enabled() then
    cmp.core:on_change('TextChanged')
  end
end
autocmd.subscribe({ 'TextChangedI', 'TextChangedP' }, on_text_changed)
-- async.debounce_next_tick is needed for performance. The mapping `:<C-u>...<CR>` will fire `CmdlineChanged` for each character.
-- I don't know why but 'We can't use `async.debounce_next_tick_by_keymap` here.
autocmd.subscribe('CmdlineChanged', async.debounce_next_tick(on_text_changed))

autocmd.subscribe('CursorMovedI', function()
  if config.enabled() then
    cmp.core:on_moved()
  else
    cmp.core:reset()
    cmp.core.view:close()
  end
end)

-- The follwoing autocmds must not be debounced.
-- If make this asynchronous, the completion menu will not close when the command output is displayed.
autocmd.subscribe({ 'InsertLeave', 'CmdlineLeave' }, function()
  cmp.core:reset()
  cmp.core.view:close()
end)

cmp.event:on('complete_done', function(evt)
  if evt.entry then
    cmp.config.compare.recently_used:add_entry(evt.entry)
  end
  cmp.config.compare.scopes:update()
  cmp.config.compare.locality:update()
end)

cmp.event:on('confirm_done', function(evt)
  if evt.entry then
    cmp.config.compare.recently_used:add_entry(evt.entry)
  end
end)

return cmp
