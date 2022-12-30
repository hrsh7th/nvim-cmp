local TreeSitter = {}

---@alias cmp.kit._.Vim.TreeSitter.VisitStatus 'stop'|'skip'
TreeSitter.VisitStatus = {}
TreeSitter.VisitStatus.Stop = 'stop'
TreeSitter.VisitStatus.Skip = 'skip'

---Get the leaf node at the specified position.
---@param row integer # 0-based
---@param col integer # 0-based
---@return userdata?
function TreeSitter.get_node_at(row, col)
  local parser = TreeSitter.get_parser()
  if not parser then
    return
  end

  for _, tree in ipairs(parser:trees()) do
    local node = tree:root():descendant_for_range(row, col, row, col)
    if node then
      local leaf = TreeSitter.get_first_leaf(node)
      if leaf then
        return leaf
      end
    end
  end
end

---Get first leaf node within the specified node.
---@param node userdata
---@return userdata?
function TreeSitter.get_first_leaf(node)
  if node:child_count() > 0 then
    return TreeSitter.get_first_leaf(node:child(0))
  end
  return node
end

---Get last leaf node within the specified node.
---@param node userdata
---@return userdata?
function TreeSitter.get_last_leaf(node)
  if node:child_count() > 0 then
    return TreeSitter.get_last_leaf(node:child(node:child_count() - 1))
  end
  return node
end

---Get next leaf node.
---@param node userdata
---@return userdata?
function TreeSitter.get_next_leaf(node)
  local function next(node_)
    local next_sibling = node_:next_sibling()
    if next_sibling then
      return TreeSitter.get_first_leaf(next_sibling)
    else
      local parent = node_:parent()
      while parent do
        next_sibling = parent:next_sibling()
        if next_sibling then
          return TreeSitter.get_first_leaf(next_sibling)
        end
        parent = parent:parent()
      end
    end
  end

  return next(TreeSitter.get_first_leaf(node))
end

---Get prev leaf node.
---@param node userdata
---@return userdata
function TreeSitter.get_prev_leaf(node)
  local function prev(node_)
    local prev_sibling = node_:prev_sibling()
    if prev_sibling then
      return TreeSitter.get_last_leaf(prev_sibling)
    else
      local parent = node_:parent()
      while parent do
        prev_sibling = parent:prev_sibling()
        if prev_sibling then
          return TreeSitter.get_last_leaf(prev_sibling)
        end
        parent = parent:parent()
      end
    end
  end

  return prev(TreeSitter.get_last_leaf(node))
end

---Return the node contained the position or not.
---@param node userdata
---@param row integer # 0-based
---@param col integer # 0-based
---@param option { s: boolean, e: boolean }
---@return boolean
function TreeSitter.within(node, row, col, option)
  option = option or {}
  option.s = option.s ~= nil and option.s or true
  option.e = option.e ~= nil and option.e or false

  local s_row, s_col, e_row, e_col = node:range()
  local s_in = s_row < row or (s_row == row and (option.s and (s_col <= col) or (s_col < col)))
  local e_in = row < e_row or (row == e_row and (option.e and (col <= e_col) or (col < e_col)))
  return s_in and e_in
end

---Extract nodes that matched the specified mapping.
---@param scope userdata
---@param mapping table
---@return userdata[]
function TreeSitter.extract(scope, mapping)
  local nodes = {}
  for node_type, next_mapping in pairs(mapping) do
    if node_type == scope:type() then
      if type(next_mapping) == 'table' then
        for c in scope:iter_children() do
          for _, node in ipairs(TreeSitter.extract(c, next_mapping)) do
            table.insert(nodes, node)
          end
        end
      elseif next_mapping == true then
        table.insert(nodes, scope)
      end
    end
  end
  return nodes
end

---Return the node is matched the specified mapping.
---@param node userdata
---@param mapping table
---@return userdata?
function TreeSitter.matches(node, mapping)
  local parent = node
  while parent do
    if vim.tbl_contains(TreeSitter.extract(parent, mapping), node) then
      return parent
    end
    parent = parent:parent()
  end
end

---Search next specific node.
---@param node userdata
---@param predicate fun(node: userdata): boolean
---@return userdata?
function TreeSitter.search_next(node, predicate)
  local current = node
  while current do
    -- down search.
    local matched = nil
    TreeSitter.visit(current, function(node_)
      if node ~= node_ and predicate(node_) then
        matched = node_
        return TreeSitter.VisitStatus.Stop
      end
    end)
    if matched then
      return matched
    end

    -- up search.
    while current do
      local next_sibling = current:next_sibling()
      if next_sibling then
        current = next_sibling
        break
      end
      current = current:parent()
    end
  end
end

---Search specific parent node.
---@param node userdata
---@param predicate fun(node: userdata): boolean
---@return userdata?
function TreeSitter.search_parent(node, predicate)
  local parent = node:parent()
  while parent do
    if predicate(parent) then
      return parent
    end
    parent = parent:parent()
  end
end

---Get all parents.
---@param node userdata
---@return userdata[]
function TreeSitter.parents(node)
  local parents = {}
  while node do
    table.insert(parents, 1, node)
    node = node:parent()
  end
  return parents
end

---Visit all nodes.
---@param scope userdata
---@param predicate fun(node: userdata, ctx: { depth: integer }): boolean
---@param option? { reversed: boolean }
function TreeSitter.visit(scope, predicate, option)
  option = option or { reversed = false }

  local function visit(node, ctx)
    if not node then
      return true
    end

    local status = predicate(node, ctx)
    if status == TreeSitter.VisitStatus.Stop then
      return status -- stop visitting.
    elseif status ~= TreeSitter.VisitStatus.Skip then
      local init, last, step
      if option.reversed then
        init, last, step = node:child_count() - 1, 0, -1
      else
        init, last, step = 0, node:child_count() - 1, 1
      end
      for i = init, last, step do
        if visit(node:child(i), { depth = ctx.depth + 1 }) == TreeSitter.VisitStatus.Stop then
          return TreeSitter.VisitStatus.Stop
        end
      end
    end
  end

  return visit(scope, { depth = 1 })
end

---Return the node is matched the specified capture.
---@param query userdata
---@param node userdata
---@return boolean
function TreeSitter.is_capture(query, node, capture)
  for id, match in query:iter_captures(node:parent()) do
    if match:id() == node:id() and query.captures[id] == capture then
      return true
    end
  end
  return false
end

---Get node text.
---@param node userdata
---@return string[]
function TreeSitter.get_node_text(node)
  local ok, text = pcall(function()
    local args = { 0, node:range() }
    table.insert(args, {})
    return vim.api.nvim_buf_get_text(unpack(args))
  end)
  if not ok then
    return { '' }
  end
  return text
end

---Get parser.
---@return table
function TreeSitter.get_parser()
  return vim.treesitter.get_parser(0, vim.api.nvim_buf_get_option(0, 'filetype'))
end

---Dump node or node-table.
---@param node userdata|userdata[]
function TreeSitter.dump(node)
  if not node then
    return print(node)
  end

  if type(node) == 'table' then
    if #node == 0 then
      return print('empty table')
    end
    for _, v in ipairs(node) do
      TreeSitter.dump(v)
    end
    return
  end

  local message = node:type()
  local current = node:parent()
  while current do
    message = current:type() .. ' ~ ' .. message
    current = current:parent()
    if not current then
      break
    end
  end
  print(message)
end

return TreeSitter
