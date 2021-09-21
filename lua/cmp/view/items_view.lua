local event = require('cmp.utils.event')
local autocmd = require('cmp.utils.autocmd')
local window = require "cmp.utils.window"

---@class cmp.ItemsView
---@field public items_win cmp.Window
---@field public offset number
---@field public entries cmp.Entry[]
---@field public marks table[]
---@field public event cmp.Event
local items_view = {}

items_view.ns = vim.api.nvim_create_namespace('cmp.menu.fancy')

items_view.new = function()
  local self = setmetatable({}, { __index = items_view })
  self.items_win = window.new()
  self.items_win:option('conceallevel', 2)
  self.items_win:option('concealcursor', 'n')
  self.items_win:option('foldenable', false)
  self.items_win:option('wrap', false)
  self.items_win:option('scrolloff', 0)
  self.items_win:option('winhighlight', 'Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel')
  self.event = event.new()
  self.offset = -1
  self.entries = {}
  self.marks = {}

  vim.api.nvim_set_decoration_provider(items_view.ns, {
    on_win = function(_, winid)
      return winid == self.items_win.win
    end,
    on_line = function(_, winid, bufnr, row)
      if winid == self.items_win.win then
        for _, mark in ipairs(self.marks[row + 1]) do
          vim.api.nvim_buf_set_extmark(bufnr, items_view.ns, row, mark.col, {
            end_line = row,
            end_col = mark.col + mark.length,
            hl_group = mark.hl_group,
            hl_mode = 'combine',
            ephemeral = true,
          })
        end
        for _, m in ipairs(self.entries[row + 1].matches or {}) do
          vim.api.nvim_buf_set_extmark(bufnr, items_view.ns, row, m.word_match_start, {
            end_line = row,
            end_col = m.word_match_end + 1,
            hl_group = 'Normal',
            hl_mode = 'combine',
            ephemeral = true,
          })
        end
      end
    end
  })

  return self
end

items_view.open = function(self, offset, entries)
  self.offset = offset
  self.entries = {}
  self.marks = {}

  if #entries > 0 then
    local dedup = {}
    local abbrs = { hl_group = 'Comment', width = 0, texts = {} }
    local kinds = { hl_group = 'Special', width = 0, texts = {} }
    local menus = { hl_group = 'NonText', width = 0, texts = {} }
    for _, e in ipairs(entries) do
      local i = #self.entries + 1
      local item = e:get_vim_item(offset)
      if item.dup == 1 or not dedup[item.abbr] then
        dedup[item.abbr] = true
        abbrs.texts[i] = ' ' .. item.abbr
        abbrs.width = math.max(abbrs.width, vim.fn.strdisplaywidth(abbrs.texts[i]))
        kinds.texts[i] = (item.kind or '')
        kinds.width = math.max(kinds.width, vim.fn.strdisplaywidth(kinds.texts[i]))
        menus.texts[i] = (item.menu or '') .. ' '
        menus.width = math.max(menus.width, vim.fn.strdisplaywidth(menus.texts[i]))
        table.insert(self.entries, e)
      end
    end

    local lines = {}
    local width = 1
    for i = 1, #self.entries do
      self.marks[i] = {}
      local off = 0
      local parts = {}
      for _, part in ipairs({ abbrs, kinds, menus }) do
        if #part.texts[i] > 0 then
          local w = vim.fn.strdisplaywidth(part.texts[i])
          table.insert(parts, part.texts[i] .. string.rep(' ', part.width - w))
          table.insert(self.marks[i], {
            col = off,
            length = #part.texts[i],
            hl_group = part.hl_group,
          })
          off = off + #parts[#parts] + 1
        end
      end
      lines[i] = table.concat(parts, ' ')
      width = math.max(#lines[i], width)
    end

    local height = #self.entries
    height = math.min(height, vim.api.nvim_get_option('pumheight') or height)
    height = math.min(height, (vim.o.lines - 1) - vim.fn.winline() - 1)

    vim.api.nvim_buf_set_lines(self.items_win.buf, 0, -1, false, lines)
    self.items_win:open({
      relative = 'editor',
      style = 'minimal',
      row = vim.fn.screenrow(),
      col = vim.fn.screencol() - 1,
      width = width,
      height = height,
    })
    vim.api.nvim_win_set_cursor(self.items_win.win, { 1, 0 })
    self.items_win:option('cursorline', false)
  else
    self:close()
  end
  self.event:emit('change')
end

items_view.close = function(self)
  self.items_win:close()
end

items_view.visible = function(self)
  return self.items_win:visible()
end

items_view.info = function(self)
  return self.items_win:info()
end

items_view.select_next_item = function(self)
  if self.items_win:visible() then
    local cursor = vim.api.nvim_win_get_cursor(self.items_win.win)[1]
    local word = self.prefix
    if not self.items_win:option('cursorline') then
      self.prefix = string.sub(vim.api.nvim_get_current_line(), self.offset, vim.api.nvim_win_get_cursor(0)[2])
      self.items_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.items_win.win, { 1, 0 })
      word = self.entries[1]:get_word()
    elseif cursor == #self.entries then
      self.items_win:option('cursorline', false)
      vim.api.nvim_win_set_cursor(self.items_win.win, { 1, 0 })
    else
      self.items_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.items_win.win, { cursor + 1, 0 })
      word = self.entries[cursor + 1]:get_word()
    end
    self:insert(word)
    self.items_win:update()
    self.event:emit('change')
  end
end

items_view.select_prev_item = function(self)
  if self.items_win:visible() then
    local cursor = vim.api.nvim_win_get_cursor(self.items_win.win)[1]
    local word = self.prefix
    if not self.items_win:option('cursorline') then
      self.prefix = string.sub(vim.api.nvim_get_current_line(), self.offset, vim.api.nvim_win_get_cursor(0)[2])
      self.items_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.items_win.win, { #self.entries, 0 })
      word = self.entries[#self.entries]:get_word()
    elseif cursor == 1 then
      self.items_win:option('cursorline', false)
      vim.api.nvim_win_set_cursor(self.items_win.win, { 1, 0 })
    else
      self.items_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.items_win.win, { cursor - 1, 0 })
      word = self.entries[cursor - 1]:get_word()
    end
    self:insert(word)
    self.items_win:update()
    self.event:emit('change')
  end
end

items_view.active = function(self)
  return not not self:get_selected_entry()
end

items_view.get_first_entry = function(self)
  if self.items_win:visible() then
    return self.entries[1]
  end
end

items_view.get_selected_entry = function(self)
  if self.items_win:visible() and self.items_win:option('cursorline') then
    return self.entries[vim.api.nvim_win_get_cursor(self.items_win.win)[1]]
  end
end

items_view.insert = function(self, word)
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_text(0, cursor[1] - 1, self.offset - 1, cursor[1] - 1, cursor[2], { word })
  vim.api.nvim_win_set_cursor(0, { cursor[1], self.offset + #word - 1 })
end

return items_view

