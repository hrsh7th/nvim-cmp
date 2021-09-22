local window = require('cmp.utils.window')
local config = require('cmp.config')

---@class cmp.DocsView
---@field public window cmp.Window
local docs_view = {}

---Create new floating window module
docs_view.new = function()
  local self = setmetatable({}, { __index = docs_view })
  self.entry = nil
  self.window = window.new()
  self.window:option('scrolloff', 0)
  return self
end

---Open documentation window
---@param e cmp.Entry
---@param view cmp.WindowStyle
docs_view.open = function(self, e, view)
  local documentation = config.get().documentation
  if not documentation then
    return
  end

  if not e then
    return self:close()
  end

  local right_space = vim.o.columns - (view.col + view.width) - 1
  local left_space = view.col - 1
  local maxwidth = math.min(documentation.maxwidth, math.max(left_space, right_space))

  -- update buffer content if needed.
  if not self.entry or e.id ~= self.entry.id then
    local documents = e:get_documentation()
    if #documents == 0 then
      return self:close()
    end

    self.entry = e
    vim.lsp.util.stylize_markdown(self.window.buf, documents, {
      max_width = maxwidth,
      max_height = documentation.maxheight,
    })
  end

  local width, height = vim.lsp.util._make_floating_popup_size(vim.api.nvim_buf_get_lines(self.window.buf, 0, -1, false), {
    max_width = maxwidth,
    max_height = documentation.maxheight,
  })
  if width <= 0 or height <= 0 then
    return self:close()
  end

  local right_col = view.col + view.width
  local left_col = view.col - width - 2

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

  self.window:option('winhighlight', documentation.winhighlight)
  self.window:open({
    relative = 'editor',
    style = 'minimal',
    width = width,
    height = height,
    row = view.row,
    col = col,
    border = documentation.border,
  })
end

---Close floating window
docs_view.close = function(self)
  self.window:close()
  self.entry = nil
end

docs_view.scroll = function(self, delta)
  if self:visible() then
    local info = vim.fn.getwininfo(self.window.win)[1] or {}
    local top = info.topline or 1
    top = top + delta
    top = math.max(top, 1)
    top = math.min(top, self.window:get_content_height() - info.height + 1)

    vim.defer_fn(function()
      vim.api.nvim_buf_call(self.window.buf, function()
        vim.api.nvim_command('normal! ' .. top .. 'zt')
        self.window:update()
      end)
    end, 0)
  end
end

docs_view.visible = function(self)
  return self.window:visible()
end

return docs_view