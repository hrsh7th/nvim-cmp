local async = {}

---Return guarded callback
---@return fun(fun: function): function
async.guard = function()
  local id = 0
  return function(callback)
    id = id + 1

    local own_id = id
    return function()
      if own_id ~= id then
        return
      end
      callback()
    end
  end
end

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
  return unpack(res or {})
end

---@class cmp.AsyncThrottle
---@field public timeout number
---@field public stop function
---@field public __call function

---@param fn function
---@param timeout number
---@return cmp.AsyncThrottle
async.throttle = function(fn, timeout)
  local time = nil
  local timer = vim.loop.new_timer()
  return setmetatable({
    timeout = timeout,
    stop = function()
      time = nil
      timer:stop()
    end,
  }, {
    __call = function(self)
      if time == nil then
        time = vim.loop.now()
      end
      timer:stop()

      local delta = math.max(0, self.timeout - (vim.loop.now() - time))
      timer:start(delta, 0, vim.schedule_wrap(function()
        time = nil
        fn()
      end))
    end
  })
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
  return setmetatable({
    timeout = timeout,
    stop = function()
      timer:stop()
    end,
  }, {
    __call = function(self)
      self:stop()
      if self.timeout == 0 then
        fn()
      else
        timer:start(self.timeout, 0, vim.schedule_wrap(fn))
      end
    end
  })
end

return async

