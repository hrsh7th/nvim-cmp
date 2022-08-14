local event = require "cmp.utils.event"

---@class cmp.ViewContext
---@field public event cmp.Event
local ViewContext = {}

function ViewContext.new()
  local self = setmetatable({}, { __index = ViewContext })
  self.event = event.new()
  return self
end

---@param callback fun(context: cmp.ViewContext)
function ViewContext:on_show(callback)
  self.event:on('show', callback)
end

---@param callback fun(context: cmp.ViewContext)
function ViewContext:on_hide(callback)
  self.event:on('hide', callback)
end

---@param callback fun(context: cmp.ViewContext)
function ViewContext:on_select(callback)
  self.event:on('select', callback)
end

return ViewContext

