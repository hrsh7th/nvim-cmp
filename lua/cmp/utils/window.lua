---@class cmp.WindowStyle
---@field public row number
---@field public col number
---@field public width number
---@field public height number

---@class cmp.Window
---@field public buf number
---@field public win number|nil
---@field public opt table<string, any>
local window = {}

---new
---@return cmp.Window
window.new = function()
  local self = setmetatable({}, { __index = window })
  self.buf = vim.api.nvim_create_buf(false, true)
  self.win = nil
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
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_set_buf(self.win, self.buf)
    vim.api.nvim_win_set_config(self.win, style)
  else
    self.win = vim.api.nvim_open_win(self.buf, false, style)
    for k, v in pairs(self.opt) do
      vim.api.nvim_win_set_option(self.win, k, v)
    end
  end
end

---Close window
window.close = function(self)
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    if self:visible() then
      vim.api.nvim_win_close(self.win, true)
    end
    self.win = nil
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
      print(vim.inspect(c.border))
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
    local a = {
      row = p[1],
      col = p[2] - o,
      width = w + o,
      height = h,
      o = o,
    }
    return a
  end
end

return window

