local debug = require('cmp.utils.debug')
local types = require('cmp.types')
local async = require('cmp.utils.async')
local float = require('cmp.float')
local config = require('cmp.config')
local autocmd = require('cmp.utils.autocmd')

---@class cmp.MenuOption
---@field on_select fun(e: cmp.Entry)

---@class cmp.Menu
---@field public float cmp.Float
---@field public cache cmp.Cache
---@field public offset number
---@field public on_select fun(e: cmp.Entry)
---@field public items vim.CompletedItem[]
---@field public entries cmp.Entry[]
---@field public deduped_entries cmp.Entry[]
---@field public selected_entry cmp.Entry|nil
---@field public context cmp.Context
---@field public resolve_dedup fun(callback: function)
local menu = {}

---Create menu
---@param opts cmp.MenuOption
---@return cmp.Menu
menu.new = function(opts)
  local self = setmetatable({}, { __index = menu })
  self.float = float.new()
  self.resolve_dedup = async.dedup()
  self.on_select = opts.on_select or function() end
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
  vim.schedule(function()
    debug.log('menu.close', vim.fn.pumvisible())
    if vim.fn.pumvisible() == 1 then
      -- TODO: Is it safe to call...?
      local line = vim.api.nvim_win_get_cursor(0)[1]
      vim.fn.complete(#vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1] + 1, {})
    end
    self:unselect()
  end)
end

---Reset menu
menu.reset = function(self)
  self.offset = nil
  self.items = {}
  self.entries = {}
  self.deduped_entries = {}
  self.context = nil
  self.preselect = 0
  self:close()
end

---Update menu
---@param ctx cmp.Context
---@param sources cmp.Source[]
---@return cmp.Menu
menu.update = function(self, ctx, sources)
  local entries = {}

  -- check the source triggered by character
  local has_triggered_by_symbol_source = false
  for _, s in ipairs(sources) do
    if #s:get_entries(ctx) > 0 then
      if s.is_triggered_by_symbol then
        has_triggered_by_symbol_source = true
        break
      end
    end
  end

  -- create filtered entries.
  local offset = ctx.cursor.col
  for i, s in ipairs(sources) do
    if s.offset <= offset then
      if not has_triggered_by_symbol_source or s.is_triggered_by_symbol then
        -- source order priority bonus.
        local priority = s:get_config().priority or ((#sources - (i - 1)) * config.get().sorting.priority_weight)

        for _, e in ipairs(s:get_entries(ctx)) do
          e.score = e.score + priority
          table.insert(entries, e)
          offset = math.min(offset, e:get_offset())
        end
      end
    end
  end

  -- sort.
  table.sort(entries, function(e1, e2)
    for _, fn in ipairs(config.get().sorting.comparators) do
      local diff = fn(e1, e2)
      if diff ~= nil then
        return diff
      end
    end
  end)

  -- create vim items.
  local items = {}
  local deduped_entries = {}
  local deduped_words = {}
  local preselect = 0
  for _, e in ipairs(entries) do
    local item = e:get_vim_item(offset)
    if item.dup == 1 or not deduped_words[item.word] then
      deduped_words[item.word] = true
      -- We have done deduplication already, no need to force Vim to repeat it.
      item.dup = 1
      table.insert(items, item)
      table.insert(deduped_entries, e)
      if preselect == 0 and e.completion_item.preselect and config.get().preselect ~= types.cmp.PreselectMode.None then
        preselect = #deduped_entries
      end
    end
  end

  -- save recent pum state.
  self.offset = offset
  self.items = items
  self.entries = entries
  self.deduped_entries = deduped_entries
  self.preselect = preselect
  self.context = ctx
  self:show()
end

---Restore previous menu
---@param ctx cmp.Context
menu.restore = function(self, ctx)
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
  if #self.deduped_entries == 0 then
    self:close()
    return
  end
  debug.log('menu.show', #self.deduped_entries)

  local completeopt = vim.o.completeopt
  if self.preselect == 1 then
    vim.opt.completeopt = { 'menuone', 'noinsert' }
  else
    vim.opt.completeopt = config.get().completion.completeopt
  end
  vim.fn.complete(self.offset, self.items)
  if self.preselect > 1 then
    vim.api.nvim_select_popupmenu_item(self.preselect - 1, false, false, {})
  end
  vim.opt.completeopt = completeopt
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
  if vim.fn.pumvisible() == 0 or not (vim.v.completed_item or {}).user_data then
    return nil
  end
  return self:get_selected_entry()
end

---Get current selected entry
---@return cmp.Entry|nil
menu.get_selected_entry = function(self)
  if not self:is_valid_mode() then
    return nil
  end

  local selected = vim.fn.complete_info({ 'selected' }).selected
  if selected == -1 then
    return nil
  end
  return self.deduped_entries[math.max(selected, 0) + 1]
end

---Get first entry
---@param self cmp.Entry|nil
menu.get_first_entry = function(self)
  if not self:is_valid_mode() then
    return nil
  end
  return self.deduped_entries[1]
end

---Return the completion menu is visible or not.
---@return boolean
menu.is_valid_mode = function()
  return vim.fn.complete_info({ 'mode' }).mode == 'eval'
end

return menu
