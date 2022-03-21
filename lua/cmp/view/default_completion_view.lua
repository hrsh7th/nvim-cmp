local window = require('cmp.utils.window')

local DefaultCompletionView = {}

function DefaultCompletionView.new()
  local self = setmetatable({}, { __index = DefaultCompletionView })
  self.window = window.new()
  self.entries = {}
  return self
end

---@param offset number
---@param entries cmp.Entry[]
function DefaultCompletionView:on_open(offset, entries)
  self.offset = offset
  self.entries = entries

  local widths = {
    abbr = 0,
    kind = 0,
    menu = 0,
  }
  for _, e in ipairs(entries) do
    local view = e:get_view(offset, self.window:get_buffer())
    widths.abbr = math.max(view.abbr.width, widths.abbr)
    widths.kind = math.max(view.kind.width, widths.kind)
    widths.menu = math.max(view.menu.width, widths.menu)
  end

  local lines = {}
  for _, e in ipairs(entries) do
    local view = e:get_view(offset, self.window:get_buffer())
    local line = {}
    table.insert(line, view.abbr.text .. (' '):rep(widths.abbr - view.abbr.width))
    table.insert(line, view.kind.text .. (' '):rep(widths.kind - view.kind.width))
    table.insert(line, view.menu.text .. (' '):rep(widths.menu - view.menu.width))
    table.insert(lines, table.concat(line, ''))
  end

  vim.api.nvim_buf_set_lines(self.window:get_buffer(), 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.window:get_buffer(), 'modified', false)

  self.window:open({
    relative = 'editor',
    style = 'minimal',
    row = vim.api.nvim_win_get_cursor(0)[1] + 1,
    col = offset,
    width = widths.abbr + widths.kind + widths.menu,
    height = math.min(#lines, 8),
  })
end

function DefaultCompletionView:on_close()
  self.window:close()
end

function DefaultCompletionView:on_abort()
  self.window:close()
end

function DefaultCompletionView:select(index, behavior)
end

return DefaultCompletionView
