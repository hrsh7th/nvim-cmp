local cache = require('cmp.utils.cache')

---@class cmp.WindowStyle
---@field public relative string
---@field public row number
---@field public col number
---@field public width number
---@field public height number

---@class cmp.Window
---@field public buf number
---@field public win number|nil
---@field public sbuf1 number
---@field public swin1 number|nil
---@field public sbuf2 number
---@field public swin2 number|nil
---@field public style cmp.WindowStyle
---@field public opt table<string, any>
---@field public cache cmp.Cache
local window = {}

---new
---@return cmp.Window
window.new = function()
  local self = setmetatable({}, { __index = window })
  self.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(self.buf, 'undolevels', -1)
  vim.api.nvim_buf_set_option(self.buf, 'buftype', 'nofile')
  self.win = nil
  self.style = {}
  self.sbuf1 = vim.api.nvim_create_buf(false, true)
  self.swin1 = nil
  self.sbuf2 = vim.api.nvim_create_buf(false, true)
  self.swin2 = nil
  self.cache = cache.new()
  self.opt = {}
  self.id = 0
  return self
end

---Set window option.
---NOTE: If the window already visible, immediately applied to it.
---@param key string
---@param value any
window.option = function(self, key, value)
  if value == nil then
    return self.opt[key]
  end

  self.opt[key] = value
  if self:visible() then
    vim.api.nvim_win_set_option(self.win, key, value)
  end
end

---Set style.
---@param style cmp.WindowStyle
window.set_style = function(self, style)
  if vim.o.columns and vim.o.columns <= style.col + style.width then
    style.width = vim.o.columns - style.col - 1
  end
  if vim.o.lines and vim.o.lines <= style.row + style.height then
    style.height = vim.o.lines - style.row - 1
  end
  self.style = style
end

---Open window
---@param style cmp.WindowStyle
window.open = function(self, style)
  self.id = self.id + 1

  if style then
    self:set_style(style)
  end

  if self.style.width < 1 or self.style.height < 1 then
    return
  end

  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_set_config(self.win, self.style)
  else
    self.win = vim.api.nvim_open_win(self.buf, false, self.style)
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
    local style1 = {}
    style1.relative = 'editor'
    style1.style = 'minimal'
    style1.width = 1
    style1.height = info.height
    style1.row = info.row
    style1.col = info.col + info.width - (info.has_scrollbar and 1 or 0)
    style1.zindex = 1
    if self.swin1 and vim.api.nvim_win_is_valid(self.swin1) then
      vim.api.nvim_win_set_config(self.swin1, style1)
    else
      self.swin1 = vim.api.nvim_open_win(self.sbuf1, false, style1)
      vim.api.nvim_win_set_option(self.swin1, 'winhighlight', 'Normal:PmenuSbar,NormalNC:PmenuSbar,NormalFloat:PmenuSbar')
    end
    local style2 = {}
    style2.relative = 'editor'
    style2.style = 'minimal'
    style2.width = 1
    style2.height = bar_height
    style2.row = info.row + bar_offset
    style2.col = info.col + info.width - (info.has_scrollbar and 1 or 0)
    style2.zindex = 2
    if self.swin2 and vim.api.nvim_win_is_valid(self.swin2) then
      vim.api.nvim_win_set_config(self.swin2, style2)
    else
      self.swin2 = vim.api.nvim_open_win(self.sbuf2, false, style2)
      vim.api.nvim_win_set_option(self.swin2, 'winhighlight', 'Normal:PmenuThumb,NormalNC:PmenuThumb,NormalFloat:PmenuThumb')
    end
  else
    if self.swin1 and vim.api.nvim_win_is_valid(self.swin1) then
      vim.api.nvim_win_close(self.swin1, false)
      self.swin1 = nil
    end
    if self.swin2 and vim.api.nvim_win_is_valid(self.swin2) then
      vim.api.nvim_win_close(self.swin2, false)
      self.swin2 = nil
    end
  end
end

---Close window
window.close = function(self)
  local id = self.id
  vim.schedule(function()
    if id == self.id then
      if self.win and vim.api.nvim_win_is_valid(self.win) then
        if self.win and vim.api.nvim_win_is_valid(self.win) then
          vim.api.nvim_win_close(self.win, true)
          self.win = nil
        end
        if self.swin1 and vim.api.nvim_win_is_valid(self.swin1) then
          vim.api.nvim_win_close(self.swin1, false)
          self.swin1 = nil
        end
        if self.swin2 and vim.api.nvim_win_is_valid(self.swin2) then
          vim.api.nvim_win_close(self.swin2, false)
          self.swin2 = nil
        end
      end
    end
  end)
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
    local multi = vim.api.nvim_get_option('ambiwidth') == 'double'
    if type(border) == 'string' then
      if border == 'single' then
        w = 2
      elseif border == 'solid' then
        w = 2
      elseif border == 'double' then
        w = 2 * (multi and 2 or 1)
      elseif border == 'rounded' then
        w = 2 * (multi and 2 or 1)
      elseif border == 'shadow' then
        w = 1
      end
    elseif type(border) == 'table' then
      local b4 = type(border[4]) == 'table' and border[4][1] or border[4]
      if #b4 > 0 then
        w = w + (multi and vim.fn.strdisplaywidth(b4) > 1 and 2 or 1)
      end
      local b8 = type(border[8]) == 'table' and border[8][1] or border[8]
      if #b8 > 0 then
        w = w + (multi and vim.fn.strdisplaywidth(b8) > 1 and 2 or 1)
      end
    end
  end
  return w
end

---Get scroll height.
---@return number
window.get_content_height = function(self)
  if not self:option('wrap') then
    return vim.api.nvim_buf_line_count(self.buf)
  end

  return self.cache:ensure({
    'get_content_height',
    self.style.width,
    self.buf,
    vim.api.nvim_buf_get_changedtick(self.buf),
  }, function()
    local height = 0
    for _, text in ipairs(vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)) do
      height = height + math.ceil(math.max(1, vim.fn.strdisplaywidth(text)) / self.style.width)
    end
    return height
  end)
end

return window
