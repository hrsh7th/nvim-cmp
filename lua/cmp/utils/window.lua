local cache = require('cmp.utils.cache')
local misc = require('cmp.utils.misc')
local buffer = require('cmp.utils.buffer')
local api = require('cmp.utils.api')

---@class cmp.WindowStyle
---@field public relative string
---@field public row number
---@field public col number
---@field public width number
---@field public height number
---@field public border string|string[]|nil
---@field public zindex number|nil

---@class cmp.Window
---@field public name string
---@field public win number|nil
---@field public swin number|nil
---@field public style cmp.WindowStyle
---@field public opt table<string, any>
---@field public thin_scrollbar boolean|nil
---@field public buffer_opt table<string, any>
---@field public cache cmp.Cache
local window = {}

--- @param style cmp.WindowStyle
--- @return integer row the offset needed to account for the popup window
window.border_offset = function(style)
  if style.border then
    return (style.border[2] ~= '' and 1 or 0) + (style.border[6] ~= '' and 1 or 0)
  end

  return 0
end

--- @param style cmp.WindowStyle
--- @return integer row, integer column the offset needed to account for the scrollbar
window.border_offset_scrollbar = function(style)
  if style.border then
    -- We want to center the scrollbar vertically, and reduce the column by one if necessary
    return style.border[2] ~= '' and 1 or 0, style.border[4] ~= '' and 1 or 0
  end

  return 0, 0
end

---new
---@return cmp.Window
window.new = function()
  local self = setmetatable({}, { __index = window })
  self.name = misc.id('cmp.utils.window.new')
  self.win = nil
  self.swin = nil
  self.style = {}
  self.cache = cache.new()
  self.opt = {}
  self.buffer_opt = {}
  return self
end

---Set window option.
---NOTE: If the window already visible, immediately applied to it.
---@param key string
---@param value any
window.option = function(self, key, value)
  if vim.fn.exists('+' .. key) == 0 then
    return
  end

  if value == nil then
    return self.opt[key]
  end

  self.opt[key] = value
  if self:visible() then
    vim.api.nvim_win_set_option(self.win, key, value)
  end
end

---Set buffer option.
---NOTE: If the buffer already visible, immediately applied to it.
---@param key string
---@param value any
window.buffer_option = function(self, key, value)
  if vim.fn.exists('+' .. key) == 0 then
    return
  end

  if value == nil then
    return self.buffer_opt[key]
  end

  self.buffer_opt[key] = value
  local existing_buf = buffer.get(self.name)
  if existing_buf then
    vim.api.nvim_buf_set_option(existing_buf, key, value)
  end
end

---Set style.
---@param style cmp.WindowStyle
window.set_style = function(self, style)
  local border_offset = window.border_offset(style)

  if vim.o.lines and vim.o.lines <= style.row + style.height + border_offset + 1 then
    style.height = vim.o.lines - style.row - border_offset - 1
  end

  -- If the popup will open above the cursor
  if vim.fn.screenrow() - 1 > style.row then
    -- shrink row by `border_offset_row`
    style.row = style.row - border_offset
    if style.row < 0 then -- compensate for negative row with height adjustment
      style.height = style.height + style.row
      style.row = 0
    end
  end

  self.style = style
  self.style.zindex = self.style.zindex or 1
end

---Return buffer id.
---@return number
window.get_buffer = function(self)
  local buf, created_new = buffer.ensure(self.name)
  if created_new then
    for k, v in pairs(self.buffer_opt) do
      vim.api.nvim_buf_set_option(buf, k, v)
    end
  end
  return buf
end

---Open window
---@param style cmp.WindowStyle
window.open = function(self, style)
  if style then
    self:set_style(style)
  end

  if self.style.width < 1 or self.style.height < 1 then
    return
  end

  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_set_config(self.win, self.style)
  else
    local s = misc.copy(self.style)
    s.noautocmd = true
    self.win = vim.api.nvim_open_win(self:get_buffer(), false, s)
    for k, v in pairs(self.opt) do
      vim.api.nvim_win_set_option(self.win, k, v)
    end
  end
  self:update()
end

---Update
window.update = function(self)
  if self:has_scrollbar() then
    local total = self:get_content_height()
    local info = self:info()
    local bar_height = math.ceil(info.height * (info.height / total))
    local bar_offset = math.min(info.height - bar_height, math.floor(info.height * (vim.fn.getwininfo(self.win)[1].topline / total)))
    local border_offset_row, border_offset_col = window.border_offset_scrollbar(self.style)

    local style2 = {}
    style2.relative = 'editor'
    style2.style = 'minimal'
    style2.width = 1
    style2.height = bar_height
    style2.row = info.row + bar_offset + border_offset_row
    style2.col = info.col + info.width - (info.has_scrollbar and 1 or 0) - border_offset_col
    style2.zindex = (self.style.zindex and (self.style.zindex + 2) or 2)
    if self.swin and vim.api.nvim_win_is_valid(self.swin) then
      vim.api.nvim_win_set_config(self.swin, style2)
    else
      style2.noautocmd = true
      local sbuf2 = buffer.ensure(self.name .. 'sbuf2')
      self.swin = vim.api.nvim_open_win(sbuf2, false, style2)
      local highlight = self.thin_scrollbar and 'CmpItemMenuThumb' or 'PmenuThumb'
      vim.api.nvim_win_set_option(self.swin, 'winhighlight', 'EndOfBuffer:'..highlight..',NormalFloat:'..highlight)

      if self.thin_scrollbar then
        local replace = {}
        for i = 1, style2.height do replace[i] = '║' end

        vim.api.nvim_buf_set_lines(sbuf2, 0, 1, true, replace)
      end

      vim.api.nvim_buf_set_lines(sbuf2, 0, 1, true, replace)
    end
  elseif self.swin and vim.api.nvim_win_is_valid(self.swin) then
    vim.api.nvim_win_hide(self.swin)
    self.swin = nil
  end

  -- In cmdline, vim does not redraw automatically.
  if api.is_cmdline_mode() then
    vim.api.nvim_win_call(self.win, function()
      misc.redraw()
    end)
  end
end

---Close window
window.close = function(self)
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    if self.win and vim.api.nvim_win_is_valid(self.win) then
      vim.api.nvim_win_hide(self.win)
      self.win = nil
    end
    if self.swin and vim.api.nvim_win_is_valid(self.swin) then
      vim.api.nvim_win_hide(self.swin)
      self.swin = nil
    end
  end
end

---Return the window is visible or not.
window.visible = function(self)
  return self.win and vim.api.nvim_win_is_valid(self.win)
end

---Return the scrollbar will shown or not.
window.has_scrollbar = function(self)
  return (self.style.height or 0) < self:get_content_height()
end

---Return win info.
window.info = function(self)
  local border_width = self:get_border_width()
  local has_scrollbar = self:has_scrollbar()
  return {
    row = self.style.row,
    col = self.style.col,
    width = self.style.width + border_width + (has_scrollbar and 1 or 0),
    height = self.style.height,
    border_width = border_width,
    has_scrollbar = has_scrollbar,
  }
end

---Get border width
---@return number
window.get_border_width = function(self)
  local border = self.style.border
  if type(border) == 'table' then
    local new_border = {}
    while #new_border < 8 do
      for _, b in ipairs(border) do
        table.insert(new_border, b)
      end
    end
    border = new_border
  end

  local w = 0
  if border then
    if type(border) == 'string' then
      if border == 'single' then
        w = 2
      elseif border == 'solid' then
        w = 2
      elseif border == 'double' then
        w = 2
      elseif border == 'rounded' then
        w = 2
      elseif border == 'shadow' then
        w = 1
      end
    elseif type(border) == 'table' then
      local b4 = type(border[4]) == 'table' and border[4][1] or border[4]
      if #b4 > 0 then
        w = w + 1
      end
      local b8 = type(border[8]) == 'table' and border[8][1] or border[8]
      if #b8 > 0 then
        w = w + 1
      end
    end
  end
  return w
end

---Get scroll height.
---@return number
window.get_content_height = function(self)
  if not self:option('wrap') then
    return vim.api.nvim_buf_line_count(self:get_buffer())
  end

  return self.cache:ensure({
    'get_content_height',
    self.style.width,
    self:get_buffer(),
    vim.api.nvim_buf_get_changedtick(self:get_buffer()),
  }, function()
    local height = 0
    local buf = self:get_buffer()
    -- The result of vim.fn.strdisplaywidth depends on the buffer it was called
    -- in (see comment in cmp.Entry.get_view).
    vim.api.nvim_buf_call(buf, function()
      for _, text in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        height = height + math.ceil(math.max(1, vim.fn.strdisplaywidth(text)) / self.style.width)
      end
    end)
    return height
  end)
end

return window
