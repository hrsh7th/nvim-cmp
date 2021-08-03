local context = require'cmp.context'
local source  = require 'cmp.source'
local types = require('cmp.types')

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
  local s = source.new('spec', {
    complete = function()
    end
  })
  return {
    context = function()
      return ctx
    end,
    source = function()
      return s
    end,
    press = function(char)
      vim.fn.feedkeys(('i%s'):format(char), 'nx')
      vim.fn.feedkeys(('l'):format(char), 'nx')
      ctx.prev_context = nil
      ctx = context.new(ctx, { reason = types.cmp.ContextReason.Manual })
      s:complete(ctx, function() end)
      return ctx
    end
  }
end

return spec

