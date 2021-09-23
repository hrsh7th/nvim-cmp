local event = require "cmp.utils.event"
local autocmd = require('cmp.utils.autocmd')
local keymap = require('cmp.utils.keymap')

---@class cmp.NativeEntriesView
---@field public offset number
---@field public entries cmp.Entry[]
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

native_entries_view.open = function(self, offset, entries)
  self.offset = offset
  self.entries = {}

  if #entries > 0 then
    local dedup = {}
    local items = {}
    for _, e in ipairs(entries) do
      local item = e:get_vim_item(offset)
      if item.dup == 1 or not dedup[item.abbr] then
        dedup[item.abbr] = true
        table.insert(self.entries, e)
        table.insert(items, item)
      end
    end
    vim.fn.complete(self.offset, items)
  else
    self:close()
  end
  vim.cmd [[doautocmd CompleteChanged]]
end

native_entries_view.close = function(_)
  if string.sub(vim.api.nvim_get_mode().mode, 1, 1) == 'i' then
    vim.fn.complete(1, {})
    keymap.feedkeys(keymap.t('<C-e>'), 'n')
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

native_entries_view.select_next_item = function(self)
  if self:visible() then
    keymap.feedkeys(keymap.t('<C-n>'), 'n')
  end
end

native_entries_view.select_prev_item = function(self)
  if self:visible() then
    keymap.feedkeys(keymap.t('<C-p>'), 'n')
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
  if self:visible() then
    if (vim.v.completed_item or {}).word then
      return self:get_selected_entry()
    end
  end
end

return native_entries_view

