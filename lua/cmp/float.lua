local async = require('cmp.utils.async')
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
  float.close.stop()

  local documentation = config.get().documentation
  if not documentation then
    return
  end

  local pum = vim.fn.pum_getpos() or {}
  if not pum.col then
    return self:close()
  end

  local right_space = vim.o.columns - (pum.col + pum.width + (pum.scrollbar and 1 or 0)) - 1
  local left_space = pum.col - 1
  local maxwidth = math.min(documentation.maxwidth, math.max(left_space, right_space))

  -- update buffer content if needed.
  if not self.entry or e.id ~= self.entry.id then
    local documents = e:get_documentation()
    if #documents == 0 then
      return self:close()
    end

    self.entry = e
    self.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(self.buf, 'bufhidden', 'wipe')
    vim.lsp.util.stylize_markdown(self.buf, documents, {
      max_width = maxwidth,
      max_height = documentation.maxheight,
    })
  end

  local width, height = vim.lsp.util._make_floating_popup_size(vim.api.nvim_buf_get_lines(self.buf, 0, -1, false), {
    max_width = maxwidth,
    max_height = documentation.maxheight,
  })
  if width <= 0 or height <= 0 then
    return self:close()
  end

  local right_col = pum.col + pum.width + (pum.scrollbar and 1 or 0)
  local left_col = pum.col - width - 3 -- TODO: Why is this needed -3?

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
float.close = async.throttle(
  vim.schedule_wrap(function(self)
    if self:is_visible() then
      vim.api.nvim_win_close(self.win, true)
    end
    self.entry = nil
    self.buf = nil
    self.win = nil
  end),
  20
)

float.scroll = function(self, delta)
  if self:is_visible() then
    local info = vim.fn.getwininfo(self.win)[1] or {}
    local buf = vim.api.nvim_win_get_buf(self.win)
    local top = info.topline or 1
    top = top + delta
    top = math.max(top, 1)
    top = math.min(top, vim.api.nvim_buf_line_count(buf) - info.height + 1)

    vim.defer_fn(function()
      vim.api.nvim_buf_call(buf, function()
        vim.api.nvim_command('normal! ' .. top .. 'zt')
      end)
    end, 0)
  end
end

float.is_visible = function(self)
  return self.win and vim.api.nvim_win_is_valid(self.win)
end

return float
