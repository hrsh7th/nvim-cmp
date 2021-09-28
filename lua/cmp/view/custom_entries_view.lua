local event = require('cmp.utils.event')
local autocmd = require('cmp.utils.autocmd')
local window = require('cmp.utils.window')
local config = require('cmp.config')
local types = require('cmp.types')

---@class cmp.CustomEntriesView
---@field private entries_win cmp.Window
---@field private offset number
---@field private entries cmp.Entry[]
---@field private marks table[]
---@field public event cmp.Event
local custom_entries_view = {}

custom_entries_view.ns = vim.api.nvim_create_namespace('cmp.view.custom_entries_view')

custom_entries_view.new = function()
  local self = setmetatable({}, { __index = custom_entries_view })
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

  autocmd.subscribe(
    'CompleteChanged',
    vim.schedule_wrap(function()
      if self:visible() and vim.fn.pumvisible() == 1 then
        self:close()
      end
    end)
  )

  vim.api.nvim_set_decoration_provider(custom_entries_view.ns, {
    on_win = function(_, win)
      return win == self.entries_win.win
    end,
    on_line = function(_, _, bufnr, row)
      for _, mark in ipairs(self.marks[row + 1]) do
        vim.api.nvim_buf_set_extmark(bufnr, custom_entries_view.ns, row, mark.col, {
          end_line = row,
          end_col = mark.col + mark.length,
          hl_group = mark.hl_group,
          hl_mode = 'combine',
          ephemeral = true,
        })
      end
      for _, m in ipairs(self.entries[row + 1].matches or {}) do
        vim.api.nvim_buf_set_extmark(bufnr, custom_entries_view.ns, row, m.word_match_start, {
          end_line = row,
          end_col = m.word_match_end + 1,
          hl_group = m.fuzzy and 'CmpItemAbbrMatchFuzzy' or 'CmpItemAbbrMatch',
          hl_mode = 'combine',
          ephemeral = true,
        })
      end
    end,
  })

  return self
end

custom_entries_view.ready = function()
  return vim.fn.pumvisible() == 0
end

custom_entries_view.open = function(self, offset, entries)
  self.offset = offset
  self.entries = {}
  self.marks = {}

  if #entries > 0 then
    local dedup = {}
    local abbrs = { width = 0, texts = {}, widths = {}, hl_groups = {} }
    local kinds = { width = 0, texts = {}, widths = {}, hl_groups = {} }
    local menus = { width = 0, texts = {}, widths = {}, hl_groups = {} }
    local preselect = 0
    for _, e in ipairs(entries) do
      local i = #self.entries + 1
      local item = e:get_vim_item(offset)
      if item.dup == 1 or not dedup[item.abbr] then
        dedup[item.abbr] = true

        table.insert(self.entries, e)

        abbrs.texts[i] = item.abbr
        abbrs.hl_groups[i] = e:is_deprecated() and 'CmpItemAbbrDeprecated' or 'CmpItemAbbr'
        abbrs.widths[i] = vim.str_utfindex(abbrs.texts[i])
        abbrs.width = math.max(abbrs.width, abbrs.widths[i])

        kinds.texts[i] = (item.kind or '')
        kinds.hl_groups[i] = 'CmpItemKind'
        kinds.widths[i] = vim.str_utfindex(kinds.texts[i])
        kinds.width = math.max(kinds.width, kinds.widths[i])

        menus.texts[i] = (item.menu or '')
        menus.widths[i] = vim.str_utfindex(kinds.texts[i])
        menus.width = math.max(kinds.width, kinds.widths[i])
        menus.hl_groups[i] = 'CmpItemMenu'

        if preselect == 0 and e.completion_item.preselect then
          preselect = i
        end
      end
    end

    local lines = {}
    local width = 0
    for i = 1, #self.entries do
      self.marks[i] = {}
      local off = 1
      local parts = { '' }
      for _, part in ipairs({ abbrs, kinds, menus }) do
        if #part.texts[i] > 0 then
          local text = part.texts[i] .. string.rep(' ', part.width - part.widths[i])
          table.insert(parts, text)
          table.insert(self.marks[i], {
            col = off,
            length = #part.texts[i],
            hl_group = part.hl_groups[i],
          })
          off = off + #text + 1
        end
      end
      table.insert(parts, '')
      lines[i] = table.concat(parts, ' ')
      width = math.max(width, vim.str_utfindex(lines[i]))
    end
    vim.api.nvim_buf_set_lines(self.entries_win.buf, 0, -1, false, lines)

    local row = vim.fn.screenrow()
    local height = vim.api.nvim_get_option('pumheight')
    height = height == 0 and #self.entries or height
    height = math.min(height, #self.entries)
    if (vim.o.lines - row) <= 8 and row - 8 > 0 then
      row = row - height - 1
    else
      height = math.min(height, vim.o.lines - row)
    end

    if width < 1 or height < 1 then
      return
    end

    local delta = vim.api.nvim_win_get_cursor(0)[2] + 1 - self.offset
    self.entries_win:option('cursorline', false)
    self.entries_win:open({
      relative = 'editor',
      style = 'minimal',
      row = row,
      col = vim.fn.screencol() - 1 - delta - 1,
      width = width,
      height = height,
      zindex = 1001,
    })
    vim.api.nvim_win_set_cursor(self.entries_win.win, { 1, 1 })

    if preselect > 0 and config.get().preselect == types.cmp.PreselectMode.Item then
      self:preselect(preselect)
    elseif string.match(config.get().completion.completeopt, 'noinsert') then
      self:preselect(1)
    end
    self.event:emit('change')
  else
    self:close()
    self.event:emit('change')
  end
end

custom_entries_view.close = function(self)
  self.offset = -1
  self.entries = {}
  self.marks = {}
  self.original = ''
  self.entries_win:close()
end

custom_entries_view.abort = function(self)
  if self.prefix then
    self:_insert(self.prefix)
  end
  self:close()
end

custom_entries_view.visible = function(self)
  return self.entries_win:visible()
end

custom_entries_view.info = function(self)
  return self.entries_win:info()
end

custom_entries_view.preselect = function(self, index)
  if self:visible() then
    if index <= #self.entries then
      self.entries_win:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.entries_win.win, { index, 1 })
      self.entries_win:update()
    end
  end
end

custom_entries_view.select_next_item = function(self, option)
  if self.entries_win:visible() then
    local cursor = vim.api.nvim_win_get_cursor(self.entries_win.win)[1] + 1
    if not self.entries_win:option('cursorline') then
      cursor = 1
    elseif #self.entries < cursor then
      cursor = 0
    end
    self:_select(cursor, option)
  end
end

custom_entries_view.select_prev_item = function(self, option)
  if self.entries_win:visible() then
    local cursor = vim.api.nvim_win_get_cursor(self.entries_win.win)[1] - 1
    if not self.entries_win:option('cursorline') then
      cursor = #self.entries
    end
    self:_select(cursor, option)
  end
end

custom_entries_view.get_first_entry = function(self)
  if self.entries_win:visible() then
    return self.entries[1]
  end
end

custom_entries_view.get_selected_entry = function(self)
  if self.entries_win:visible() and self.entries_win:option('cursorline') then
    return self.entries[vim.api.nvim_win_get_cursor(self.entries_win.win)[1]]
  end
end

custom_entries_view.get_active_entry = function(self)
  if self.entries_win:visible() and self.entries_win:option('cursorline') then
    local cursor = vim.api.nvim_win_get_cursor(self.entries_win.win)
    if cursor[2] == 0 then
      return self:get_selected_entry()
    end
  end
end

custom_entries_view._select = function(self, cursor, option)
  local is_insert = (option.behavior or types.cmp.SelectBehavior.Insert) == types.cmp.SelectBehavior.Insert
  if is_insert then
    if vim.api.nvim_win_get_cursor(self.entries_win.win)[2] == 1 then
      self.prefix = string.sub(vim.api.nvim_get_current_line(), self.offset, vim.api.nvim_win_get_cursor(0)[2]) or ''
    end
  end

  self.entries_win:option('cursorline', cursor > 0)
  vim.api.nvim_win_set_cursor(self.entries_win.win, { math.max(cursor, 1), is_insert and 0 or 1 })

  if is_insert then
    self:_insert(self.entries[cursor] and self.entries[cursor]:get_vim_item(self.offset).word or self.prefix)
  end
  self.entries_win:update()
  self.event:emit('change')
end

custom_entries_view._insert = function(self, word)
  vim.cmd([[undojoin]])
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_text(0, cursor[1] - 1, self.offset - 1, cursor[1] - 1, cursor[2], { word })
  vim.api.nvim_win_set_cursor(0, { cursor[1], self.offset + #word - 1 })
end

return custom_entries_view
