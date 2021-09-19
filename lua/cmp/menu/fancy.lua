local window = require "cmp.utils.window"

local fancy = {}

fancy.new = function()
  local self = setmetatable({}, { __index = fancy })
  self.window = window.new()
  self.window:option('conceallevel', 2)
  self.window:option('concealcursor', 'n')
  self.window:option('foldenable', false)
  self.window:option('wrap', true)
  self.window:option('scrolloff', 0)
  self.offset = -1
  self.items = {}
  return self
end

fancy.show = function(self, offset, items)
  self.offset = offset
  self.items = items
  vim.api.nvim_buf_set_lines(self.window.buf, 0, -1, false, {})
  if #items > 0 then
    local labels = { bytes = 0, items = {} }
    for i, item in ipairs(items) do
      labels.items[i] = item.abbr or item.word
      labels.bytes = math.max(labels.bytes, #labels.items[i])
    end
    local kinds = { bytes = 0, items = {} }
    for i, item in ipairs(items) do
      kinds.items[i] = (item.kind or '')
      kinds.bytes = math.max(kinds.bytes, #kinds.items[i])
    end
    local menus = { bytes = 0, items = {} }
    for i, item in ipairs(items) do
      menus.items[i] = (item.menu or '')
      menus.bytes = math.max(menus.bytes, #menus.items[i])
    end

    local lines = {}
    local width = 1
    for i = 1, #items do
      lines[i] = string.format(
        '%s %s %s',
        labels.items[i] .. string.rep(' ', labels.bytes - #labels.items[i]),
        kinds.items[i] .. string.rep(' ', kinds.bytes - #kinds.items[i]),
        menus.items[i] .. string.rep(' ', menus.bytes - #menus.items[i])
      )
      width = math.max(#lines[i], width)
    end

    vim.api.nvim_buf_set_lines(self.window.buf, 0, -1, false, lines)
    self.window:open({
      relative = 'cursor',
      style = 'minimal',
      row = 1,
      col = offset - vim.api.nvim_win_get_cursor(0)[2] - 1,
      width = width,
      height = math.min(#items, vim.api.nvim_get_option('pumheight') or #items),
    })
    self.window:option('cursorline', false)
    vim.api.nvim_win_set_cursor(self.window.win, { 1, 0 })
  else
    self.window:close()
  end
end

fancy.hide = function(self)
  self.window:close()
end

fancy.visible = function(self)
  return self.window:visible()
end

fancy.select_next_item = function(self)
  if self.window:visible() then
    local cursor = vim.api.nvim_win_get_cursor(self.window.win)[1]
    if not self.window:option('cursorline') then
      self.window:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.window.win, { 1, 0 })
    elseif cursor == #self.items then
      self.window:option('cursorline', false)
      vim.api.nvim_win_set_cursor(self.window.win, { 1, 0 })
    else
      self.window:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.window.win, { cursor + 1, 0 })
    end
  end
end

fancy.select_prev_item = function(self)
  if self.window:visible() then
    local cursor = vim.api.nvim_win_get_cursor(self.window.win)[1]
    if not self.window:option('cursorline') then
      self.window:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.window.win, { #self.items, 0 })
    elseif cursor == 1 then
      self.window:option('cursorline', false)
      vim.api.nvim_win_set_cursor(self.window.win, { 1, 0 })
    else
      self.window:option('cursorline', true)
      vim.api.nvim_win_set_cursor(self.window.win, { cursor - 1, 0 })
    end
  end
end

fancy.get_first_item = function(self)
  if self.window:visible() then
    return self.items[1]
  end
end

fancy.get_selected_item = function(self)
  if self.window:visible() and self.window:option('cursorline') then
    return self.items[vim.api.nvim_win_get_cursor(self.window.win)[1]]
  end
end

return fancy
