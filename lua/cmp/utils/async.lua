local async = {}

---Return sync callback
---@param timeout number
---@param callback fun()
async.sync = function(timeout, callback)
  local sync = false
  return setmetatable({
    wait = function()
      vim.wait(timeout, function()
        return sync
      end)
    end
  }, {
    __call = function(_, ...)
      if callback then
        callback(...)
      end
      sync = true
    end
  })
end

return async
