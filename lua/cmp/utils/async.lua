local async = {}

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
    __call = function(self, ...)
      local args = { ... }

      time = time or vim.loop.now()

      local delta = math.max(1, self.timeout - (vim.loop.now() - time))
      timer:stop()
      timer:start(delta, 0, function()
        time = nil
        fn(unpack(args))
      end)
    end,
  })
end

---Control async tasks.
async.step = function(...)
  local tasks = { ... }
  local next
  next = function(...)
    if #tasks > 0 then
      table.remove(tasks, 1)(next, ...)
    end
  end
  table.remove(tasks, 1)(next)
end

---@alias cmp.AsyncDedup fun(callback: function): function
---Create deduplicated callback
---@generic T
---@return fun(callback: T): T
async.dedup = function()
  local id = 0
  return function(callback)
    id = id + 1

    local current = id
    return function(...)
      if current == id then
        callback(...)
      end
    end
  end
end

---Convert async process as sync
async.sync = function(runner, timeout)
  local done = false
  runner(function()
    done = true
  end)
  vim.wait(timeout, function()
    return done
  end, 10, false)
end

---Invoke timeout timer.
---@param callback function
---@param timeout number
---@return {}
async.set_timeout = function(callback, timeout)
  local timer = vim.loop.new_timer()
  timer:start(timeout, 0, function()
    timer:stop()
    vim.schedule(function()
      if not timer:is_closing() then
        callback()
      end
    end)
  end)
  return timer
end

---Clear timeout timer.
---@param timer {}
async.clear_timeout = function(timer)
  if not timer then
    return
  end
  if timer:is_active() then
    timer:stop()
  end
  if not timer:is_closing() then
    timer:close()
  end
end

---Invoke interval timer.
---@param callback function
---@param interval number
---@return {}
async.set_interval = function(callback, interval)
  local doing = false
  local timer = vim.loop.new_timer()
  timer:start(0, interval, function()
    if doing then
      return
    end
    doing = true
    vim.schedule(function()
      doing = false
      if not timer:is_closing() then
        callback()
      end
    end)
  end)
  return timer
end

---Clear interval timer
---@param timer {}
async.clear_interval = function(timer)
  if not timer then
    return
  end
  if timer:is_active() then
    timer:stop()
  end
  if not timer:is_closing() then
    timer:close()
  end
end

return async

