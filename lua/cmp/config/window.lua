local window = {}

window.bordered = function(opts)
  opts = opts or {}
  return {
    border = opts.border or 'rounded',
    winhighlight = opts.winhighlight or 'Normal:Normal,FloatBorder:Normal,CursorLine:Visual,Search:None',
    zindex = opts.zindex or 1001,
  }
end

return window
