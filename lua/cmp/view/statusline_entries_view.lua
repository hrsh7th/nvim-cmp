local event = require('cmp.utils.event')
local autocmd = require('cmp.utils.autocmd')
local feedkeys = require('cmp.utils.feedkeys')
local config = require('cmp.config')
local types = require('cmp.types')
local keymap = require('cmp.utils.keymap')
local misc = require('cmp.utils.misc')
local api = require('cmp.utils.api')

---@class cmp.CustomEntriesView
---@field private offset number
---@field private active boolean
---@field private entries cmp.Entry[]
---@field public event cmp.Event
local statusline_entries_view = {}

statusline_entries_view.ns = vim.api.nvim_create_namespace('cmp.view.statusline_entries_view')

statusline_entries_view.init = function(self)
  self.event = event.new()
  self.offset = -1
  self.active = false
  self.entries = {}
  self.org_statusline = nil
  self.selected_index = nil
  self.last_displayed_indices = {}
  self.moving_forwards = nil
end

statusline_entries_view.new = function()
  local self = setmetatable({}, { __index = statusline_entries_view })
  self:init()

  autocmd.subscribe(
    'CompleteChanged',
    vim.schedule_wrap(function()
      if self:visible() and vim.fn.pumvisible() == 1 then
        self:close()
      end
    end)
  )
  return self
end

statusline_entries_view.close = function(self)
  if self.org_statusline ~= nil then
    vim.o.statusline = self.org_statusline
  end
  self:init()
end

statusline_entries_view.ready = function()
  return vim.fn.pumvisible() == 0
end

statusline_entries_view.on_change = function(self)
  self.active = false
end

statusline_entries_view.open = function(self, offset, entries)
  if self.org_statusline == nil then
    self.org_statusline = vim.o.statusline
  end
  self.offset = offset
  self.entries = {}
  self.last_displayed_indices = {}

  local lines = {}
  local dedup = {}
  local preselect = 0
  local i = 1
  for _, e in ipairs(entries) do
    local view = e:get_view(offset, 0)
    if view.dup == 1 or not dedup[e.completion_item.label] then
      dedup[e.completion_item.label] = true
      table.insert(self.entries, e)
      table.insert(lines, ' ')
      if preselect == 0 and e.completion_item.preselect then
        preselect = i
      end
      i = i + 1
    end
  end

  if preselect > 0 and config.get().preselect == types.cmp.PreselectMode.Item then
    self:_select(preselect, { behavior = types.cmp.SelectBehavior.Select })
  elseif not string.match(config.get().completion.completeopt, 'noselect') then
    self:_select(1, { behavior = types.cmp.SelectBehavior.Select })
  else
    self:_select(nil, { behavior = types.cmp.SelectBehavior.Select })
  end
end

statusline_entries_view.abort = function(self)
  feedkeys.call('', 'n', function()
    self:close()
  end)
end
-- format entry for status line.
-- only use the 'abbr' field
-- return formatted text, original text, view length
statusline_entries_view.highlight_entry = function(self, entry)
  local view = entry:get_view(self.offset, 0)
  local word = view['abbr'].text
  local view_length = view['abbr'].bytes
  local hl_group = '%#' .. view['abbr'].hl_group .. '#'
  local fuzzy_group = '%#' .. 'CmpItemAbbrMatchFuzzy' .. '#'
  local match_group = '%#' .. 'CmpItemAbbrMatch' .. '#'
  local text = { hl_group }
  local last_offset = 1
  for _, m in ipairs(entry.matches or {}) do
    if m.word_match_start > last_offset then
      -- add everything b4 m.word_match_start
      table.insert(text, word:sub(last_offset, m.word_match_start - 1))
    end
    table.insert(text, m.fuzzy and fuzzy_group or match_group)
    table.insert(text, word:sub(m.word_match_start, m.word_match_end))
    table.insert(text, hl_group)
    last_offset = m.word_match_end + 1
  end
  table.insert(text, '%#Normal#')
  table.insert(text, word:sub(last_offset))

  return table.concat(text, ''), word, view_length
end

statusline_entries_view.draw = function(self)
  local texts = {}
  local lengths = {}
  for i, e in ipairs(self.entries) do
    if e then
      local formatted_text, text, view_length = self:highlight_entry(e)
      if i == self.selected_index then
        formatted_text = '%#CursorLine#' .. text .. '%#Normal#'
      end
      table.insert(lengths, view_length)
      table.insert(texts, formatted_text)
    end
  end
  local selected_index = (self.selected_index or 1)
  local start_index = (self.selected_index or 1)
  local lst_dspl_ind = self.last_displayed_indices
  if #lst_dspl_ind == 0 then
    start_index = start_index
  elseif vim.tbl_contains(lst_dspl_ind, selected_index) then
    start_index = lst_dspl_ind[1]
    -- elseif start_index > lst_dspl_ind[#lst_dspl_ind] then
  elseif self.moving_forwards then
    local needed_length = lengths[selected_index]
    start_index = lst_dspl_ind[1]
    while needed_length > 0 and vim.tbl_contains(lst_dspl_ind, start_index) do
      needed_length = needed_length - lengths[start_index]
      start_index = start_index + 1
    end
  else -- we need to scroll back
    local needed_length = lengths[selected_index]
    start_index = lst_dspl_ind[1]
    while needed_length > 0 and vim.tbl_contains(lst_dspl_ind, start_index) do
      needed_length = needed_length - lengths[start_index]
      start_index = start_index - 1
      if start_index <= 0 then
        start_index = #self.entries
      end
    end
  end
  local statusline = {}
  local total_length = 0
  local displayed_indices = {}
  for index = start_index, #self.entries * 2 do
    if index > #self.entries then
      index = index - #self.entries
    end
    if total_length + lengths[index] < vim.api.nvim_win_get_width(0) then
      if total_length ~= 0 and index == start_index then
        break
      end
      table.insert(statusline, texts[index])
      table.insert(displayed_indices, index)
      -- add 1 for the space between items
      total_length = total_length + lengths[index] + 1
    else
      break
    end
  end

  statusline = table.concat(statusline, '|')
  self.last_displayed_indices = displayed_indices
  vim.o.statusline = statusline

  vim.api.nvim_win_call(0, function()
    misc.redraw()
  end)
end

statusline_entries_view.visible = function(self)
  return self.org_statusline ~= nil
end

statusline_entries_view.info = function(self)
  return nil
end

statusline_entries_view.select_next_item = function(self, option)
  if self:visible() then
    self.moving_forwards = true
    if self.selected_index == nil or self.selected_index == #self.entries then
      self:_select(1, option)
    else
      self:_select(self.selected_index + 1, option)
    end
  end
end

statusline_entries_view.select_prev_item = function(self, option)
  if self:visible() then
    self.moving_forwards = false
    if self.selected_index == nil or self.selected_index <= 1 then
      self:_select(#self.entries, option)
    else
      self:_select(self.selected_index - 1, option)
    end
  end
end

statusline_entries_view.get_first_entry = function(self)
  if self:visible() then
    return self.entries[1]
  end
end

statusline_entries_view.get_selected_entry = function(self)
  if self:visible() and self.active then
    return self.entries[self.selected_index]
  end
end

statusline_entries_view.get_active_entry = function(self)
  if self:visible() and self.active then
    return self:get_selected_entry()
  end
end

statusline_entries_view._select = function(self, selected_index, option)
  self.selected_index = selected_index
  self.active = (selected_index ~= nil)

  if self.active then
    local cursor = api.get_cursor()
    local word = self:get_active_entry():get_vim_item(self.offset).word
    local length = vim.fn.strchars(string.sub(api.get_current_line(), self.offset, cursor[2]), true)
    vim.api.nvim_feedkeys(keymap.backspace(length) .. word, 'int', true)
  end

  self:draw()
  self.event:emit('change')
end

return statusline_entries_view
