local async = {}

---Return sync callback
---@param runner fun()
---@param timeout number
async.sync = function(runner, timeout)
  local fin = false
  local res
  runner(function(...)
    fin = true
    res = { ... }
  end)
  vim.wait(timeout, function()
    return fin
  end)
  return unpack(res)
end

return async
