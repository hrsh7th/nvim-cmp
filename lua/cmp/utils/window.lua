local window_analysis = require('cmp.utils.window_analysis')
local misc = require('cmp.utils.misc')
local buffer = require('cmp.utils.buffer')
local api = require('cmp.utils.api')

---@class cmp.WindowStyle
---@field public relative string
---@field public row number
---@field public col number
---@field public width number
---@field public height number
---@field public zindex number|nil
---@field public border string|string[]

---@class cmp.Window
---@field public name string
---@field public win number|nil
---@field public sbar_win number|nil
---@field public thumb_win number|nil
---@field public style cmp.WindowStyle
---@field public window_opt table<string, any>
---@field public buffer_opt table<string, any>
local window = {}

---new
---@return cmp.Window
window.new = function()
  local self = setmetatable({}, { __index = window })
  self.name = misc.id('cmp.utils.window.new')
  self.win = nil
  self.sbar_win = nil
  self.thumb_win = nil
  self.style = {}
  self.window_opt = {}
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
    return self.window_opt[key]
  end

  self.window_opt[key] = value
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
  local border_info = window_analysis.get_border_info(style.border)
  if style.row + style.height + border_info.vertical >= vim.o.lines - 1 then
    style.height = vim.o.lines - style.row - border_info.vertical - 1
  end
  local analyzed = window_analysis.analyze(style, self:get_buffer())
  if style.col + analyzed.width >= vim.o.columns - 1 then
    style.width = vim.o.columns - style.col - analyzed.border_info.horizontal - analyzed.scroll_info.extra_width
  end
  if style.row < 0 or style.col < 0 or style.width <= 0 or style.height <= 0 then
    return
  end
  style.zindex = style.zindex or 1

  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_set_config(self.win, style)
  else
    local s = misc.copy(style)
    s.noautocmd = true
    self.win = vim.api.nvim_open_win(self:get_buffer(), false, s)
    for k, v in pairs(self.window_opt) do
      vim.api.nvim_win_set_option(self.win, k, v)
    end
  end
  self.style = style
  self:update()
end

---Update
window.update = function(self)
  local analyzed = self:analyzed()
  if analyzed.scroll_info.scrollable then
    local bar_ratio = analyzed.inner_height / analyzed.scroll_height
    local scroll_ratio = vim.fn.getwininfo(self.win)[1].topline / analyzed.scroll_height

    local area_height, area_offset, bar_height, bar_offset
    if analyzed.border_info.is_visible then
      area_height = analyzed.inner_height
      area_offset = analyzed.border_info.top
    else
      area_height = analyzed.height
      area_offset = 0
    end
    bar_height = math.floor(0.5 + area_height * bar_ratio)
    bar_offset = math.floor(area_height * scroll_ratio)

    if not analyzed.border_info.is_visible then
      local style1 = {}
      style1.relative = 'editor'
      style1.style = 'minimal'
      style1.width = 1
      style1.height = area_height
      style1.row = analyzed.row + area_offset
      style1.col = analyzed.col + analyzed.width - 1
      style1.zindex = (self.style.zindex and (self.style.zindex + 1) or 1)
      if self.sbar_win and vim.api.nvim_win_is_valid(self.sbar_win) then
        vim.api.nvim_win_set_config(self.sbar_win, style1)
      else
        style1.noautocmd = true
        self.sbar_win = vim.api.nvim_open_win(buffer.ensure(self.name .. 'sbar_buf'), false, style1)
        vim.api.nvim_win_set_option(self.sbar_win, 'winhighlight', 'EndOfBuffer:PmenuSbar,Normal:PmenuSbar,NormalNC:PmenuSbar,NormalFloat:PmenuSbar')
      end
    end
    local style2 = {}
    style2.relative = 'editor'
    style2.style = 'minimal'
    style2.width = 1
    style2.height = bar_height
    style2.row = analyzed.row + area_offset + bar_offset
    style2.col = analyzed.col + analyzed.width - 1
    style2.zindex = (self.style.zindex and (self.style.zindex + 2) or 2)
    if self.thumb_win and vim.api.nvim_win_is_valid(self.thumb_win) then
      vim.api.nvim_win_set_config(self.thumb_win, style2)
    else
      style2.noautocmd = true
      self.thumb_win = vim.api.nvim_open_win(buffer.ensure(self.name .. 'thumb_win'), false, style2)
      vim.api.nvim_win_set_option(self.thumb_win, 'winhighlight', 'EndOfBuffer:PmenuThumb,Normal:PmenuThumb,NormalNC:PmenuThumb,NormalFloat:PmenuThumb')
    end
  else
    if self.sbar_win and vim.api.nvim_win_is_valid(self.sbar_win) then
      vim.api.nvim_win_hide(self.sbar_win)
      self.sbar_win = nil
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
    if self.sbar_win and vim.api.nvim_win_is_valid(self.sbar_win) then
      vim.api.nvim_win_hide(self.sbar_win)
      self.sbar_win = nil
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

window.analyzed = function(self)
  return window_analysis.analyze(self.style, self:get_buffer())
end

return window
