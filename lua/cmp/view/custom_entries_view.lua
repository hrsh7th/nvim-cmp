local event = require('cmp.utils.event')
local autocmd = require('cmp.utils.autocmd')
local window = require('cmp.utils.window')
local config = require('cmp.config')
local types = require('cmp.types')
local keymap = require('cmp.utils.keymap')
local misc = require('cmp.utils.misc')

---@class cmp.CustomEntriesView
---@field private entries_win cmp.Window
---@field private offset number
---@field private entries cmp.Entry[]
---@field private column_bytes any
---@field private column_width any
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
  self.entries_win:option('winhighlight', 'Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None')
  self.event = event.new()
  self.offset = -1
  self.entries = {}

  autocmd.subscribe(
    'CompleteChanged',
    vim.schedule_wrap(function()
      if self:visible() and vim.fn.pumvisible() == 1 then
        self:close()
      end
    end)
  )

  vim.api.nvim_set_decoration_provider(custom_entries_view.ns, {
    on_win = function(_, win, buf, top, bot)
      if win ~= self.entries_win.win then
        return
      end

      for i = top, bot do
        local e = self.entries[i + 1]
        if e then
          local v = e:get_view(self.offset)
          local o = 1
          for _, key in ipairs({ 'abbr', 'kind', 'menu' }) do
            if self.column_bytes[key] > 0 then
              vim.api.nvim_buf_set_extmark(buf, custom_entries_view.ns, i, o, {
                end_line = i,
                end_col = o + v[key].bytes,
                hl_group = v[key].hl_group,
                hl_mode = 'combine',
                ephemeral = true,
              })
              o = o + self.column_bytes[key] + 1
            end
          end
          for _, m in ipairs(e.matches or {}) do
            vim.api.nvim_buf_set_extmark(buf, custom_entries_view.ns, i, m.word_match_start, {
              end_line = i,
              end_col = m.word_match_end + 1,
              hl_group = m.fuzzy and 'CmpItemAbbrMatchFuzzy' or 'CmpItemAbbrMatch',
              hl_mode = 'combine',
              ephemeral = true,
            })
          end
        end
      end
    end,
  })

  return self
end

custom_entries_view.ready = function()
  return vim.fn.pumvisible() == 0
end

custom_entries_view.redraw = function()
  -- noop
end

custom_entries_view.open = function(self, offset, entries)
  self.offset = offset
  self.entries = {}
  self.column_bytes = { abbr = 0, kind = 0, menu = 0 }
  self.column_width = { abbr = 0, kind = 0, menu = 0 }

  local lines = {}
  local dedup = {}
  local preselect = 0
  local i = 1
  for _, e in ipairs(entries) do
    local view = e:get_view(offset)
    if view.dup == 1 or not dedup[e.completion_item.label] then
      dedup[e.completion_item.label] = true
      self.column_bytes.abbr = math.max(self.column_bytes.abbr, view.abbr.bytes)
      self.column_bytes.kind = math.max(self.column_bytes.kind, view.kind.bytes)
      self.column_bytes.menu = math.max(self.column_bytes.menu, view.menu.bytes)
      self.column_width.abbr = math.max(self.column_width.abbr, view.abbr.width)
      self.column_width.kind = math.max(self.column_width.kind, view.kind.width)
      self.column_width.menu = math.max(self.column_width.menu, view.menu.width)
      table.insert(self.entries, e)
      table.insert(lines, ' ')
      if preselect == 0 and e.completion_item.preselect then
        preselect = i
      end
      i = i + 1
    end
  end
  vim.api.nvim_buf_set_lines(self.entries_win.buf, 0, -1, false, lines)

  local width = 0
  width = width + 1
  width = width + self.column_width.abbr + (self.column_width.kind > 0 and 1 or 0)
  width = width + self.column_width.kind + (self.column_width.menu > 0 and 1 or 0)
  width = width + self.column_width.menu + 1

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = vim.fn.screenpos('.', cursor[1], cursor[2] + 1).row
  local height = vim.api.nvim_get_option('pumheight')
  height = height == 0 and #self.entries or height
  height = math.min(height, #self.entries)
  if (vim.o.lines - row) <= 8 and row - 8 > 0 then
    height = math.min(height, row - 1)
    row = row - height - 1
  else
    height = math.min(height, vim.o.lines - row)
  end

  if width < 1 or height < 1 then
    return
  end

  local delta = cursor[2] + 1 - self.offset
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
  else
    self:draw()
  end
  self.event:emit('change')
end

custom_entries_view.close = function(self)
  self.offset = -1
  self.entries = {}
  self.entries_win:close()
end

custom_entries_view.abort = function(self)
  if self.prefix then
    self:_insert(self.prefix)
  end
  self:close()
end

custom_entries_view.draw = function(self)
  local info = vim.fn.getwininfo(self.entries_win.win)[1]
  local topline = info.topline - 1
  local botline = info.topline + info.height - 1
  local texts = {}
  for i = topline, botline - 1 do
    local view = self.entries[i + 1]:get_view(self.offset)
    local text = {}
    table.insert(text, ' ')
    table.insert(text, view.abbr.text)
    table.insert(text, string.rep(' ', 1 + self.column_width.abbr - view.abbr.width))
    table.insert(text, view.kind.text)
    table.insert(text, string.rep(' ', 1 + self.column_width.kind - view.kind.width))
    table.insert(text, view.menu.text)
    table.insert(text, string.rep(' ', 1 + self.column_width.menu - view.menu.width))
    table.insert(text, ' ')
    table.insert(texts, table.concat(text, ''))
  end
  vim.api.nvim_buf_set_lines(self.entries_win.buf, topline, botline, false, texts)
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
      self:draw()
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
  self:draw()
  self.event:emit('change')
end

custom_entries_view._insert = function(self, word)
  vim.api.nvim_buf_set_keymap(0, 'i', '<Plug>(cmp.view.custom_entries_view._insert.remove)', ('v:lua.cmp.view.custom_entries_view._insert.remove(%s)'):format(self.offset), {
    expr = true,
    noremap = true,
  })
  keymap.feedkeys(keymap.t('<Plug>(cmp.view.custom_entries_view._insert.remove)'), 't')
  keymap.feedkeys(word, 'nt')
end

misc.set(_G, { 'cmp', 'view', 'custom_entries_view', '_insert', 'remove' }, function(offset)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local length = vim.str_utfindex(string.sub(vim.api.nvim_get_current_line(), offset, cursor[2]))
  return keymap.t(string.rep('<C-g>U<Left><Del>', length))
end)

return custom_entries_view
