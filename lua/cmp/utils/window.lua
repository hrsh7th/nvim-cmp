local window = {}

---@class cmp.Window
---@field public buf number
---@field public win number|nil

---@class cmp.WindowStyle
---@field public row number
---@field public col number
---@field public width number
---@field public height number

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

return window

