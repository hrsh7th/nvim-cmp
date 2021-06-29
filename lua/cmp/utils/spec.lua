local context = require'cmp.context'

local spec = {}

spec.before = function()
  vim.cmd [[
    bdelete!
    enew!
    setlocal virtualedit=all
  ]]
end

spec.state = function(text, row, col)
  vim.fn.setline(1, text)
  vim.fn.cursor(row, col)
  local ctx = context.empty()
  return {
    context = function()
      return ctx
    end,
    press = function(char)
      vim.fn.feedkeys(('i%s'):format(char), 'nx')
      vim.fn.feedkeys(('l'):format(char), 'nx')
      ctx.prev_context = nil
      ctx = context.new(ctx)
      return ctx
    end
  }
end

return spec

