local cache = require('cmp.utils.cache')

---@class cmp.WindowAnalyzed
---@field public row number
---@field public col number
---@field public width number
---@field public height number
---@field public inner_width number
---@field public inner_height number
---@field public scroll_height number
---@field public border_info cmp.WindowBorderAnalyzed
---@field public scroll_info cmp.WindowScrollAnalyzed

---@class cmp.WindowBorderAnalyzed
---@field public top number
---@field public left number
---@field public right number
---@field public bottom number
---@field public horizontal number
---@field public vertical number
---@field public is_visible boolean

---@class cmp.WindowScrollAnalyzed
---@field public scrollable boolean
---@field public extra_width number

local window_analysis = {}

window_analysis.cache = cache.new()

---Return analyzed window information.
---@param style cmp.WindowStyle
---@param bufnr number
---@return cmp.WindowAnalyzed
window_analysis.analyze = function(style, bufnr)
  local scroll_height = window_analysis.get_content_height(style.width, bufnr)
  local border_info = window_analysis.get_border_info(style.border)
  local scroll_info = style.height >= scroll_height and ({
    scrollable = false,
    extra_width = 0,
  }) or (
    border_info.is_visible and ({
      scrollable = true,
      extra_width = 0,
    }) or ({
      scrollable = true,
      extra_width = 1,
    })
  )
  return {
    row = style.row,
    col = style.col,
    width = style.width + border_info.horizontal + scroll_info.extra_width,
    height = style.height + border_info.vertical,
    inner_width = style.width,
    inner_height = style.height,
    scroll_height = scroll_height,
    border_info = border_info,
    scroll_info = scroll_info,
  }
end

---Return border info.
---@param border string|string[]
---@return cmp.WindowBorderAnalyzed
window_analysis.get_border_info = function(border)
  border = border or { '' }
  return window_analysis.cache:ensure(border, function()
    local border_info = {
      top = 0,
      left = 0,
      right = 0,
      bottom = 0,
      horizontal = 0,
      vertical = 0,
      is_visible = false
    }
    if border then
      if vim.tbl_contains({ 'single', 'solid', 'double', 'rounded' }, border) then
        border_info.top = 1
        border_info.left = 1
        border_info.right = 1
        border_info.bottom = 1
        border_info.is_visible = true
      elseif border == 'shadow' then
        border_info.top = 0
        border_info.left = 0
        border_info.right = 1
        border_info.bottom = 1
        border_info.is_visible = true
      elseif type(border) == 'table' then
        local normalized_border = {}
        while #normalized_border < 8 do
          for _, b in ipairs(border) do
            table.insert(normalized_border, b)
          end
        end
        border_info.top = normalized_border[2] == '' and 0 or 1
        border_info.left = normalized_border[4] == '' and 0 or 1
        border_info.right = normalized_border[8] == '' and 0 or 1
        border_info.bottom = normalized_border[6] == '' and 0 or 1
        border_info.is_visible = not ((normalized_border[4] == '' or normalized_border[4] == ' ') and (border[8] == '' or border[8] == ' '))
      end
    end
    border_info.horizontal = border_info.left + border_info.right
    border_info.vertical = border_info.top + border_info.bottom
    return border_info
  end)
end

---Return content width.
---@param bufnr number
---@return number
window_analysis.get_content_width = function(bufnr)
  return window_analysis.cache:ensure({
    bufnr,
    vim.api.nvim_buf_get_changedtick(bufnr)
  }, function()
    local content_width = 0
    vim.api.nvim_buf_call(bufnr, function()
      for _, text in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        content_width = math.max(content_width, vim.fn.strdisplaywidth(text))
      end
    end)
    return content_width
  end)
end

---Return content height.
---@param width number
---@param bufnr number
---@return number
window_analysis.get_content_height = function(width, bufnr)
  return window_analysis.cache:ensure({
    width,
    bufnr,
    vim.api.nvim_buf_get_changedtick(bufnr)
  }, function()
    local content_height = 0
    vim.api.nvim_buf_call(bufnr, function()
      for _, text in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        content_height = content_height + math.ceil(math.max(1, vim.fn.strdisplaywidth(text) / width))
      end
    end)
    return content_height
  end)
end

return window_analysis

