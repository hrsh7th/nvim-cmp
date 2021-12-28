local misc = {}

---Create once callback
---@param callback function
---@return function
misc.once = function(callback)
  local done = false
  return function(...)
    if done then
      return
    end
    done = true
    callback(...)
  end
end

---Checks if cursor is inside a comment
---@return boolean
misc.is_inside_comment = function()
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
    return {}
  end

  local matches = {}

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

    for capture, node, _ in iter do
      local hl = query.hl_cache[capture]

      if hl and ts_utils.is_in_node_range(node, row, col) then
        local c = query._query.captures[capture] -- name of the capture in the query
        if c ~= nil then
          local general_hl = query:_get_hl_from_capture(capture)
          table.insert(matches, general_hl)
        end
      end
    end
  end, true)
  local lnum, col = vim.fn.line('.'), math.min(vim.fn.col('.'), #vim.fn.getline('.'))
  for _, syn_id in ipairs(vim.fn.synstack(lnum, col)) do
    syn_id = vim.fn.synIDtrans(syn_id) -- Resolve :highlight links
    if vim.fn.synIDattr(syn_id, 'name') == 'Comment' then
      return true
    end
  end
  return vim.tbl_contains(matches, 'TSComment')
end

---Return concatenated list
---@param list1 any[]
---@param list2 any[]
---@return any[]
misc.concat = function(list1, list2)
  local new_list = {}
  for _, v in ipairs(list1) do
    table.insert(new_list, v)
  end
  for _, v in ipairs(list2) do
    table.insert(new_list, v)
  end
  return new_list
end

---The symbol to remove key in misc.merge.
misc.none = vim.NIL

---Merge two tables recursively
---@generic T
---@param v1 T
---@param v2 T
---@return T
misc.merge = function(v1, v2)
  local merge1 = type(v1) == 'table' and (not vim.tbl_islist(v1) or vim.tbl_isempty(v1))
  local merge2 = type(v2) == 'table' and (not vim.tbl_islist(v2) or vim.tbl_isempty(v2))
  if merge1 and merge2 then
    local new_tbl = {}
    for k, v in pairs(v2) do
      new_tbl[k] = misc.merge(v1[k], v)
    end
    for k, v in pairs(v1) do
      if v2[k] == nil and v ~= misc.none then
        new_tbl[k] = v
      end
    end
    return new_tbl
  end
  if v1 == misc.none then
    return nil
  end
  if v1 == nil then
    if v2 == misc.none then
      return nil
    else
      return v2
    end
  end
  if v1 == true then
    if merge2 then
      return v2
    end
    return {}
  end

  return v1
end

---Generate id for group name
misc.id = setmetatable({
  group = {},
}, {
  __call = function(_, group)
    misc.id.group[group] = misc.id.group[group] or vim.loop.now()
    misc.id.group[group] = misc.id.group[group] + 1
    return misc.id.group[group]
  end,
})

---Check the value is nil or not.
---@param v boolean
---@return boolean
misc.safe = function(v)
  if v == nil or v == vim.NIL then
    return nil
  end
  return v
end

---Treat 1/0 as bool value
---@param v boolean|"1"|"0"
---@param def boolean
---@return boolean
misc.bool = function(v, def)
  if misc.safe(v) == nil then
    return def
  end
  return v == true or v == 1
end

---Set value to deep object
---@param t table
---@param keys string[]
---@param v any
misc.set = function(t, keys, v)
  local c = t
  for i = 1, #keys - 1 do
    local key = keys[i]
    c[key] = misc.safe(c[key]) or {}
    c = c[key]
  end
  c[keys[#keys]] = v
end

---Copy table
---@generic T
---@param tbl T
---@return T
misc.copy = function(tbl)
  if type(tbl) ~= 'table' then
    return tbl
  end

  if vim.tbl_islist(tbl) then
    local copy = {}
    for i, value in ipairs(tbl) do
      copy[i] = misc.copy(value)
    end
    return copy
  end

  local copy = {}
  for key, value in pairs(tbl) do
    copy[key] = misc.copy(value)
  end
  return copy
end

---Safe version of vim.str_utfindex
---@param text string
---@param vimindex number|nil
---@return number
misc.to_utfindex = function(text, vimindex)
  vimindex = vimindex or #text + 1
  return vim.str_utfindex(text, math.max(0, math.min(vimindex - 1, #text)))
end

---Safe version of vim.str_byteindex
---@param text string
---@param utfindex number
---@return number
misc.to_vimindex = function(text, utfindex)
  utfindex = utfindex or #text
  for i = utfindex, 1, -1 do
    local s, v = pcall(function()
      return vim.str_byteindex(text, i) + 1
    end)
    if s then
      return v
    end
  end
  return utfindex + 1
end

---Mark the function as deprecated
misc.deprecated = function(fn, msg)
  local printed = false
  return function(...)
    if not printed then
      print(msg)
      printed = true
    end
    return fn(...)
  end
end

return misc
