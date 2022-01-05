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
---@param entries_info cmp.WindowInfo
docs_view.open = function(self, e, entries_info)
  local documentation = config.get().documentation
  if not documentation then
    return
  end

  if not e or not entries_info then
    return self:close()
  end

  local right_space = vim.o.columns - (entries_info.col + entries_info.width) - 1
  local left_space = entries_info.col - 1
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

  self.window:set_style({
    relative = 'editor',
    style = 'minimal',
    width = content_width,
    height = content_height,
    row = entries_info.row,
    col = 0, -- determine later.
  })
  local docs_info = self.window:info()
  if not docs_info.border_info.is_visible then
    self.window:option('winhighlight', 'Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None')
  else
    self.window:option('winhighlight', 'FloatBorder:Normal,CursorLine:NormalFloat,Search:None,NormalFloat:Normal,FloatBorder:Normal')
  end

  local right_col = entries_info.col + entries_info.width
  local left_col = entries_info.col - docs_info.width
  if right_space >= docs_info.width and left_space >= docs_info.width then
    if right_space < left_space then
      self.window.style.col = left_col
    else
      self.window.style.col = right_col
    end
  elseif right_space >= docs_info.width then
    self.window.style.col = right_col
  elseif left_space >= docs_info.width then
    self.window.style.col = left_col
  else
    return self:close()
  end
  self.window:open(self.window.style)
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
