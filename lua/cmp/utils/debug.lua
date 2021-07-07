local debug = {}

---Print log
---@vararg any
debug.log = function(...)
  local data = {}
  for _, v in ipairs({ ... }) do
    if not vim.tbl_contains({ 'string', 'number', 'boolean' }, type(v)) then
      v = vim.inspect(v)
    end
    table.insert(data, v)
  end
  print(table.concat(data, '\t'))
end

return debug
