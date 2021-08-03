local debug = {}

local flag = false

---Print log
---@vararg any
debug.log = function(...)
  if flag then
    local data = {}
    for _, v in ipairs({ ... }) do
      if not vim.tbl_contains({ 'string', 'number', 'boolean' }, type(v)) then
        v = vim.inspect(v)
      end
      table.insert(data, v)
    end
    print(table.concat(data, '\t'))
  end
end

return debug
