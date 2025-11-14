local window = {}

window.bordered = function(opts)
  opts = opts or {}
  return {
    border = opts.border or 'rounded',
    winhighlight = opts.winhighlight or 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None',
    zindex = opts.zindex or 1001,
    scrolloff = opts.scrolloff or 0,
    col_offset = opts.col_offset or 0,
    side_padding = opts.side_padding or 1,
    scrollbar = opts.scrollbar == nil and true or opts.scrollbar,
    max_height = opts.max_height or nil,
  }
end

window.get_border = function()
  -- On neovim 0.11+, use the vim.o.winborder option by default
  local has_winborder, winborder = pcall(function()
    return vim.o.winborder
  end)
  if has_winborder and winborder ~= '' then
    return winborder
  end

  -- On lower versions return the default
  return 'none'
end

return window
