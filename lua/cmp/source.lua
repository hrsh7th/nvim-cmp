local context = require('cmp.context')
local config = require('cmp.config')
local entry = require('cmp.entry')
local debug = require('cmp.utils.debug')
local misc = require('cmp.utils.misc')
local cache = require('cmp.utils.cache')
local types = require('cmp.types')
local async = require('cmp.utils.async')
local pattern = require('cmp.utils.pattern')
local char = require('cmp.utils.char')

---@class cmp.Source
---@field public id integer
---@field public name string
---@field public source cmp.CustomSource
---@field public cache cmp.Cache
---@field public revision integer
---@field public incomplete boolean
---@field public is_triggered_by_symbol boolean
---@field public entries cmp.Entry[]
---@field public offset integer
---@field public request_offset integer
---@field public context cmp.Context
---@field public completion_context lsp.CompletionContext|nil
---@field public status cmp.SourceStatus
---@field public complete_dedup function
local source = {}

---@alias cmp.SourceStatus 1 | 2 | 3
source.SourceStatus = {}
source.SourceStatus.WAITING = 1
source.SourceStatus.FETCHING = 2
source.SourceStatus.COMPLETED = 3

---@param name string
---@param s cmp.CustomSource
---@return cmp.Source
source.new = function(name, s)
  local self = setmetatable({}, { __index = source })
  self.id = misc.id('cmp.source.new')
  self.name = name
  self.source = s
  self.cache = cache.new()
  self.complete_dedup = async.dedup()
  self.revision = 0
  self:reset()
  return self
end

---Reset current completion state
source.reset = function(self)
  self.cache:clear()
  self.revision = self.revision + 1
  self.context = context.empty()
  self.is_triggered_by_symbol = false
  self.incomplete = false
  self.entries = {}
  self.offset = -1
  self.request_offset = -1
  self.completion_context = nil
  self.status = source.SourceStatus.WAITING
  self.complete_dedup(function() end)
end

---Return source config
---@return cmp.SourceConfig
source.get_source_config = function(self)
  local c = config.get_source_config(self.name) or {}
  c.override = c.override or {}
  c.override.is_available = c.override.is_available or function(is_available)
    return is_available()
  end
  c.override.get_keyword_pattern = c.override.get_keyword_pattern or function(params, get_keyword_pattern)
    return get_keyword_pattern(params)
  end
  c.override.get_trigger_characters = c.override.get_trigger_characters or function(params, get_trigger_characters)
    return get_trigger_characters(params)
  end
  c.override.complete = c.override.complete or function(params, callback, complete)
    complete(params, callback)
  end
  c.override.resolve = c.override.resolve or function(completion_item, callback, resolve)
    resolve(completion_item, callback)
  end
  c.override.execute = c.override.execute or function(completion_item, callback, execute)
    execute(completion_item, callback)
  end
  return c
end

---Return matching config
---@return cmp.MatchingConfig
source.get_matching_config = function()
  return config.get().matching
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
  if self.offset == -1 then
    return {}
  end

  local target_entries = (function()
    local key = { 'get_entries', self.revision }
    for i = ctx.cursor.col, self.offset, -1 do
      key[3] = string.sub(ctx.cursor_before_line, 1, i)
      local prev_entries = self.cache:get(key)
      if prev_entries then
        return prev_entries
      end
    end
    return self.entries
  end)()

  local entry_filter = self:get_entry_filter()

  local inputs = {}
  local entries = {}
  local matching_config = self:get_matching_config()
  for _, e in ipairs(target_entries) do
    local o = e:get_offset()
    if not inputs[o] then
      inputs[o] = string.sub(ctx.cursor_before_line, o)
    end

    local match = e:match(inputs[o], matching_config)
    e.score = match.score
    e.exact = false
    if e.score >= 1 then
      e.matches = match.matches
      e.exact = e:get_filter_text() == inputs[o] or e:get_word() == inputs[o]

      if entry_filter(e, ctx) then
        table.insert(entries, e)
      end
    end
  end
  self.cache:set({ 'get_entries', tostring(self.revision), ctx.cursor_before_line }, entries)

  local max_item_count = self:get_source_config().max_item_count or 200
  local limited_entries = {}
  for _, e in ipairs(entries) do
    table.insert(limited_entries, e)
    if max_item_count and #limited_entries >= max_item_count then
      break
    end
  end
  return limited_entries
end

---Get default insert range (UTF8 byte index).
---@return lsp.Range
source.get_default_insert_range = function(self)
  if not self.context then
    error('context is not initialized yet.')
  end

  return self.cache:ensure({ 'get_default_insert_range', tostring(self.revision) }, function()
    return {
      start = {
        line = self.context.cursor.row - 1,
        character = self.offset - 1,
      },
      ['end'] = {
        line = self.context.cursor.row - 1,
        character = self.context.cursor.col - 1,
      },
    }
  end)
end

---Get default replace range (UTF8 byte index).
---@return lsp.Range
source.get_default_replace_range = function(self)
  if not self.context then
    error('context is not initialized yet.')
  end

  return self.cache:ensure({ 'get_default_replace_range', tostring(self.revision) }, function()
    local _, e = pattern.offset('^' .. '\\%(' .. self:get_keyword_pattern() .. '\\)', string.sub(self.context.cursor_line, self.offset))
    return {
      start = {
        line = self.context.cursor.row - 1,
        character = self.offset,
      },
      ['end'] = {
        line = self.context.cursor.row - 1,
        character = (e and self.offset + e - 2 or self.context.cursor.col - 1),
      },
    }
  end)
end

---Get keyword_length
---@return integer
source.get_keyword_length = function(self)
  local c = self:get_source_config()
  if c.keyword_length then
    return c.keyword_length
  end
  return config.get().completion.keyword_length or 1
end

---Get filter
--@return fun(entry: cmp.Entry, context: cmp.Context): boolean
source.get_entry_filter = function(self)
  local c = self:get_source_config()
  if c.entry_filter then
    return c.entry_filter --[[@as fun(entry: cmp.Entry, context: cmp.Context): boolean]]
  end
  return function(_, _)
    return true
  end
end

---Return source name.
source.get_debug_name = function(self)
  local name = self.name
  if self.source.get_debug_name then
    name = self.source:get_debug_name()
  end
  return name
end

---Get lsp.PositionEncodingKind
---@return lsp.PositionEncodingKind
source.get_position_encoding_kind = function(self)
  if self.source.get_position_encoding_kind then
    return self.source:get_position_encoding_kind()
  end
  return types.lsp.PositionEncodingKind.UTF16
end

---Return the source is available or not.
source.is_available = function(self)
  local params = self:get_source_config()
  return params.override.is_available(function()
    if self.source.is_available then
      return self.source:is_available()
    end
    return true
  end)
end

---Get trigger_characters
---@return string[]
source.get_trigger_characters = function(self)
  local params = self:get_source_config()
  return params.override.get_trigger_characters(params, function(params)
    local trigger_characters = {}
    if self.source.get_trigger_characters then
      trigger_characters = self.source:get_trigger_characters(misc.copy(params)) or {}
    end
    if config.get().completion.get_trigger_characters then
      return config.get().completion.get_trigger_characters(trigger_characters)
    end
    return trigger_characters
  end)
end

---Get keyword_pattern
---@return string
source.get_keyword_pattern = function(self)
  local params = self:get_source_config()
  return params.override.get_keyword_pattern(params, function(params)
    if self.source.get_keyword_pattern then
      local keyword_pattern = self.source:get_keyword_pattern(misc.copy(params))
      if keyword_pattern then
        return keyword_pattern
      end
    end
    return config.get().completion.keyword_pattern
  end)
end

---Invoke completion
---@param ctx cmp.Context
---@param callback function
---@return boolean? Return true if not trigger completion.
source.complete = function(self, ctx, callback)
  local offset = ctx:get_offset(self:get_keyword_pattern())

  -- NOTE: This implementation is nvim-cmp specific.
  -- We trigger new completion after core.confirm but we check only the symbol trigger_character in this case.
  local before_char = string.sub(ctx.cursor_before_line, -1)
  if ctx:get_reason() == types.cmp.ContextReason.TriggerOnly then
    before_char = string.match(ctx.cursor_before_line, '(.)%s*$')
    if not before_char or not char.is_symbol(string.byte(before_char)) then
      before_char = ''
    end
  end

  local completion_context
  if ctx:get_reason() == types.cmp.ContextReason.Manual then
    completion_context = {
      triggerKind = types.lsp.CompletionTriggerKind.Invoked,
    }
  elseif vim.tbl_contains(self:get_trigger_characters(), before_char) then
    completion_context = {
      triggerKind = types.lsp.CompletionTriggerKind.TriggerCharacter,
      triggerCharacter = before_char,
    }
  elseif ctx:get_reason() ~= types.cmp.ContextReason.TriggerOnly then
    if offset < ctx.cursor.col and self:get_keyword_length() <= (ctx.cursor.col - offset) then
      if self.incomplete and self.context.cursor.col ~= ctx.cursor.col and self.status ~= source.SourceStatus.FETCHING then
        completion_context = {
          triggerKind = types.lsp.CompletionTriggerKind.TriggerForIncompleteCompletions,
        }
      elseif not vim.tbl_contains({ self.request_offset, self.offset }, offset) then
        completion_context = {
          triggerKind = types.lsp.CompletionTriggerKind.Invoked,
        }
      end
    else
      self:reset() -- Should clear current completion if the TriggerKind isn't TriggerCharacter or Manual and keyword length does not enough.
    end
  else
    self:reset() -- Should clear current completion if ContextReason is TriggerOnly and the triggerCharacter isn't matched
  end

  -- Does not perform completions.
  if not completion_context then
    return
  end

  if completion_context.triggerKind == types.lsp.CompletionTriggerKind.TriggerCharacter then
    self.is_triggered_by_symbol = char.is_symbol(string.byte(completion_context.triggerCharacter))
  end

  debug.log(self:get_debug_name(), 'request', offset, vim.inspect(completion_context))
  local prev_status = self.status
  self.status = source.SourceStatus.FETCHING
  self.offset = offset
  self.request_offset = offset
  self.context = ctx
  self.completion_context = completion_context

  local params = self:get_source_config()
  params.override.complete(
    vim.tbl_extend('keep', misc.copy(self:get_source_config()), {
      offset = self.offset,
      context = ctx,
      completion_context = completion_context,
    }),
    self.complete_dedup(vim.schedule_wrap(function(response)
      ---@type lsp.CompletionResponse
      response = response or {}

      self.incomplete = response.isIncomplete or false

      if #(response.items or response) > 0 then
        debug.log(self:get_debug_name(), 'retrieve', #(response.items or response))
        local old_offset = self.offset
        local old_entries = self.entries

        self.status = source.SourceStatus.COMPLETED
        self.entries = {}
        for i, item in ipairs(response.items or response) do
          if (misc.safe(item) or {}).label then
            local e = entry.new(ctx, self, item, response.itemDefaults)
            self.entries[i] = e
            self.offset = math.min(self.offset, e:get_offset())
          end
        end
        self.revision = self.revision + 1
        if #self:get_entries(ctx) == 0 then
          self.offset = old_offset
          self.entries = old_entries
          self.revision = self.revision + 1
        end
      else
        -- The completion will be invoked when pressing <CR> if the trigger characters contain the <Space>.
        -- If the server returns an empty response in such a case, should invoke the keyword completion on the next keypress.
        if offset == ctx.cursor.col then
          self:reset()
        end
        self.status = prev_status
      end
      callback()
    end)),
    function(params, callback)
      self.source:complete(params, callback)
    end
  )
  return true
end

---Resolve CompletionItem
---@param item lsp.CompletionItem
---@param callback fun(item: lsp.CompletionItem)
source.resolve = function(self, item, callback)
  local params = self:get_source_config()
  params.override.resolve(item, function(resolved_item)
    callback(resolved_item or item)
  end, function(item, callback)
    if not self.source.resolve then
      return callback(item)
    end
    self.source:resolve(item, function(resolved_item)
      callback(resolved_item or item)
    end)
  end)
end

---Execute command
---@param item lsp.CompletionItem
---@param callback fun()
source.execute = function(self, item, callback)
  local params = self:get_source_config()
  params.override.execute(item, function()
    callback()
  end, function(item, callback)
    if not self.source.execute then
      return callback()
    end
    self.source:execute(item, callback)
  end)
end

return source
