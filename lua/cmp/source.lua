local context = require('cmp.context')
local matcher = require('cmp.matcher')
local config = require('cmp.config')
local entry = require('cmp.entry')
local binary = require('cmp.utils.binary')
local debug = require('cmp.utils.debug')
local misc = require('cmp.utils.misc')
local cache = require('cmp.utils.cache')
local lsp = require('cmp.types.lsp')

---@class cmp.Source
---@field public id number
---@field public name string
---@field public source any
---@field public cache cmp.Cache
---@field public revision number
---@field public context cmp.Context
---@field public trigger_kind lsp.CompletionTriggerKind|nil
---@field public incomplete boolean
---@field public entries cmp.Entry[]
---@field public offset number|nil
---@field public status cmp.SourceStatus
local source = {}

---@alias cmp.SourceStatus "1" | "2" | "3"
source.SourceStatus = {}
source.SourceStatus.WAITING = 1
source.SourceStatus.FETCHING = 2
source.SourceStatus.COMPLETED = 3

---@alias cmp.SourceChangeKind "1" | "2" | "3"
source.SourceChangeKind = {}
source.SourceChangeKind.RETRIEVE = 1
source.SourceChangeKind.CONTINUE = 2

---@return cmp.Source
source.new = function(name, s)
  local self = setmetatable({}, { __index = source })
  self.id = misc.id('source')
  self.name = name
  self.source = s
  self.cache = cache.new()
  self.revision = 0
  self:reset()
  return self
end

---Reset current completion state
---@return boolean
source.reset = function(self)
  self.cache:clear()
  self.revision = self.revision + 1
  self.context = context.empty()
  self.trigger_kind = nil
  self.incomplete = false
  self.entries = {}
  self.offset = nil
  self.status = source.SourceStatus.WAITING
end

---Return if this source matches to current context or not.
source.match = function(self, ctx)
  if not self.source.match then
    return true
  end
  return self.source:match(ctx)
end

---Return the source has items or not.
---@return boolean
source.has_items = function(self)
  return self.offset ~= nil
end

---Return filtered entries
---@param ctx cmp.Context
---@return cmp.Entry[]
source.get_entries = function(self, ctx)
  if not self:has_items() then
    return {}
  end

  local prev_entries = (function()
    local key = { 'get_entries', self.revision }
    for i = ctx.cursor.col, self.offset + 1, -1 do
      key[3] = string.sub(ctx.cursor_before_line, 1, i)
      local prev_entries = self.cache:get(key)
      if prev_entries then
        return prev_entries
      end
    end
    return nil
  end)()

  return self.cache:ensure({ 'get_entries', self.revision, ctx.cursor_before_line }, function()
    local inputs = {}
    local entries = {}
    debug.log('filter', self.name, self.id, #(prev_entries or self.entries))
    local targets = prev_entries or self.entries
    for _, e in ipairs(targets) do
      if not inputs[e:get_offset()] then
        inputs[e:get_offset()] = string.sub(ctx.cursor_before_line, e:get_offset())
      end
      e.score = matcher.match(inputs[e:get_offset()], e:get_filter_text(), {
        max_word_bound = #targets > 2000 and 1 or 100,
        prefix_start_offset = e:get_word_start_offset(),
      })
      if e.score >= 1 then
        binary.insort(entries, e, config.get().compare)
      end
    end
    return entries
  end)
end

---Find entry by id
---@param id number
---@return cmp.Entry|nil
source.find_entry_by_id = function(self, id)
  for _, e in ipairs(self.entries) do
    if e.id == id then
      return e
    end
  end
  return nil
end

---Get trigger_characters
---@return string[]
source.get_trigger_characters = function(self)
  if self.source.get_trigger_characters then
    return self.source:get_trigger_characters() or {}
  end
  return {}
end

---Invoke completion
---@param ctx cmp.Context
---@param callback function
---@return boolean Return true if not trigger completion.
source.complete = function(self, ctx, callback)
  if self.offset then
    if not ctx:maybe_continue(self.offset) then
      debug.log('not continue', self.name, self.id)
      self:reset()
    end
  end

  local completion_context
  if vim.tbl_contains(self:get_trigger_characters(), ctx.before_char) then
    completion_context = {
      triggerKind = lsp.CompletionTriggerKind.TriggerCharacter,
      triggerCharacter = ctx.before_char,
    }
  elseif ctx:is_keyword_beginning() and (not self.context or self.context.offset ~= ctx.offset) then
    completion_context = {
      triggerKind = lsp.CompletionTriggerKind.Invoked,
    }
  elseif self.incomplete and ctx.input ~= '' then
    completion_context = {
      triggerKind = lsp.CompletionTriggerKind.TriggerForIncompleteCompletions,
    }
  end
  if not completion_context then
    debug.log('skip', self.name, self.id)
    return
  end

  debug.log('request', self.name, self.id, vim.inspect(completion_context))
  local prev_status = self.status
  self.status = source.SourceStatus.FETCHING
  self.context = ctx
  self.source:complete(
    {
      context = ctx,
      completion_context = completion_context,
    },
    vim.schedule_wrap(function(response)
      if self.context.id ~= ctx.id then
        debug.log('ignore', self.name, self.id)
        return
      end
      if response ~= nil then
        debug.log('retrieve', self.name, self.id, #(response.items or response))
        self.status = source.SourceStatus.COMPLETED
        self.revision = self.revision + 1
        self.trigger_kind = completion_context.triggerKind
        self.incomplete = response.isIncomplete or false
        self.entries = {}
        self.offset = ctx.offset
        for i, item in ipairs(response.items or response) do
          local e = entry.new(ctx, self, item)
          self.entries[i] = e
          self.offset = math.min(self.offset, e:get_offset())
        end
      else
        debug.log('continue', self.name, self.id, 'nil')
        self.status = prev_status
      end
      callback()
    end)
  )
  return true
end

---Resolve CompletionItem
---@param item lsp.CompletionItem
---@param callback fun(item: lsp.CompletionItem)
source.resolve = function(self, item, callback)
  if not self.source.resolve then
    return callback(item)
  end
  self.source:resolve(item, function(resolved_item)
    callback(resolved_item or item)
  end)
end

---Execute command
---@param item lsp.CompletionItem
---@param callback fun()
source.execute = function(self, item, callback)
  if not self.source.execute then
    return callback()
  end
  self.source:execute(item, function()
    callback()
  end)
end

return source
