local debug = require('cmp.utils.debug')
local async = require('cmp.utils.async')
local keymap = require('cmp.keymap')
local float = require('cmp.float')
local types = require('cmp.types')
local config = require('cmp.config')

---@class cmp.Menu
---@field public float cmp.Float
---@field public cache cmp.Cache
---@field public offset number
---@field public items vim.CompletedItem[]
---@field public entries cmp.Entry[]
---@field public selected_entry cmp.Entry|nil
---@field public context cmp.Context
---@field public resolve_dedup fun(callback: function)
local menu = {}

---Create menu
---@return cmp.Menu
menu.new = function()
  local self = setmetatable({}, { __index = menu })
  self.float = float.new()
  self.resolve_dedup = async.dedup()
  self:reset()
  return self
end

---Close menu
menu.close = function(self)
  if vim.fn.pumvisible() == 1 then
    vim.fn.complete(1, {})
  end
  self:unselect()
end

---Reset menu
menu.reset = function(self)
  self.offset = nil
  self.items = {}
  self.entries = {}
  self.context = nil
  self.preselect = 0
  self:close()
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
        local priority = 5 * (#sources - i)

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
  config.get().sorting.sort(entries)

  -- create vim items.
  local items = {}
  local abbrs = {}
  local preselect = 0
  for i, e in ipairs(entries) do
    if preselect == 0 and e.completion_item.preselect then
      preselect = i
    end

    local item = e:get_vim_item(offset)
    if not abbrs[item.abbr] then
      table.insert(items, item)
      abbrs[item.abbr] = true
    end
  end

  -- save recent pum state.
  self.offset = offset
  self.items = items
  self.entries = entries
  self.preselect = preselect
  self.context = ctx
  self:show()

  if #self.entries == 0 then
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
        self:show()
      end
    end
  end
end

---Show completion item
menu.show = function(self)
  if vim.fn.pumvisible() == 0 and #self.entries == 0 then
    return
  end

  local completeopt = vim.o.completeopt
  if self.preselect == 1 then
    vim.cmd('set completeopt=menuone,noinsert')
  else
    vim.cmd('set completeopt=' .. config.get().completion.completeopt)
  end
  vim.fn.complete(self.offset, self.items)
  vim.cmd('set completeopt=' .. completeopt)

  if self.preselect > 0 then
    vim.api.nvim_select_popupmenu_item(self.preselect - 1, false, false, {})
  end
end

---Select current item
---@param e cmp.Entry
menu.select = function(self, e)
  -- Documentation (always invoke to follow to the pum position)
  e:resolve(self.resolve_dedup(vim.schedule_wrap(function()
    self.float:show(e)
  end)))

  -- Avoid duplicate handling
  if self.selected_entry == e then
    return
  end
  self.selected_entry = e

  -- Add commit character listeners.
  for _, key in ipairs(e:get_commit_characters()) do
    keymap.register(key)
  end
end

---Select current item
menu.unselect = function(self)
  if self.selected_entry then
    self.selected_entry = nil
    self.float:close()
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

---Get first entry
---@param self cmp.Entry|nil
menu.get_first_entry = function(self)
  local info = vim.fn.complete_info({ 'items' })
  local completed_item = info.items[1] or {}
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
