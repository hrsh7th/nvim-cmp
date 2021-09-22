local event = require('cmp.utils.event')
local window = require('cmp.utils.window')

---@class cmp.EntriesView
---@field public entries_win cmp.Window
---@field public offset number
---@field public entries cmp.Entry[]
---@field public marks table[]
---@field public event cmp.Event
local entries_view = {}

entries_view.ns = vim.api.nvim_create_namespace('cmp.menu.fancy')

entries_view.new = function()
  local self = setmetatable({}, { __index = entries_view })
  self.entries_win = window.new()
  self.entries_win:option('conceallevel', 2)
  self.entries_win:option('concealcursor', 'n')
  self.entries_win:option('foldenable', false)
  self.entries_win:option('wrap', false)
  self.entries_win:option('scrolloff', 0)
  self.entries_win:option('winhighlight', 'Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel')
  self.event = event.new()
  self.offset = -1
  self.entries = {}
  self.marks = {}

  vim.api.nvim_set_decoration_provider(entries_view.ns, {
    on_win = function(_, winid)
      return winid == self.entries_win.win
    end,
    on_line = function(_, winid, bufnr, row)
      if winid == self.entries_win.win then
        for _, mark in ipairs(self.marks[row + 1]) do
          vim.api.nvim_buf_set_extmark(bufnr, entries_view.ns, row, mark.col, {
            end_line = row,
            end_col = mark.col + mark.length,
            hl_group = mark.hl_group,
            hl_mode = 'combine',
            ephemeral = true,
          })
        end
        for _, m in ipairs(self.entries[row + 1].matches or {}) do
          vim.api.nvim_buf_set_extmark(bufnr, entries_view.ns, row, m.word_match_start, {
            end_line = row,
            end_col = m.word_match_end + 1,
            hl_group = m.fuzzy and 'CmpItemAbbrMatchFuzzy' or 'CmpItemAbbrMatch',
            hl_mode = 'combine',
            ephemeral = true,
          })
        end
      end
    end,
  })

  return self
end

entries_view.open = function(self, offset, entries)
  self.offset = offset
  self.entries = {}
  self.marks = {}

  if #entries > 0 then
    local dedup = {}
    local abbrs = { hl_group = 'CmpItemAbbr', width = 0, texts = {} }
    local kinds = { hl_group = 'CmpItemKind', width = 0, texts = {} }
    local menus = { hl_group = 'CmpItemMenu', width = 0, texts = {} }
    for _, e in ipairs(entries) do
      local i = #self.entries + 1
      local item = e:get_vim_item(offset)
      if item.dup == 1 or not dedup[item.abbr] then
        dedup[item.abbr] = true
        abbrs.texts[i] = item.abbr
        abbrs.width = math.max(abbrs.width, vim.fn.strchars(abbrs.texts[i]))
        kinds.texts[i] = (item.kind or '')
        kinds.width = math.max(kinds.width, vim.fn.strchars(kinds.texts[i]))
        menus.texts[i] = (item.menu or '')
        menus.width = math.max(menus.width, vim.fn.strchars(menus.texts[i]))
        table.insert(self.entries, e)
      end
    end

    local lines = {}
    local width = 0
    for i = 1, #self.entries do
      self.marks[i] = {}
      local off = 1
      local parts = { '' }
      for j, part in ipairs({ abbrs, kinds, menus }) do
        if #part.texts[i] > 0 then
          local w = vim.fn.strchars(part.texts[i])
          table.insert(parts, part.texts[i] .. string.rep(' ', part.width - w))
          table.insert(self.marks[i], {
            col = off,
            length = #part.texts[i],
            hl_group = j == 1 and self.entries[i]:is_deprecated() and 'CmpItemAbbrDeprecated' or part.hl_group,
          })
          off = off + #parts[#parts] + 1
        end
      end
      table.insert(parts, '')
      lines[i] = table.concat(parts, ' ')
      width = math.max(width, vim.fn.strchars(lines[i]))
    end
    vim.api.nvim_buf_set_lines(self.entries_win.buf, 0, -1, false, lines)

    local height = vim.api.nvim_get_option('pumheight')
    height = height == 0 and #self.entries or height
    height = math.min(height, #self.entries)
    height = math.min(height, (vim.o.lines - 1) - vim.fn.winline() - 1)

    local delta = vim.api.nvim_win_get_cursor(0)[2] + 1 - self.offset
    self.entries_win:open({
      relative = 'editor',
      style = 'minimal',
      row = vim.fn.screenrow(),
      col = vim.fn.screencol() - 1 - delta - 1,
      width = width,
      height = height,
    })
    if self.entries_win:visible() then
      vim.api.nvim_win_set_cursor(self.entries_win.win, { 1, 0 })
      self.entries_win:option('cursorline', false)
    end
  else
    self:close()
  end
  self.event:emit('change')
end

entries_view.close = function(self)
  self.entries_win:close()
end

entries_view.visible = function(self)
  return self.entries_win:visible()
end

entries_view.info = function(self)
  return self.entries_win:info()
end

entries_view.select_next_item = function(self)
  if self.entries_win:visible() then
    local cursor = vim.api.nvim_win_get_cursor(self.entries_win.win)[1]
    local word = self.prefix
    if not self.entries_win:option('cursorline') then
      self.prefix = string.sub(vim.api.nvim_get_current_line(), self.offset, vim.api.nvim_win_get_cursor(0)[2])
      self.entries_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.entries_win.win, { 1, 0 })
      word = self.entries[1]:get_word()
    elseif cursor == #self.entries then
      self.entries_win:option('cursorline', false)
      vim.api.nvim_win_set_cursor(self.entries_win.win, { 1, 0 })
    else
      self.entries_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.entries_win.win, { cursor + 1, 0 })
      word = self.entries[cursor + 1]:get_word()
    end
    self:insert(word)
    self.entries_win:update()
    self.event:emit('change')
  end
end

entries_view.select_prev_item = function(self)
  if self.entries_win:visible() then
    local cursor = vim.api.nvim_win_get_cursor(self.entries_win.win)[1]
    local word = self.prefix
    if not self.entries_win:option('cursorline') then
      self.prefix = string.sub(vim.api.nvim_get_current_line(), self.offset, vim.api.nvim_win_get_cursor(0)[2])
      self.entries_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.entries_win.win, { #self.entries, 0 })
      word = self.entries[#self.entries]:get_word()
    elseif cursor == 1 then
      self.entries_win:option('cursorline', false)
      vim.api.nvim_win_set_cursor(self.entries_win.win, { 1, 0 })
    else
      self.entries_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.entries_win.win, { cursor - 1, 0 })
      word = self.entries[cursor - 1]:get_word()
    end
    self:insert(word)
    self.entries_win:update()
    self.event:emit('change')
  end
end

entries_view.active = function(self)
  return not not self:get_selected_entry()
end

entries_view.get_first_entry = function(self)
  if self.entries_win:visible() then
    return self.entries[1]
  end
end

entries_view.get_selected_entry = function(self)
  if self.entries_win:visible() and self.entries_win:option('cursorline') then
    return self.entries[vim.api.nvim_win_get_cursor(self.entries_win.win)[1]]
  end
end

entries_view.insert = function(self, word)
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_text(0, cursor[1] - 1, self.offset - 1, cursor[1] - 1, cursor[2], { word })
  vim.api.nvim_win_set_cursor(0, { cursor[1], self.offset + #word - 1 })
end

return entries_view
