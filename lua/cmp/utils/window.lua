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
local window = {}

---new
---@return cmp.Window
window.new = function()
  local self = setmetatable({}, { __index = window })
  self.buf = vim.api.nvim_create_buf(false, true)
  self.win = nil
  self.style = nil
  self.sbuf1 = vim.api.nvim_create_buf(false, true)
  self.swin1 = nil
  self.sbuf2 = vim.api.nvim_create_buf(false, true)
  self.swin2 = nil
  self.opt = {}
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

---Open window
---@param style cmp.WindowStyle
window.open = function(self, style)
  self.style = style
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_set_buf(self.win, self.buf)
    vim.api.nvim_win_set_config(self.win, style)
  else
    self.win = vim.api.nvim_open_win(self.buf, false, style)
    for k, v in pairs(self.opt) do
      vim.api.nvim_win_set_option(self.win, k, v)
    end
  end
  self:update()
end

---Update
window.update = function(self)
  local total = vim.api.nvim_buf_line_count(self.buf)
  if self.style.height < total then
    local bar_height = math.ceil(self.style.height * (self.style.height / total))
    local bar_offset = math.min(self.style.height - bar_height, math.floor(self.style.height * (vim.fn.getwininfo(self.win)[1].topline / total)))
    local style1 = {}
    style1.relative = 'editor'
    style1.style = 'minimal'
    style1.width = 1
    style1.height = self.style.height
    style1.row = self.style.row
    style1.col = self.style.col + self.style.width
    style1.zindex = 1
    if self.swin1 and vim.api.nvim_win_is_valid(self.swin1) then
      vim.api.nvim_win_set_config(self.swin1, style1)
    else
      self.swin1 = vim.api.nvim_open_win(self.sbuf1, false, style1)
      vim.api.nvim_win_set_option(self.swin1, 'winhighlight', 'Normal:PmenuSbar')
    end
    local style2 = {}
    style2.relative = 'editor'
    style2.style = 'minimal'
    style2.width = 1
    style2.height = bar_height
    style2.row = self.style.row + bar_offset
    style2.col = self.style.col + self.style.width
    style2.zindex = 2
    if self.swin2 and vim.api.nvim_win_is_valid(self.swin2) then
      vim.api.nvim_win_set_config(self.swin2, style2)
    else
      self.swin2 = vim.api.nvim_open_win(self.sbuf2, false, style2)
      vim.api.nvim_win_set_option(self.swin2, 'winhighlight', 'Normal:PmenuSel')
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

---Return the window is visible or not.
window.visible = function(self)
  return self.win and vim.api.nvim_win_is_valid(self.win)
end

---Return win info.
window.info = function(self)
  if self:visible() then
    local p = vim.api.nvim_win_get_position(self.win)
    local w = vim.api.nvim_win_get_width(self.win)
    local h = vim.api.nvim_win_get_height(self.win)
    local c = vim.api.nvim_win_get_config(self.win)
    local o = 0
    if c.border then
      local multi = vim.api.nvim_get_option('ambiwidth') == 'double'
      if type(c.border) == 'string' then
        if c.border == 'single' then
          o = 2
        elseif c.border == 'solid' then
          o = 2
        elseif c.border == 'double' then
          o = 2 * (multi and 2 or 1)
        elseif c.border == 'rounded' then
          o = 2 * (multi and 2 or 1)
        elseif c.border == 'shadow' then
          o = 1
        end
      elseif type(c.border) == 'table' then
        local b4 = type(c.border[1]) == 'table' and c.border[4][1] or c.border[4]
        if #b4 > 0 then
          o = o + vim.fn.strdisplaywidth(b4) > 1 and multi and 2 or 1
        end
        local b8 = type(c.border[8]) == 'table' and c.border[8][1] or c.border[8]
        if #b8 > 0 then
          o = o + vim.fn.strdisplaywidth(b8) > 1 and multi and 2 or 1
        end
      end
    end
    return {
      row = p[1],
      col = p[2] - math.floor(o / 2),
      width = w + o + ((self.swin1 and vim.api.nvim_win_is_valid(self.swin1)) and 1 or 0),
      height = h,
      o = o,
    }
  end
end

return window

