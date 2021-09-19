local vimmenu = {}

vimmenu.new = function()
  local self = setmetatable({}, { __index = vimmenu })
  self.offset = -1
  self.items = {}
  return self
end

vimmenu.show = function(self, offset, items)
  self.offset = offset
  self.items = items
  vim.fn.complete(self.offset, self.items)
end

vimmenu.hide = function(self)
  vim.fn.complete(-1, {})
end

vimmenu.visible = function(self)
  return vim.fn.pumvisible() == 1
end

vimmenu.select_next_item = function(self)
  if self:visible() then
    local idx = vim.fn.complete_info({ 'selected' })
    if idx == -1 then
      vim.api.nvim_select_popupmenu_item(1, true, false, {})
    elseif idx < 0 then
      vim.api.nvim_select_popupmenu_item(1, true, false, {})
    elseif idx == #self.items then
      vim.api.nvim_select_popupmenu_item(-1, true, false, {})
    else
      vim.api.nvim_select_popupmenu_item(idx + 1, true, false, {})
    end
  end
end

vimmenu.select_prev_item = function(self)
  if self:visible() then
    local idx = vim.fn.complete_info({ 'selected' })
    if idx == -1 then
      vim.api.nvim_select_popupmenu_item(#self.items - 1, true, false, {})
    elseif idx < 0 then
      vim.api.nvim_select_popupmenu_item(#self.items - 1, true, false, {})
    elseif idx == 0 then
      vim.api.nvim_select_popupmenu_item(-1, true, false, {})
    else
      vim.api.nvim_select_popupmenu_item(idx - 1, true, false, {})
    end
  end
end

vimmenu.get_first_item = function(self)
  if self.window:visible() then
    return self.items[1]
  end
end

vimmenu.get_selected_item = function(self)
  if self.window:visible() and self.window:option('cursorline') then
    return self.items[vim.api.nvim_win_get_cursor(self.window.win)[1]]
  end
end

return vimmenu

