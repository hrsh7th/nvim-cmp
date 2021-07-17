local config = require('cmp.config')

---@class cmp.Float
---@field public entry cmp.Entry|nil
---@field public buf number|nil
---@field public win number|nil
local float = {}

---Create new floating window module
float.new = function()
  local self = setmetatable({}, { __index = float })
  self.entry = nil
  self.win = nil
  self.buf = nil
  return self
end

---Show floating window
---@param e cmp.Entry
float.show = function(self, e)
  local documentation = config.get().documentation

  -- update buffer content if needed.
  if not self.entry or e.id ~= self.entry.id then
    self.entry = e
    self.buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_option(self.buf, 'bufhidden', 'wipe')

    local documents = e:get_documentation()
    if #documents == 0 then
      return self:close()
    end
    vim.lsp.util.stylize_markdown(self.buf, documents, {
      max_width = documentation.maxwidth,
      max_height = documentation.maxheight,
    })
  end

  local width, height = vim.lsp.util._make_floating_popup_size(vim.api.nvim_buf_get_lines(self.buf, 0, -1, false), {
    max_width = documentation.maxwidth,
    max_height = documentation.maxheight,
  })
  if width <= 0 or height <= 0 then
    return self:close()
  end

  local pum = vim.fn.pum_getpos() or {}
  if not pum.col then
    return self:close()
  end

  local right_col = pum.col + pum.width + (pum.scrollbar and 1 or 0)
  local right_space = vim.o.columns - right_col - 1
  local left_col = pum.col - width - 3 -- TODO: Why is this needed -3?
  local left_space = pum.col - 1

  local col
  if right_space >= width and left_space >= width then
    if right_space < left_space then
      col = left_col
    else
      col = right_col
    end
  elseif right_space >= width then
    col = right_col
  elseif left_space >= width then
    col = left_col
  else
    return self:close()
  end

  local style = {
    relative = 'editor',
    style = 'minimal',
    width = width,
    height = height,
    row = pum.row,
    col = col,
    border = documentation.border,
  }

  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_set_buf(self.win, self.buf)
    vim.api.nvim_win_set_config(self.win, style)
  else
    self.win = vim.api.nvim_open_win(self.buf, false, style)
    vim.api.nvim_win_set_option(self.win, 'conceallevel', 2)
    vim.api.nvim_win_set_option(self.win, 'concealcursor', 'n')
    vim.api.nvim_win_set_option(self.win, 'winhighlight', config.get().documentation.winhighlight)
    vim.api.nvim_win_set_option(self.win, 'foldenable', false)
    vim.api.nvim_win_set_option(self.win, 'wrap', true)
    vim.api.nvim_win_set_option(self.win, 'scrolloff', 0)
  end
end

---Close floating window
float.close = function(self)
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  self.entry = nil
  self.buf = nil
  self.win = nil
end

return float
