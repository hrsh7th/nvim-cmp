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

return async

