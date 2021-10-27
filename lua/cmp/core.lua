local debug = require('cmp.utils.debug')
local char = require('cmp.utils.char')
local pattern = require('cmp.utils.pattern')
local async = require('cmp.utils.async')
local keymap = require('cmp.utils.keymap')
local context = require('cmp.context')
local source = require('cmp.source')
local view = require('cmp.view')
local misc = require('cmp.utils.misc')
local config = require('cmp.config')
local types = require('cmp.types')
local api = require('cmp.utils.api')

local SOURCE_TIMEOUT = 500
local THROTTLE_TIME = 120
local DEBOUNCE_TIME = 20

---@class cmp.Core
---@field public suspending boolean
---@field public view cmp.View
---@field public sources cmp.Source[]
---@field public sources_by_name table<string, cmp.Source>
---@field public context cmp.Context
local core = {}

core.new = function()
  local self = setmetatable({}, { __index = core })
  self.suspending = false
  self.sources = {}
  self.sources_by_name = {}
  self.context = context.new()
  self.view = view.new()
  self.view.event:on('keymap', function(...)
    self:on_keymap(...)
  end)
  return self
end

---Register source
---@param s cmp.Source
core.register_source = function(self, s)
  self.sources[s.id] = s
  if not self.sources_by_name[s.name] then
    self.sources_by_name[s.name] = {}
  end
  table.insert(self.sources_by_name[s.name], s)
end

---Unregister source
---@param source_id string
core.unregister_source = function(self, source_id)
  local name = self.sources[source_id].name
  self.sources_by_name[name] = vim.tbl_filter(function(s)
    return s.id ~= source_id
  end, self.sources_by_name[name])
  self.sources[source_id] = nil
end

---Get new context
---@param option cmp.ContextOption
---@return cmp.Context
core.get_context = function(self, option)
  local prev = self.context:clone()
  prev.prev_context = nil
  local ctx = context.new(prev, option)
  self:set_context(ctx)
  return self.context
end

---Set new context
---@param ctx cmp.Context
core.set_context = function(self, ctx)
  self.context = ctx
end

---Suspend completion
core.suspend = function(self)
  self.suspending = true
  return function()
    self.suspending = false
  end
end

---Get sources that sorted by priority
---@param statuses cmp.SourceStatus[]
---@return cmp.Source[]
core.get_sources = function(self, statuses)
  local sources = {}
  for _, c in pairs(config.get().sources) do
    for _, s in ipairs(self.sources_by_name[c.name] or {}) do
      if not statuses or vim.tbl_contains(statuses, s.status) then
        if s:is_available() then
          table.insert(sources, s)
        end
      end
    end
  end
  return sources
end

---Keypress handler
core.on_keymap = function(self, keys, fallback)
  for key, action in pairs(config.get().mapping) do
    if keymap.equals(key, keys) then
      if type(action) == 'function' then
        action(fallback)
      else
        action.invoke(fallback)
      end
      return
    end
  end

  --Commit character. NOTE: This has a lot of cmp specific implementation to make more user-friendly.
  local chars = keymap.t(keys)
  local e = self.view:get_active_entry()
  if e and vim.tbl_contains(config.get().confirmation.get_commit_characters(e:get_commit_characters()), chars) then
    local is_printable = char.is_printable(string.byte(chars, 1))
    self:confirm(e, {
      behavior = is_printable and 'insert' or 'replace',
    }, function()
      local ctx = self:get_context()
      local word = e:get_word()
      if string.sub(ctx.cursor_before_line, -#word, ctx.cursor.col - 1) == word and is_printable then
        fallback()
      else
        self:reset()
      end
    end)
    return
  end

  fallback()
end

---Prepare completion
core.prepare = function(self)
  for keys, action in pairs(config.get().mapping) do
    if type(action) == 'function' then
      action = {
        modes = { 'i' },
        action = action,
      }
    end
    for _, mode in ipairs(action.modes) do
      keymap.listen(mode, keys, function(...)
        self:on_keymap(...)
      end)
    end
  end
end

---Check auto-completion
core.on_change = function(self, trigger_event)
  local ignore = false
  ignore = ignore or self.suspending
  ignore = ignore or (vim.fn.pumvisible() == 1 and (vim.v.completed_item).word)
  ignore = ignore or not self.view:ready()
  if ignore then
    self:get_context({ reason = types.cmp.ContextReason.Auto })
    return
  end

  self:autoindent(trigger_event, function()
    local ctx = self:get_context({ reason = types.cmp.ContextReason.Auto })
    debug.log(('ctx: `%s`'):format(ctx.cursor_before_line))
    if ctx:changed(ctx.prev_context) then
      self.view:on_change()
      debug.log('changed')

      if vim.tbl_contains(config.get().completion.autocomplete or {}, trigger_event) then
        self:complete(ctx)
      else
        self.filter.timeout = THROTTLE_TIME
        self:filter()
      end
    else
      debug.log('unchanged')
    end
  end)
end

---Cursor moved.
core.on_moved = function(self)
  local ignore = false
  ignore = ignore or self.suspending
  ignore = ignore or (vim.fn.pumvisible() == 1 and (vim.v.completed_item).word)
  ignore = ignore or not self.view:visible()
  if ignore then
    return
  end
  self:filter()
end

---Check autoindent
---@param trigger_event cmp.TriggerEvent
---@param callback function
core.autoindent = function(self, trigger_event, callback)
  if trigger_event ~= types.cmp.TriggerEvent.TextChanged then
    return callback()
  end
  if not api.is_insert_mode()  then
    return callback()
  end

  local cursor_before_line = api.get_cursor_before_line()
  local prefix = pattern.matchstr('[^[:blank:]]\\+$', cursor_before_line)
  if prefix then
    for _, key in ipairs(vim.split(vim.bo.indentkeys, ',')) do
      if vim.tbl_contains({ '=' .. prefix, '0=' .. prefix }, key) then
        local release = self:suspend()
        vim.schedule(function()
          if cursor_before_line == api.get_cursor_before_line() then
            local indentkeys = vim.bo.indentkeys
            vim.bo.indentkeys = indentkeys .. ',!^F'
            keymap.feedkeys(keymap.t('<C-f>'), 'n', function()
              vim.bo.indentkeys = indentkeys
              release()
              callback()
            end)
          else
            callback()
          end
        end)
        return
      end
    end
  end
  callback()
end

---Invoke completion
---@param ctx cmp.Context
core.complete = function(self, ctx)
  if not api.is_suitable_mode() then
    return
  end
  self:set_context(ctx)

  for _, s in ipairs(self:get_sources({ source.SourceStatus.WAITING, source.SourceStatus.COMPLETED })) do
    s:complete(
      ctx,
      (function(src)
        local callback
        callback = function()
          local new = context.new(ctx)
          if new:changed(new.prev_context) and ctx == self.context then
            src:complete(new, callback)
          else
            self.filter.stop()
            self.filter.timeout = DEBOUNCE_TIME
            self:filter()
          end
        end
        return callback
      end)(s)
    )
  end

  self.filter.timeout = THROTTLE_TIME
  self:filter()
end

---Update completion menu
core.filter = async.throttle(
  vim.schedule_wrap(function(self)
    if not api.is_suitable_mode() then
      return
    end
    if self.view:get_active_entry() ~= nil then
      return
    end
    local ctx = self:get_context()

    -- To wait for processing source for that's timeout.
    local sources = {}
    for _, s in ipairs(self:get_sources({ source.SourceStatus.FETCHING, source.SourceStatus.COMPLETED })) do
      local time = SOURCE_TIMEOUT - s:get_fetching_time()
      if not s.incomplete and time > 0 then
        if #sources == 0 then
          self.filter.stop()
          self.filter.timeout = time + 1
          self:filter()
          return
        end
        break
      end
      table.insert(sources, s)
    end
    self.filter.timeout = THROTTLE_TIME

    self.view:open(ctx, sources)
  end),
  THROTTLE_TIME
)

---Confirm completion.
---@param e cmp.Entry
---@param option cmp.ConfirmOption
---@param callback function
core.confirm = function(self, e, option, callback)
  if not (e and not e.confirmed) then
    return
  end
  e.confirmed = true

  debug.log('entry.confirm', e:get_completion_item())

  local release = self:suspend()
  local ctx = self:get_context()

  -- Close menus.
  self.view:close()

  -- Simulate `<C-y>` behavior.
  local confirm = {}
  table.insert(confirm, keymap.backspace(ctx.cursor.character - misc.to_utfindex(e.context.cursor_before_line, e:get_offset())))
  table.insert(confirm, e:get_word())
  keymap.feedkeys(table.concat(confirm, ''), 'nt', function()
    -- Restore to the requested state.
    local restore = {}
    table.insert(restore, keymap.backspace(vim.str_utfindex(e:get_word())))
    table.insert(restore, string.sub(e.context.cursor_before_line, e:get_offset()))
    keymap.feedkeys(table.concat(restore, ''), 'n', function()
      --@see https://github.com/microsoft/vscode/blob/main/src/vs/editor/contrib/suggest/suggestController.ts#L334
      if #(misc.safe(e:get_completion_item().additionalTextEdits) or {}) == 0 then
        local pre = context.new()
        e:resolve(function()
          local new = context.new()
          local text_edits = misc.safe(e:get_completion_item().additionalTextEdits) or {}
          if #text_edits == 0 then
            return
          end

          local has_cursor_line_text_edit = (function()
            local minrow = math.min(pre.cursor.row, new.cursor.row)
            local maxrow = math.max(pre.cursor.row, new.cursor.row)
            for _, te in ipairs(text_edits) do
              local srow = te.range.start.line + 1
              local erow = te.range['end'].line + 1
              if srow <= minrow and maxrow <= erow then
                return true
              end
            end
            return false
          end)()
          if has_cursor_line_text_edit then
            return
          end
          vim.fn['cmp#apply_text_edits'](new.bufnr, text_edits)
        end)
      else
        vim.fn['cmp#apply_text_edits'](ctx.bufnr, e:get_completion_item().additionalTextEdits)
      end

      -- Prepare completion item for confirmation
      local completion_item = misc.copy(e:get_completion_item())
      if not misc.safe(completion_item.textEdit) then
        completion_item.textEdit = {}
        completion_item.textEdit.newText = misc.safe(completion_item.insertText) or completion_item.word or completion_item.label
      end
      local behavior = option.behavior or config.get().confirmation.default_behavior
      if behavior == types.cmp.ConfirmBehavior.Replace then
        completion_item.textEdit.range = e:get_replace_range()
      else
        completion_item.textEdit.range = e:get_insert_range()
      end

      local keys = {}
      if e.context.cursor.character < completion_item.textEdit.range['end'].character then
        table.insert(keys, keymap.t(string.rep('<Del>', completion_item.textEdit.range['end'].character - e.context.cursor.character)))
      end
      if completion_item.textEdit.range.start.character < e.context.cursor.character then
        table.insert(keys, keymap.backspace(e.context.cursor.character - completion_item.textEdit.range.start.character))
      end
      table.insert(keys, keymap.undobreak())

      local is_snippet = completion_item.insertTextFormat == types.lsp.InsertTextFormat.Snippet
      if is_snippet then
        table.insert(keys, e:get_word())
      else
        table.insert(keys, completion_item.textEdit.newText)
      end

      keymap.feedkeys(table.concat(keys, ''), 'n', function()
        if is_snippet then
          -- remove snippet prefix without changing `dot` register.
          local snippet_ctx = context.new()
          vim.fn['cmp#apply_text_edits'](ctx.bufnr, { {
            range = {
              start = {
                line = snippet_ctx.cursor.line,
                character = snippet_ctx.cursor.character - vim.str_utfindex(e:get_word()),
              },
              ['end'] = snippet_ctx.cursor,
            },
            newText = '',
          } })
          config.get().snippet.expand({
            body = completion_item.textEdit.newText,
            insert_text_mode = completion_item.insertTextMode,
          })
        end
        e:execute(vim.schedule_wrap(function()
          release()

          if config.get().event.on_confirm_done then
            config.get().event.on_confirm_done(e)
          end
          if callback then
            callback()
          end
        end))
      end)
    end)
  end)
end

---Reset current completion state
core.reset = function(self)
  for _, s in pairs(self.sources) do
    s:reset()
  end
  self:get_context() -- To prevent new event
end

return core
