local debug = require('cmp.utils.debug')
local keymap = require('cmp.utils.keymap')
local float = require('cmp.float')
local cache = require('cmp.utils.cache')
local types = require('cmp.types')
local config = require('cmp.config')

---@class cmp.Menu
---@field public on_commit_character fun(c: string, fallback: function)
---@field public float cmp.Float
---@field public cache cmp.Cache
---@field public offset number
---@field public items vim.CompletedItem[]
---@field public entries cmp.Entry[]
---@field public preselect boolean
---@field public selected_entry cmp.Entry|nil
---@field public context cmp.Context
local menu = {}

---Create menu
---@param on_commit_character fun(c: string, fallback: function)
---@return cmp.Menu
menu.new = function(on_commit_character)
  local self = setmetatable({}, { __index = menu })
  self.on_commit_character = on_commit_character
  self.float = float.new()
  self.cache = cache.new()
  self:reset()
  return self
end

---Reset menu
menu.reset = function(self)
  self.offset = nil
  self.items = {}
  self.entries = {}
  self.context = nil
  if vim.tbl_contains({ 'i', 'ic' }, vim.api.nvim_get_mode().mode) then
    vim.fn.complete(1, {})
  end
  self:unselect()
end

---Update menu
---@param ctx cmp.Context
---@param sources cmp.Source[]
---@return cmp.Menu
menu.update = function(self, ctx, sources)
  if not (ctx.mode == 'i' or ctx.mode == 'ic') then
    return
  end

  local entries = {}

  -- check the source triggered by character
  local has_triggered_by_character_source = false
  for _, s in ipairs(sources) do
    if s:has_items() then
      if s.trigger_kind == types.lsp.CompletionTriggerKind.TriggerCharacter then
        has_triggered_by_character_source = true
        break
      end
    end
  end

  -- create filtered entries.
  local offset = ctx.offset
  for i, s in ipairs(sources) do
    if s:has_items() and s.offset <= offset then
      if not has_triggered_by_character_source or s.trigger_kind == types.lsp.CompletionTriggerKind.TriggerCharacter then
        -- source order priority bonus.
        local priority = 10 * (#sources - i)

        local filtered = s:get_entries(ctx)
        for _, e in ipairs(filtered) do
          e.score = e.score + priority
          table.insert(entries, e)
        end
        if #filtered > 0 then
          offset = math.min(offset, s.offset)
        end
      end
    end
  end

  -- sort.
  config.get().menu.sort(entries)

  -- create vim items.
  local items = {}
  local abbrs = {}
  for _, e in ipairs(entries) do
    local item = e:get_vim_item(offset)
    if not abbrs[item.abbr] then
      table.insert(items, item)
      abbrs[item.abbr] = true
    end
  end

  -- preselect.
  local preselect = false
  preselect = preselect or self.entries[1] and self.entries[1].completion_item.preselect
  preselect = preselect or config.get().preselect.mode == types.cmp.PreselectMode.Always

  -- save recent pum state.
  self.offset = offset
  self.items = items
  self.entries = entries
  self.context = ctx
  self.preselect = preselect

  if vim.fn.pumvisible() == 0 and #items == 0 then
    debug.log('menu/not-show')
  else
    debug.log('menu/show', offset, #self.items)

    local completeopt = vim.o.completeopt
    if self.preselect then
      vim.cmd('set completeopt=menuone,noinsert')
    else
      vim.cmd('set completeopt=menuone,noselect')
    end
    vim.fn.complete(offset, self.items)
    vim.cmd('set completeopt=' .. completeopt)
  end
  if #self.entries > 0 then
    self:select(self.entries[1])
  else
    self:unselect()
  end
end

---Restore previous menu
---@param ctx cmp.Context
menu.restore = function(self, ctx)
  if not (ctx.mode == 'i' or ctx.mode == 'ic') then
    return
  end

  if not ctx.pumvisible then
    if #self.items > 0 then
      if self.offset <= ctx.cursor.col then
        debug.log('menu/restore')
        local completeopt = vim.o.completeopt
        if self.preselect then
          vim.cmd('set completeopt=menuone,noinsert')
        else
          vim.cmd('set completeopt=menuone,noselect')
        end
        vim.fn.complete(self.offset, self.items)
        vim.cmd('set completeopt=' .. completeopt)
      end
    end
  end
end

---Select current item
---@param e cmp.Entry
menu.select = function(self, e)
  -- Documentation (always invoke to follow to the pum position)
  self.cache:ensure({ 'select', self.context.id }, function()
    e:resolve(vim.schedule_wrap(function()
      self.float:show(e)
    end))
  end)

  -- Avoid duplicate handling
  if self.selected_entry == e then
    return
  end
  self.selected_entry = e

  -- Add commit character listeners.
  for _, key in ipairs(config.get().commit_characters.resolve(e)) do
    keymap.listen(
      key,
      (function(k)
        return function(fallback)
          return self.on_commit_character(k, fallback)
        end
      end)(key)
    )
  end
end

---Select current item
menu.unselect = function(self)
  if self.selected_entry then
    self.selected_entry = nil
    vim.schedule(function()
      self.float:close()
    end)
    return
  end
end

---Geta current active entry
---@return cmp.Entry|nil
menu.get_active_entry = function(self)
  local completed_item = vim.v.completed_item or {}
  if vim.fn.pumvisible() == 0 or not completed_item.user_data then
    return nil
  end

  local id = completed_item.user_data.cmp
  for _, e in ipairs(self.entries) do
    if e.id == id then
      return e
    end
  end
  return nil
end

---Get current selected entry
---@return cmp.Entry|nil
menu.get_selected_entry = function(self)
  local info = vim.fn.complete_info({ 'items', 'selected' })
  if info.selected == -1 then
    return nil
  end

  local completed_item = info.items[math.max(info.selected, 0) + 1] or {}
  if not completed_item.user_data then
    return nil
  end

  local id = completed_item.user_data.cmp
  for _, e in ipairs(self.entries) do
    if e.id == id then
      return e
    end
  end
  return nil
end

return menu
