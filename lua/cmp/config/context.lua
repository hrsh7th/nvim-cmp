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
  local highlighter = require('vim.treesitter.highlighter')
  local ts_utils = require('nvim-treesitter.ts_utils')
  local buf = vim.api.nvim_get_current_buf()

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  if vim.api.nvim_get_mode().mode == 'i' then
    col = col - 1
  end

  local self = highlighter.active[buf]
  if not self then
    return false
  end

  local match = false

  self.tree:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end

    local root = tstree:root()
    local root_start_row, _, root_end_row, _ = root:range()
    if root_start_row > row or root_end_row < row then
      return
    end

    local query = self:get_query(tree:lang())
    if not query:query() then
      return
    end

    local iter = query:query():iter_captures(root, self.bufnr, row, row + 1)
    for the_capture, node, _ in iter do
      local hl = query.hl_cache[the_capture]

      if hl and ts_utils.is_in_node_range(node, row, col) then
        local c = query._query.captures[the_capture] -- name of the capture in the query
        if type(capture) == 'string' and c == capture then
          match = true
          return
        elseif type(capture) == 'table' and vim.tbl_contains(capture, c) then
          match = true
          return
        end
      end
    end
  end, true)

  return match
end

return context
