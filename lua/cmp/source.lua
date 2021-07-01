local context = require'cmp.context'
local misc = require'cmp.utils.misc'
local lsp = require'cmp.types.lsp'

---@class cmp.Source
---@field public id number
---@field public name string
---@field public source any
---@field public state cmp.SourceState
---@field public on_change fun(ctx: cmp.Context)
---@field public context cmp.Context
---@field public incomplete boolean
---@field public items lsp.CompletionItem[]
local source = {}

---@class cmp.ChangeKind
source.ChangeKind = {}
source.ChangeKind.UPDATE = 1
source.ChangeKind.FILTER = 2

---@class cmp.SourceState
source.SourceState = {}
source.SourceState.IDLE = 1
source.SourceState.ACTIVE = 2

---@return cmp.Source
source.new = function(name, s)
  local self = setmetatable({}, { __index = source })
  self.id = misc.id('source')
  self.name = name
  self.source = s
  self.on_change = function() end
  self:reset(context.empty())
  return self
end

---Reset current completion state
---@param ctx cmp.Context
---@return boolean
source.reset = function(self, ctx)
  self.context = context.empty()
  self.incomplete = false
  self.items = {}
  if self.state == source.SourceState.ACTIVE then
    self.state = source.SourceState.IDLE
    self.on_change(ctx, source.ChangeKind.UPDATE)
    return true
  end
  return false
end

---Subscribe source state changes
---@param on_change fun(ctx: cmp.Context)
source.subscribe = function(self, on_change)
  self.on_change = on_change
end

---Unsubscribe source state changes
source.unsubscribe = function(self)
  self.on_change = function() end
end

---Return if this source matches to current context or not.
source.match = function(self, ctx)
  if not self.source.match then
    return true
  end
  return self.source:match(ctx)
end

---Get all commit characters
---@return string[]
source.get_all_commit_characters = function(self)
  if self.source.get_all_commit_characters then
    return self.source:get_all_commit_characters() or {}
  end
  return {}
end

---Invoke completion
---@param ctx cmp.Context
---@return boolean
source.complete = function(self, ctx)
  local trigger_characters = self.source:get_trigger_characters()

  local completion_context
  if vim.tbl_contains(trigger_characters, ctx.before_char) then
    completion_context = {
      triggerKind = lsp.CompletionTriggerKind.TriggerCharacter,
      triggerCharacter = ctx.before_char,
    }
  elseif ctx:is_keyword_beginning() then
    completion_context = {
      triggerKind = lsp.CompletionTriggerKind.Invoked,
    }
  elseif self.incomplete and ctx.input ~= '' then
    completion_context = {
      triggerKind = lsp.CompletionTriggerKind.TriggerForIncompleteCompletions
    }
  else
    if ctx.input == '' then
      return self:reset(ctx)
    end
    return false
  end

  self.context = ctx
  self.source:complete({
    context = ctx,
    completion_context = completion_context,
  }, function(response)
    if self.context.id ~= ctx.id then
      return
    end
    if response and #(response.items or response) > 0 then
      self.state = source.SourceState.ACTIVE
      self.incomplete = response.isIncomplete or false
      self.items = response.items or response
      self.on_change(ctx, source.ChangeKind.UPDATE)
    elseif self.state == source.SourceState.ACTIVE then
      self.on_change(ctx, source.ChangeKind.FILTER)
    end
  end)
  return true
end

---Resolve CompletionItem
source.resolve = function(self, item, callback)
  if not self.source.resolve then
    return callback(item)
  end
  self.source:resolve(item, function(resolved_item)
    callback(resolved_item or item)
  end)
end

---Execute command
source.execute = function(self, item, callback)
  self.source:execute(item, function()
    callback()
  end)
end

return source

