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
  local documentation = config.get().documentation
  if not documentation then
    return
  end

  if not e or not entries_analyzed then
    return self:close()
  end

  local right_space = vim.o.columns - (entries_analyzed.col + entries_analyzed.width) - 1
  local left_space = entries_analyzed.col - 1
  local maxwidth = math.min(documentation.maxwidth, math.max(left_space, right_space) - 1)

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
      max_width = maxwidth,
      max_height = documentation.maxheight,
    })
  end

  local content_width, content_height = vim.lsp.util._make_floating_popup_size(vim.api.nvim_buf_get_lines(self.window:get_buffer(), 0, -1, false), {
    max_width = maxwidth,
    max_height = documentation.maxheight,
  })
  if content_width <= 0 or content_height <= 0 then
    return self:close()
  end

  local docs_analyzed = window_analysis.analyze({
    row = 0,
    col = 0,
    width = content_width,
    height = content_height,
    border = config.get().window.documentation.border,
  }, self.window:get_buffer())
  if not docs_analyzed.border_info.is_visible then
    self.window:option('winhighlight', 'Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None')
  else
    self.window:option('winhighlight', 'FloatBorder:Normal,CursorLine:NormalFloat,Search:None,NormalFloat:Normal,FloatBorder:Normal')
  end

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

  self.window:open({
    relative = 'editor',
    style = 'minimal',
    width = content_width,
    height = content_height,
    border = config.get().window.documentation.border,
    row = entries_analyzed.row,
    col = col,
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
