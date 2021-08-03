local keymap = require('cmp.utils.keymap')
local types = require('cmp.types')

local patch = {}

---@type table<number, function>
patch.callbacks = {}

---Apply oneline textEdit
---@param ctx cmp.Context
---@param range lsp.Range
---@param word string
---@param callback function
patch.apply = function(ctx, range, word, callback)
  local ok = true
  ok = ok and range.start.line == ctx.cursor.row - 1
  ok = ok and range.start.line == range['end'].line
  if not ok then
    error("text_edit's range must be current one line.")
  end
  range = types.lsp.Range.to_vim(ctx.bufnr, range)

  local before = string.sub(ctx.cursor_before_line, range.start.col)
  local after = string.sub(ctx.cursor_after_line, ctx.cursor.col, range['end'].col)
  local before_len = vim.fn.strchars(before)
  local after_len = vim.fn.strchars(after)
  local keys = string.rep('<Left>', after_len) .. string.rep('<BS>', after_len + before_len) .. word
  keymap.feedkeys(keys, 'n', callback)
end

return patch

