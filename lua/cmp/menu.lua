local debug = require('cmp.utils.debug')
local async = require('cmp.utils.async')
local float = require('cmp.float')
local types = require('cmp.types')
local config = require('cmp.config')
local autocmd = require('cmp.autocmd')

---@class cmp.Menu
---@field public float cmp.Float
---@field public cache cmp.Cache
---@field public offset number
---@field public on_select fun(e: cmp.Entry)
---@field public items vim.CompletedItem[]
---@field public entries cmp.Entry[]
---@field public entry_map table<number, cmp.Entry>
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
  self.on_select = function() end
  self:reset()
  autocmd.subscribe('CompleteChanged', function()
    local e = self:get_selected_entry()
    if e then
      self:select(e)
    else
      self:unselect()
    end
  end)
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
  self.entry_map = {}
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
  local entry_map = {}

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
  local offset = ctx.cursor.col
  for i, s in ipairs(sources) do
    if s:has_items() and s.offset <= offset then
      if not has_triggered_by_character_source or s.trigger_kind == types.lsp.CompletionTriggerKind.TriggerCharacter then
        -- source order priority bonus.
        local priority = (#sources - i - 1) * 2

        local filtered = s:get_entries(ctx)
        for _, e in ipairs(filtered) do
          e.score = e.score + priority
          table.insert(entries, e)
          entry_map[e.id] = e
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
    if not abbrs[item.abbr] or item.dup == 1 then
      table.insert(items, item)
      abbrs[item.abbr] = true
    end
  end

  -- save recent pum state.
  self.offset = offset
  self.items = items
  self.entries = entries
  self.entry_map = entry_map
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
    if self:get_selected_entry() == e then
      self.float:show(e)
    end
  end)))

  self.on_select(e)
end

---Select current item
menu.unselect = function(self)
  self.float:close()
end

---Geta current active entry
---@return cmp.Entry|nil
menu.get_active_entry = function(self)
  local completed_item = vim.v.completed_item or {}
  if vim.fn.pumvisible() == 0 or not completed_item.user_data then
    return nil
  end

  local id = completed_item.user_data.cmp
  if id then
    return self.entry_map[id]
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
  if id then
    return self.entry_map[id]
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
  if id then
    return self.entry_map[id]
  end
  return nil
end

return menu
