local context = {}

---Check if cursor is in syntax group
---@param group string | []string
---@return boolean
context.in_syntax_group = function(group)
  local lnum, col = vim.fn.line('.'), math.min(vim.fn.col('.'), #vim.fn.getline('.'))
  for _, syn_id in ipairs(vim.fn.synstack(lnum, col)) do
    syn_id = vim.fn.synIDtrans(syn_id) -- Resolve :highlight links
    local g = vim.fn.synIDattr(syn_id, 'name')
    if type(group) == 'string' and g == group then
      return true
    elseif type(group) == 'table' and vim.tbl_contains(group, g) then
      return true
    end
  end
  return false
end

---Check if cursor is in treesitter capture
---@param capture string | []string
---@return boolean
context.in_treesitter_capture = function(capture)
  local captures_at_cursor = require('vim.treesitter').get_captures_at_cursor()

  if vim.tbl_isempty(captures_at_cursor) then
    return false
  elseif type(capture) == 'string' and vim.tbl_contains(captures_at_cursor, capture) then
    return true
  elseif type(capture) == 'table' then
    for _, v in ipairs(capture) do
      if vim.tbl_contains(captures_at_cursor, v) then
        return true
      end
    end
  end

  return false
end

return context
