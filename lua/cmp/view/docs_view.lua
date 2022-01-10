local window = require('cmp.utils.window')
local window_analysis = require('cmp.utils.window_analysis')
local config = require('cmp.config')

---@class cmp.DocsView
---@field public window cmp.Window
local docs_view = {}

---Create new floating window module
docs_view.new = function()
  local self = setmetatable({}, { __index = docs_view })
  self.entry = nil
  self.window = window.new()
  self.window:option('conceallevel', 2)
  self.window:option('concealcursor', 'n')
  self.window:option('foldenable', false)
  self.window:option('linebreak', true)
  self.window:option('scrolloff', 0)
  self.window:option('wrap', true)
  return self
end

---Open documentation window
---@param e cmp.Entry
---@param entries_analyzed cmp.WindowAnalyzed
docs_view.open = function(self, e, entries_analyzed)
  local documentation = config.get().window.documentation
  if not documentation then
    return
  end

  if not e or not entries_analyzed then
    return self:close()
  end

  -- Reserve +1 width for the scrollbar area but we try to compute border dimenstions.
  -- The presence or absence of scrollbars depends on the height of the content.
  -- However, stylize_markdown still requests max_width / max_height, even though it writes to the buffer internally.
  -- With this, it is not possible to check the presence of the scroll bar in advance and adjust the width.

  local border_info = window_analysis.get_border_info(config.get().window.documentation.border)
  local right_space = vim.o.columns - (entries_analyzed.col + entries_analyzed.width)
  local left_space = entries_analyzed.col
  local bottom_space = vim.o.lines - entries_analyzed.row
  local max_content_width = math.min(documentation.max_width, math.max(left_space, right_space)) - border_info.horizontal - 1
  local max_content_height = math.min(documentation.max_height, bottom_space) - border_info.vertical

  -- update buffer content if needed.
  if not self.entry or e.id ~= self.entry.id then
    local documents = e:get_documentation()
    if #documents == 0 then
      return self:close()
    end

    self.entry = e
    vim.api.nvim_buf_call(self.window:get_buffer(), function()
      vim.cmd([[syntax clear]])
    end)
    vim.lsp.util.stylize_markdown(self.window:get_buffer(), documents, {
      max_width = max_content_width,
      max_height = max_content_height,
    })
  end

  local content_width = math.min(max_content_width, window_analysis.get_content_width(self.window:get_buffer()))
  local content_height = math.min(max_content_height, window_analysis.get_content_height(content_width, self.window:get_buffer()))
  local docs_analyzed = window_analysis.analyze({
    row = 0,
    col = 0,
    width = content_width,
    height = content_height,
    border = documentation.border,
  }, self.window:get_buffer())

  local col
  local right_col = entries_analyzed.col + entries_analyzed.width
  local left_col = entries_analyzed.col - docs_analyzed.width
  if right_space >= docs_analyzed.width and left_space >= docs_analyzed.width then
    if right_space < left_space then
      col = left_col
    else
      col = right_col
    end
  elseif right_space >= docs_analyzed.width then
    col = right_col
  elseif left_space >= docs_analyzed.width then
    col = left_col
  else
    return self:close()
  end
  local win_mode_option = docs_analyzed.border_info.is_visible and documentation.win_mode.bordered or documentation.win_mode.default
  self.window:set_scrollbar(win_mode_option.scrollbar)
  self.window:option('winhighlight', win_mode_option.winhighlight)
  self.window:open({
    relative = 'editor',
    style = 'minimal',
    row = entries_analyzed.row,
    col = col,
    width = docs_analyzed.inner_width,
    height = docs_analyzed.inner_height,
    border = documentation.border,
    zindex = documentation.zindex or 1001,
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
    top = math.min(top, self.window:analyzed().scroll_height - info.height + 1)

    vim.defer_fn(function()
      vim.api.nvim_buf_call(self.window:get_buffer(), function()
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
