local context = require('cmp.context')
local config = require('cmp.config')
local matcher = require('cmp.matcher')
local entry = require('cmp.entry')
local debug = require('cmp.utils.debug')
local misc = require('cmp.utils.misc')
local cache = require('cmp.utils.cache')
local types = require('cmp.types')
local async = require('cmp.utils.async')
local pattern = require('cmp.utils.pattern')

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
---@field public offset number
---@field public request_offset number
---@field public status cmp.SourceStatus
---@field public complete_dedup function
local source = {}

---@alias cmp.SourceStatus "1" | "2" | "3"
source.SourceStatus = {}
source.SourceStatus.WAITING = 1
source.SourceStatus.FETCHING = 2
source.SourceStatus.COMPLETED = 3

---@return cmp.Source
source.new = function(name, s)
  local self = setmetatable({}, { __index = source })
  self.id = misc.id('source')
  self.name = name
  self.source = s
  self.cache = cache.new()
  self.complete_dedup = async.dedup()
  self.revision = 0
  self:reset()
  return self
end

---Reset current completion state
---@return boolean
source.reset = function(self)
  debug.log(self.id, self.name, 'source.reset')
  self.cache:clear()
  self.revision = self.revision + 1
  self.context = context.empty()
  self.request_offset = -1
  self.trigger_kind = nil
  self.incomplete = false
  self.entries = {}
  self.offset = -1
  self.status = source.SourceStatus.WAITING
  self.complete_dedup(function() end)
end

---Return source option
---@return table
source.get_option = function(self)
  return config.get_source_option(self.name)
end

---Return the source has items or not.
---@return boolean
source.has_items = function(self)
  return self.offset ~= -1
end

---Get fetching time
source.get_fetching_time = function(self)
  if self.status == source.SourceStatus.FETCHING then
    return vim.loop.now() - self.context.time
  end
  return 100 * 1000 -- return pseudo time if source isn't fetching.
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
    for i = ctx.cursor.col, self.offset, -1 do
      key[3] = string.sub(ctx.cursor_before_line, 1, i)
      local prev_entries = self.cache:get(key)
      if prev_entries then
        return prev_entries
      end
    end
    return nil
  end)()

  return self.cache:ensure({ 'get_entries', self.revision, ctx.cursor_before_line }, function()
    debug.log('filter', self.name, self.id, #(prev_entries or self.entries))

    local inputs = {}
    local entries = {}
    for _, e in ipairs(prev_entries or self.entries) do
      local o = e:get_offset()
      if not inputs[o] then
        inputs[o] = string.sub(ctx.cursor_before_line, o)
      end
      e.score = matcher.match(inputs[o], e:get_filter_text(), { e:get_word() })
      e.exact = false
      if e.score >= 1 then
        e.exact = vim.tbl_contains({ e:get_filter_text(), e:get_word() }, inputs[o])
        table.insert(entries, e)
      end
    end
    return entries
  end)
end

---Get default insert range
---@return lsp.Range|nil
source.get_default_insert_range = function(self)
  if not self.context then
    return nil
  end

  return self.cache:ensure({ 'get_default_insert_range', self.revision }, function()
    return {
      start = {
        line = self.context.cursor.row - 1,
        character = vim.str_utfindex(self.context.cursor_line, self.offset - 1),
      },
      ['end'] = {
        line = self.context.cursor.row - 1,
        character = vim.str_utfindex(self.context.cursor_line, self.context.cursor.col - 1),
      },
    }
  end)
end

---Get default replace range
---@return lsp.Range|nil
source.get_default_replace_range = function(self)
  if not self.context then
    return nil
  end

  return self.cache:ensure({ 'get_default_replace_range', self.revision }, function()
    local _, e = pattern.offset('^' .. self:get_keyword_pattern(), string.sub(self.context.cursor_line, self.offset))
    return {
      start = {
        line = self.context.cursor.row - 1,
        character = vim.str_utfindex(self.context.cursor_line, self.offset - 1),
      },
      ['end'] = {
        line = self.context.cursor.row - 1,
        character = vim.str_utfindex(self.context.cursor_line, e and self.offset + e - 2 or self.context.cursor.col - 1),
      },
    }
  end)
end

---Get keyword_pattern
---@return string
source.get_keyword_pattern = function(self)
  if self.source.get_keyword_pattern then
    return self.source:get_keyword_pattern()
  end
  return config.get().completion.keyword_pattern
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
  local c = config.get()

  local offset = ctx:get_offset(self:get_keyword_pattern())
  if ctx.cursor.col <= offset then
    self:reset()
  end

  local before_char = string.sub(ctx.cursor_before_line, -1)
  local before_char_iw = string.match(ctx.cursor_before_line, '(.)%s*$') or before_char

  if ctx:get_reason() == types.cmp.ContextReason.TriggerOnly then
    if string.match(before_char, '^%a+$') then
      before_char = ''
    end
    if string.match(before_char_iw, '^%a+$') then
      before_char_iw = ''
    end
  end

  local completion_context
  if ctx:get_reason() == types.cmp.ContextReason.Manual then
    completion_context = {
      triggerKind = types.lsp.CompletionTriggerKind.Invoked,
    }
  else
    if vim.tbl_contains(self:get_trigger_characters(), before_char) then
      completion_context = {
        triggerKind = types.lsp.CompletionTriggerKind.TriggerCharacter,
        triggerCharacter = before_char,
      }
    elseif vim.tbl_contains(self:get_trigger_characters(), before_char_iw) then
      completion_context = {
        triggerKind = types.lsp.CompletionTriggerKind.TriggerCharacter,
        triggerCharacter = before_char_iw,
      }
    else
      if ctx:get_reason() == types.cmp.ContextReason.Auto then
        if c.completion.keyword_length <= (ctx.cursor.col - offset) and self.request_offset ~= offset then
          completion_context = {
            triggerKind = types.lsp.CompletionTriggerKind.Invoked,
          }
        elseif self.incomplete then
          completion_context = {
            triggerKind = types.lsp.CompletionTriggerKind.TriggerForIncompleteCompletions,
          }
        end
      else
        self:reset()
      end
    end
  end
  if not completion_context then
    debug.log('skip empty context', self.name, self.id)
    if ctx:get_reason() == types.cmp.ContextReason.TriggerOnly then
      self:reset()
    end
    return
  end

  debug.log('request', self.name, self.id, offset, vim.inspect(completion_context))
  local prev_status = self.status
  self.status = source.SourceStatus.FETCHING
  self.request_offset = offset
  self.offset = offset
  self.context = ctx
  self.source:complete(
    {
      context = ctx,
      offset = self.offset,
      option = self:get_option(),
      completion_context = completion_context,
    },
    vim.schedule_wrap(self.complete_dedup(function(response)
      self.revision = self.revision + 1
      if #(misc.safe(response) and response.items or response or {}) > 0 then
        debug.log('retrieve', self.name, self.id, #(response.items or response))
        self.status = source.SourceStatus.COMPLETED
        self.trigger_kind = completion_context.triggerKind
        self.incomplete = response.isIncomplete or false
        self.entries = {}
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
    end))
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
