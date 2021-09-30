local event = require('cmp.utils.event')
local autocmd = require('cmp.utils.autocmd')
local keymap = require('cmp.utils.keymap')
local types = require('cmp.types')
local config = require('cmp.config')

---@class cmp.NativeEntriesView
---@field private offset number
---@field private entries cmp.Entry[]
---@field public event cmp.Event
local native_entries_view = {}

native_entries_view.new = function()
  local self = setmetatable({}, { __index = native_entries_view })
  self.event = event.new()
  autocmd.subscribe('CompleteChanged', function()
    self.event:emit('change')
  end)
  return self
end

native_entries_view.ready = function(_)
  if vim.fn.pumvisible() == 0 then
    return true
  end
  return vim.fn.complete_info({ 'mode' }).mode == 'eval'
end

native_entries_view.open = function(self, offset, entries)
  self.offset = offset
  self.entries = {}

  if #entries > 0 then
    local preselect = 0
    local dedup = {}
    local items = {}
    for _, e in ipairs(entries) do
      local item = e:get_vim_item(offset)
      if item.dup == 1 or not dedup[item.abbr] then
        dedup[item.abbr] = true
        table.insert(self.entries, e)
        table.insert(items, item)
        if preselect == 0 and e.completion_item.preselect then
          preselect = #self.entries
        end
      end
    end
    local completeopt = vim.o.completeopt
    vim.o.completeopt = preselect == 1 and 'menu,menuone,noinsert' or config.get().completion.completeopt
    vim.fn.complete(self.offset, items)
    vim.o.completeopt = completeopt

    if preselect > 1 and config.get().preselect == types.cmp.PreselectMode.Item then
      self:preselect(preselect)
    end
  else
    self:close()
  end
end

native_entries_view.close = function(_)
  if string.sub(vim.api.nvim_get_mode().mode, 1, 1) == 'i' then
    vim.fn.complete(1, {})
  end
end

native_entries_view.abort = function(_)
  if string.sub(vim.api.nvim_get_mode().mode, 1, 1) == 'i' then
    vim.api.nvim_select_popupmenu_item(-1, true, true, {})
  end
end

native_entries_view.visible = function(_)
  return vim.fn.pumvisible() == 1
end

native_entries_view.info = function(self)
  if self:visible() then
    local info = vim.fn.pum_getpos()
    return {
      width = info.width + (info.scrollbar and 1 or 0),
      height = info.height,
      row = info.row,
      col = info.col,
    }
  end
end

native_entries_view.preselect = function(self, index)
  if self:visible() then
    if index <= #self.entries then
      vim.api.nvim_select_popupmenu_item(index - 1, false, false, {})
    end
  end
end

native_entries_view.select_next_item = function(self, option)
  if self:visible() then
    if (option.behavior or types.cmp.SelectBehavior.Insert) == types.cmp.SelectBehavior.Insert then
      keymap.feedkeys(keymap.t('<C-n>'), 'n')
    else
      keymap.feedkeys(keymap.t('<Down>'), 'n')
    end
  end
end

native_entries_view.select_prev_item = function(self, option)
  if self:visible() then
    if (option.behavior or types.cmp.SelectBehavior.Insert) == types.cmp.SelectBehavior.Insert then
      keymap.feedkeys(keymap.t('<C-p>'), 'n')
    else
      keymap.feedkeys(keymap.t('<Up>'), 'n')
    end
  end
end

native_entries_view.get_first_entry = function(self)
  if self:visible() then
    return self.entries[1]
  end
end

native_entries_view.get_selected_entry = function(self)
  if self:visible() then
    local idx = vim.fn.complete_info({ 'selected' }).selected
    if idx > -1 then
      return self.entries[math.max(0, idx) + 1]
    end
  end
end

native_entries_view.get_active_entry = function(self)
  if self:visible() and (vim.v.completed_item or {}).word then
    return self:get_selected_entry()
  end
end

return native_entries_view
