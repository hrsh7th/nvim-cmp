local cache = require('cmp.utils.cache')
local misc = require('cmp.utils.misc')
local buffer = require('cmp.utils.buffer')
local api = require('cmp.utils.api')
local str = require('cmp.utils.str')

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
---@field public thumb_win number|nil the scrollbar thumb window
---@field public scroll_win number|nil the scrollbar window
---@field public style cmp.WindowStyle
---@field public opt table<string, any>
---@field public buffer_opt table<string, any>
---@field public scrollbar string
---@field public cache cmp.Cache
local window = {}

---new
---@return cmp.Window
window.new = function()
  local self = setmetatable({}, { __index = window })
  self.name = misc.id('cmp.utils.window.new')
  self.win = nil
  self.scroll_win = nil
  self.thumb_win = nil
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
  self.style = style
  local info = self:info()

  if vim.o.lines and vim.o.lines <= info.row + info.height + 1 then
    self.style.height = vim.o.lines - info.row - info.border.height - 1
  end

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
  local info = self:info()
  if info.scrollbar and info.scrollbar.width > 0 then
    info.scrollbar.relative = 'editor'
    info.scrollbar.style = 'minimal'

    -- Draw the background of the scrollbar
    if str.is_invisible(self.style.border[2]) or math.max(info.border.height, info.border.width) < 1 then
      local style = {
        relative = info.scrollbar.relative,
        style = info.scrollbar.style,
        width = info.scrollbar.width,
        height = self.style.height,
        row = info.row + ((str.is_invisible(self.style.border[2]) or self.style.border == 'shadow') and 0 or 1),
        col = info.scrollbar.col,
        zindex = (self.style.zindex and (self.style.zindex + 1) or 1),
      }

      if self.scroll_win and vim.api.nvim_win_is_valid(self.scroll_win) then
        vim.api.nvim_win_set_config(self.scroll_win, style)
      else
        style.noautocmd = true
        self.scroll_win = vim.api.nvim_open_win(buffer.ensure(self.name .. 'scroll_buf'), false, style)
        local highlight = self.scrollbar == '' and 'PmenuSbar' or 'CmpScrollBar'
        vim.api.nvim_win_set_option(self.scroll_win, 'winhighlight', 'EndOfBuffer:'..highlight..',NormalFloat:'..highlight)
      end

      if self.scrollbar ~= '' then
        local replace = {}
        for i = 1, style.height do replace[i] = self.scrollbar end

        vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(self.scroll_win), 0, -1, true, replace)
      end
    end

    -- Draw the scrollbar thumb
    info.scrollbar.zindex = (self.style.zindex and (self.style.zindex + 2) or 2)

    if self.thumb_win and vim.api.nvim_win_is_valid(self.thumb_win) then
      vim.api.nvim_win_set_config(self.thumb_win, info.scrollbar)
    else
      info.scrollbar.noautocmd = true
      self.thumb_win = vim.api.nvim_open_win(buffer.ensure(self.name .. 'thumb_buf'), false, info.scrollbar)
      local highlight = self.scrollbar == '' and 'PmenuThumb' or 'CmpScrollThumb'
      vim.api.nvim_win_set_option(self.thumb_win, 'winhighlight', 'EndOfBuffer:'..highlight..',NormalFloat:'..highlight)
    end

    if self.scrollbar ~= '' then
      local replace = {}
      for i = 1, info.scrollbar.height do replace[i] = self.scrollbar end

      vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(self.thumb_win), 0, -1, true, replace)
    end
  else
    if self.scroll_win and vim.api.nvim_win_is_valid(self.scroll_win) then
      vim.api.nvim_win_hide(self.scroll_win)
      self.scroll_win = nil
    end
    if self.thumb_win and vim.api.nvim_win_is_valid(self.thumb_win) then
      vim.api.nvim_win_hide(self.thumb_win)
      self.thumb_win = nil
    end
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
    if self.scroll_win and vim.api.nvim_win_is_valid(self.scroll_win) then
      vim.api.nvim_win_hide(self.scroll_win)
      self.scroll_win = nil
    end
    if self.thumb_win and vim.api.nvim_win_is_valid(self.thumb_win) then
      vim.api.nvim_win_hide(self.thumb_win)
      self.thumb_win = nil
    end
  end
end

---Return the window is visible or not.
window.visible = function(self)
  return self.win and vim.api.nvim_win_is_valid(self.win)
end

---Return win info.
window.info = function(self)
  local border_height, border_width = self:get_border_dimensions()
  local info = {
    row = self.style.row,
    col = self.style.col,
    width = self.style.width + border_width,
    height = self.style.height + border_height,
    -- NOTE: this is the scrollbar THUMB information.
    border = {
      height = border_height,
      width = border_width,
    },
  }

  -- Information about the scrollbar
  if self.win and type(self.scrollbar) == 'string' then
    local content_height = self:get_content_height()
    if content_height > self.style.height then
      info.scrollbar = {
        height = math.ceil(self.style.height * (self.style.height / content_height)),
        width = 1,
      }
      info.scrollbar.col = info.col + info.width - ((str.is_invisible(self.style.border[4])) and 0 or 1)
      info.scrollbar.row = info.row +
        math.min(self.style.height - info.scrollbar.height, math.floor(self.style.height * (vim.fn.getwininfo(self.win)[1].topline / content_height))) +
        ((str.is_invisible(self.style.border[2]) or self.style.border == 'shadow') and 0 or 1)
      if border_width < 1 then
        info.width = info.width + info.scrollbar.width
      end
    end
  end

  return info
end

--- @return number height, number width
--- @return number[] dimensions the height and width
window.get_border_dimensions = function(self)
  local border = self.style.border

  if border == 'shadow' then
    return 1, 1
  elseif type(border) == 'string' then
    return 2, 2
  elseif type(border) == 'table' then
    -- NOTE: the border indices look like this: 1 2 3
    --                                          8   4
    --                                          7 6 5
    return (self.style.border[2] ~= '' and 1 or 0) + (self.style.border[6] ~= '' and 1 or 0),
           (self.style.border[4] ~= '' and 1 or 0) + (self.style.border[8] ~= '' and 1 or 0)
  end

  return 0, 0
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
