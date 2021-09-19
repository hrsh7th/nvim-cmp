local native = {}

native.new = function()
  local self = setmetatable({}, { __index = native })
  self.offset = -1
  self.items = {}
  return self
end

native.show = function(self, offset, items)
  self.offset = offset
  self.items = items
  vim.fn.complete(self.offset, self.items)
end

native.hide = function(self)

  vim.fn.complete(-1, {})
end

native.visible = function(self)
  return vim.fn.pumvisible() == 1
end

native.info = function(self)
  local pum = vim.fn.pum_getpos()
  return {
    row = pum.row,
    col = pum.col,
    width = pum.width + (pum.scrollbar and 1 or 0),
    height = pum.height,
    off = (pum.scrollbar and 1 or 0),
  }
end

native.select_next_item = function(self)
  if self:visible() then
    local idx = vim.fn.complete_info({ 'selected' }).selected
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

native.select_prev_item = function(self)
  if self:visible() then
    local idx = vim.fn.complete_info({ 'selected' }).selected
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

native.get_first_item = function(self)
  if self:visible() then
    return self.items[1]
  end
end

native.get_selected_item = function(self)
  if self:visible() then
    local idx = vim.fn.complete_info({ 'selected' }).selected
    if idx ~= -1 then
      return self.items[math.max(idx + 1, 1)]
    end
  end
end

return native

