local Highlight = require('cmp.kit._.Vim.Highlight')

local Buffer = {}

---Ensure buffer number.
---NOTE: This function only supports '%' as special symbols.
---NOTE: This function uses `vim.fn.bufload`. It can cause side-effect.
---@param expr string|number
---@return number
function Buffer.ensure(expr)
  if type(expr) == 'number' then
    if not vim.api.nvim_buf_is_valid(expr) then
      error(string.format([=[[kit.Vim.Buffer] expr=`%s` is not a valid]=], expr))
    end
  else
    if expr == '%' then
      expr = vim.api.nvim_get_current_buf()
    end
    if vim.fn.bufexists(expr) == 0 then
      expr = vim.fn.bufadd(expr)
      vim.api.nvim_buf_set_option(expr, 'buflisted', true)
    else
      expr = vim.fn.bufnr(expr)
    end
  end
  if not vim.api.nvim_buf_is_loaded(expr) then
    vim.fn.bufload(expr)
  end
  return expr
end

---Get buffer line.
---@param expr string|number
---@param line number
---@return string
function Buffer.at(expr, line)
  return vim.api.nvim_buf_get_lines(Buffer.ensure(expr), line, line + 1, false)[1] or ''
end

---Open buffer.
---@param cmd table # The `new` command argument. See :help nvim_parse_cmd()`
---@param range? cmp.kit.LSP.Range
function Buffer.open(cmd, range)
  vim.cmd.new(cmd)

  local Range = require('cmp.kit.LSP.Range')
  if range and Range.is(range) and not Range.empty(range) then
    vim.api.nvim_win_set_cursor(0, { range.start.line + 1, range.start.character })
    Highlight.blink(range)
  end
end

return Buffer
