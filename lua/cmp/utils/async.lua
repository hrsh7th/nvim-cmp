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

---@class cmp.AsyncDebounce
---@field public timeout number
---@field public stop function
---@field public __call function

---Debounce specified function
---@param fn function
---@param timeout number
---@return cmp.AsyncDebounce
async.debounce = function(fn, timeout)
  local timer = vim.loop.new_timer()
  return setmetatable({}, {
    timeout = timeout,
    stop = function()
      timer:stop()
    end,
    __call = function(self)
      timer:stop()
      if self.timeout == 0 then
        fn()
      else
        timer:start(self.timeout, 0, vim.schedule_wrap(fn))
      end
    end
  })
end

return async

