local kit = require('cmp.kit')

local Syntax = {}

---Get all syntax groups for specified position.
---NOTE: This function accepts 0-origin cursor position.
---@param cursor number[]
---@return string[]
function Syntax.get_syntax_groups(cursor)
  return kit.concat(Syntax.get_vim_syntax_groups(cursor), Syntax.get_treesitter_syntax_groups(cursor))
end

---Get vim's syntax groups for specified position.
---NOTE: This function accepts 0-origin cursor position.
---@param cursor number[]
---@return string[]
function Syntax.get_vim_syntax_groups(cursor)
  local unique = {}
  local groups = {}
  for _, syntax_id in ipairs(vim.fn.synstack(cursor[1] + 1, cursor[2] + 1)) do
    local name = vim.fn.synIDattr(vim.fn.synIDtrans(syntax_id), 'name')
    if not unique[name] then
      unique[name] = true
      table.insert(groups, name)
    end
  end
  for _, syntax_id in ipairs(vim.fn.synstack(cursor[1] + 1, cursor[2] + 1)) do
    local name = vim.fn.synIDattr(syntax_id, 'name')
    if not unique[name] then
      unique[name] = true
      table.insert(groups, name)
    end
  end
  return groups
end

---Get tree-sitter's syntax groups for specified position.
---NOTE: This function accepts 0-origin cursor position.
---@param cursor number[]
---@return string[]
function Syntax.get_treesitter_syntax_groups(cursor)
  local groups = {}
  for _, capture in ipairs(vim.treesitter.get_captures_at_pos(0, cursor[1], cursor[2])) do
    table.insert(groups, ('@%s'):format(capture.capture))
  end
  return groups
end

return Syntax
