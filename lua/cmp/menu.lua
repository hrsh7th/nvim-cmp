local debug = require('cmp.utils.debug')
local keymap = require('cmp.utils.keymap')
local float = require('cmp.float')
local cache = require('cmp.utils.cache')
local lsp = require('cmp.types.lsp')
local config = require('cmp.config')

---@class cmp.Menu
---@field public on_commit_character fun(c: string, fallback: function)
---@field public float cmp.Float
---@field public cache cmp.Cache
---@field public offset number
---@field public items vim.CompletedItem[]
---@field public entries cmp.Entry[]
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
      if s.trigger_kind == lsp.CompletionTriggerKind.TriggerCharacter then
        has_triggered_by_character_source = true
        break
      end
    end
  end

  -- create filtered entries.
  local offset = ctx.offset
  for i, s in ipairs(sources) do
    if s:has_items() then
      if not has_triggered_by_character_source or s.trigger_kind == lsp.CompletionTriggerKind.TriggerCharacter then
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
  table.sort(entries, config.get().compare)

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

  -- save recent pum state.
  self.offset = offset
  self.items = items
  self.entries = entries
  self.context = ctx

  if vim.fn.pumvisible() == 0 and #items == 0 then
    debug.log('menu/not-show')
  else
    debug.log('menu/show', offset, #self.items)
    vim.fn.complete(offset, self.items)
  end
  self:select(ctx)
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
        vim.fn.complete(self.offset, self.items)
      end
    end
  end
end

---Select current item
---@param ctx cmp.Context
menu.select = function(self, ctx)
  local e = self:get_selected_entry()
  if not e then
    self:unselect()
    return
  end

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
  for _, key in ipairs(e:get_commit_characters()) do
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
