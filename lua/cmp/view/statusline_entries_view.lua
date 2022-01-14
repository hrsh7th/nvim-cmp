local event = require('cmp.utils.event')
local autocmd = require('cmp.utils.autocmd')
local feedkeys = require('cmp.utils.feedkeys')
local config = require('cmp.config')
local window = require('cmp.utils.window')
local types = require('cmp.types')
local keymap = require('cmp.utils.keymap')
local misc = require('cmp.utils.misc')
local api = require('cmp.utils.api')

---@class cmp.CustomEntriesView
---@field private offset number
---@field private entries_win cmp.Window
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
  self.selected_index = nil
  self.last_displayed_indices = {}
  self.moving_forwards = nil
end

statusline_entries_view.new = function()
  local self = setmetatable({}, { __index = statusline_entries_view })
  self:init()

  self.entries_win = window.new()
  self.entries_win:option('conceallevel', 2)
  self.entries_win:option('concealcursor', 'n')
  self.entries_win:option('cursorlineopt', 'line')
  self.entries_win:option('foldenable', false)
  self.entries_win:option('wrap', false)
  self.entries_win:option('scrolloff', 0)
  self.entries_win:option('winhighlight', 'Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None')
  self.entries_win:buffer_option('tabstop', 1)

  vim.api.nvim_set_decoration_provider(statusline_entries_view.ns, {
    on_win = function(_, win, buf, _, _)
      if win ~= self.entries_win.win or buf ~= self.entries_win:get_buffer() then
        return
      end

      dump('========================================')
      local location = 0
      for _, i in ipairs(self.last_displayed_indices) do
        local e = self.entries[i]
        if e then
          local view = e:get_view(self.offset, buf)
          vim.api.nvim_buf_set_extmark(buf, statusline_entries_view.ns, 0, location, {
            end_line = 0,
            end_col = location + view['abbr'].bytes,
            hl_group = view['abbr'].hl_group,
            hl_mode = 'combine',
            ephemeral = true,
          })

          if i == self.selected_index then
            vim.api.nvim_buf_set_extmark(buf, statusline_entries_view.ns, 0, location, {
              end_line = 0,
              end_col = location + view['abbr'].bytes,
              hl_group = 'PmenuSel',
              hl_mode = 'combine',
              ephemeral = true,
            })
          end

          for _, m in ipairs(e.matches or {}) do
            vim.api.nvim_buf_set_extmark(buf, statusline_entries_view.ns, 0, location + m.word_match_start - 1, {
              end_line = 0,
              end_col = location + m.word_match_end,
              hl_group = m.fuzzy and 'CmpItemAbbrMatchFuzzy' or 'CmpItemAbbrMatch',
              hl_mode = 'combine',
              ephemeral = true,
            })
          end

          location = location + view['abbr'].bytes + 1
        end
      end
    end,
  })

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
  self.entries_win:close()
  self:init()
end

statusline_entries_view.ready = function()
  return vim.fn.pumvisible() == 0
end

statusline_entries_view.on_change = function(self)
  self.active = false
end

statusline_entries_view.open = function(self, offset, entries)
  self.offset = offset
  self.entries = {}
  self.last_displayed_indices = {}

  -- Apply window options (that might be changed) on the custom completion menu.
  self.entries_win:option('winblend', vim.o.pumblend)

  -- local entries_buf = self.entries_win:get_buffer()
  local dedup = {}
  local preselect = 0
  local i = 1
  for _, e in ipairs(entries) do
    local view = e:get_view(offset, 0)
    if view.dup == 1 or not dedup[e.completion_item.label] then
      dedup[e.completion_item.label] = true
      table.insert(self.entries, e)
      if preselect == 0 and e.completion_item.preselect then
        preselect = i
      end
      i = i + 1
    end
  end

  self.entries_win:open({
    relative = 'editor',
    style = 'minimal',
    row = vim.api.nvim_win_get_height(0),
    col = 0,
    width = vim.api.nvim_win_get_width(0),
    height = 1,
    zindex = 1001,
  })
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

statusline_entries_view.draw = function(self)
  local entries_buf = self.entries_win:get_buffer()
  local texts = {}
  local lengths = {}
  for i, e in ipairs(self.entries) do
    if e then
      local view = e:get_view(self.offset, entries_buf)
      -- add 1 to lengths, to account for the added separator
      table.insert(lengths, view['abbr'].bytes + 1)
      table.insert(texts, view['abbr'].text)
    end
  end

  local selected_index = (self.selected_index or 1)
  local start_index = (self.selected_index or 1)
  local lst_dspl_ind = self.last_displayed_indices
  if #lst_dspl_ind == 0 then
    start_index = start_index
  elseif vim.tbl_contains(lst_dspl_ind, selected_index) then
    start_index = lst_dspl_ind[1]
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
    if total_length + lengths[index] < vim.api.nvim_win_get_width(self.entries_win.win) then
      if total_length ~= 0 and index == start_index then
        break
      end
      table.insert(statusline, texts[index])
      table.insert(displayed_indices, index)
      total_length = total_length + lengths[index]
    else
      -- always add the last entry
      table.insert(statusline, texts[index])
      break
    end
  end

  statusline = table.concat(statusline, '|')
  self.last_displayed_indices = displayed_indices

  vim.api.nvim_buf_set_lines(entries_buf, 0, 1, false, { statusline })
  vim.api.nvim_buf_set_option(entries_buf, 'modified', false)

  vim.api.nvim_win_call(0, function()
    misc.redraw()
  end)
end

statusline_entries_view.visible = function(self)
  return self.entries_win:visible()
end

statusline_entries_view.info = function(self)
  return self.entries_win:info()
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

  self.entries_win:update()
  self:draw()
  self.event:emit('change')
end

return statusline_entries_view
