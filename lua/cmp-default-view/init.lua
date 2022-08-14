
---@class cmp-default-menu-view.Option
---@field public border string|string[]
---@field public highlight string|table<string,string>

local View = {}
View.__index = View

---@param option cmp-default-menu-view.Option
function View.new(option)
  local self = setmetatable({}, View)
  self.option = option
  return self
end

---@param context cmp.ViewContext
function View:show(context)
end

---@param context cmp.ViewContext
function View:hide(context)
end

---@param context cmp.ViewContext
function View:select(context)
end

---@param option cmp-default-menu-view.Option
return function(option)
  local view = View.new(option)

  ---@param context cmp.ViewContext
  return function(context)
    context:on_show(function()
      view:show(context)
    end)
    context:on_hide(function()
      view:hide(context)
    end)
    context:on_select(function()
      view:select(context)
    end)
  end
end

