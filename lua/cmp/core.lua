local debug = require('cmp.utils.debug')
local char = require('cmp.utils.char')
local str = require('cmp.utils.str')
local pattern = require('cmp.utils.pattern')
local async = require('cmp.utils.async')
local keymap = require('cmp.utils.keymap')
local context = require('cmp.context')
local source = require('cmp.source')
local menu = require('cmp.menu')
local misc = require('cmp.utils.misc')
local config = require('cmp.config')
local types = require('cmp.types')

---@class cmp.Core
local core = {}

core.SOURCE_TIMEOUT = 500
core.THROTTLE_TIME = 80

---Suspending state.
core.suspending = false

core.GHOST_TEXT_NS = vim.api.nvim_create_namespace('cmp:GHOST_TEXT')

---@type cmp.Menu
core.menu = menu.new({
  on_select = function(e)
    for _, c in ipairs(config.get().confirmation.get_commit_characters(e:get_commit_characters())) do
      keymap.listen('i', c, core.on_keymap)
    end
    core.ghost_text(e)
  end,
})

---Show ghost text if possible
---@param e cmp.Entry
core.ghost_text = function(e)
  vim.api.nvim_buf_clear_namespace(0, core.GHOST_TEXT_NS, 0, -1)

  local c = config.get().experimental.ghost_text
  if not c then
    return
  end

  if not e then
    return
  end

  local ctx = context.new()
  if ctx.cursor_after_line ~= '' then
    return
  end

  local diff = ctx.cursor.col - e:get_offset()
  local text = e:get_insert_text()
  if e.completion_item.insertTextFormat == types.lsp.InsertTextFormat.Snippet then
    text = vim.lsp.util.parse_snippet(text)
  end
  text = string.sub(str.oneline(text), diff + 1)
  if #text > 0 then
    vim.api.nvim_buf_set_extmark(ctx.bufnr, core.GHOST_TEXT_NS, ctx.cursor.row - 1, ctx.cursor.col - 1, {
      right_gravity = false,
      virt_text = { { text, c.hl_group or 'Comment' } },
      virt_text_pos = 'overlay',
      hl_mode = 'combine',
      priority = 1,
    })
  end
end

---@type table<number, cmp.Source>
core.sources = {}

---@type table<string, cmp.Source[]>
core.sources_by_name = {}

---@type cmp.Context
core.context = context.new()

---Register source
---@param s cmp.Source
core.register_source = function(s)
  core.sources[s.id] = s
  if not core.sources_by_name[s.name] then
    core.sources_by_name[s.name] = {}
  end
  table.insert(core.sources_by_name[s.name], s)
  if misc.is_insert_mode() then
    core.complete(core.get_context({ reason = types.cmp.ContextReason.Auto }))
  end
end

---Unregister source
---@param source_id string
core.unregister_source = function(source_id)
  local name = core.sources[source_id].name
  core.sources_by_name[name] = vim.tbl_filter(function(s)
    return s.id ~= source_id
  end, core.sources_by_name[name])
  core.sources[source_id] = nil
end

---Get new context
---@param option cmp.ContextOption
---@return cmp.Context
core.get_context = function(option)
  local prev = core.context:clone()
  prev.prev_context = nil
  local ctx = context.new(prev, option)
  core.set_context(ctx)
  return core.context
end

---Set new context
---@param ctx cmp.Context
core.set_context = function(ctx)
  core.context = ctx
end

---Suspend completion
core.suspend = function()
  core.suspending = true
  return function()
    core.suspending = false
  end
end

---Get sources that sorted by priority
---@param statuses cmp.SourceStatus[]
---@return cmp.Source[]
core.get_sources = function(statuses)
  local sources = {}
  for _, c in pairs(config.get().sources) do
    for _, s in ipairs(core.sources_by_name[c.name] or {}) do
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
core.on_keymap = function(keys, fallback)
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
  local e = core.menu:get_selected_entry()
  if e and vim.tbl_contains(config.get().confirmation.get_commit_characters(e:get_commit_characters()), chars) then
    local is_printable = char.is_printable(string.byte(chars, 1))
    core.confirm(e, {
      behavior = is_printable and 'insert' or 'replace',
    }, function()
      local ctx = core.get_context()
      local word = e:get_word()
      if string.sub(ctx.cursor_before_line, -#word, ctx.cursor.col - 1) == word and is_printable then
        fallback()
      else
        core.reset()
      end
    end)
    return
  end

  fallback()
end

---Prepare completion
core.prepare = function()
  for keys, action in pairs(config.get().mapping) do
    if type(action) == 'function' then
      action = {
        modes = { 'i' },
        action = action,
      }
    end
    for _, mode in ipairs(action.modes) do
      keymap.listen(mode, keys, core.on_keymap)
    end
  end
end

---Check auto-completion
core.on_change = function(event)
  if core.suspending then
    return
  end

  core.autoindent(event, function()
    local ctx = core.get_context({ reason = types.cmp.ContextReason.Auto })

    -- Skip autocompletion when the item is selected manually.
    if ctx.pumvisible and not vim.tbl_isempty(vim.v.completed_item) then
      return
    end

    debug.log(('ctx: `%s`'):format(ctx.cursor_before_line))
    if ctx:changed(ctx.prev_context) then
      debug.log('changed')
      core.menu:restore(ctx)
      core.ghost_text(core.menu:get_first_entry())

      if vim.tbl_contains(config.get().completion.autocomplete or {}, event) then
        core.complete(ctx)
      else
        core.filter.timeout = core.THROTTLE_TIME
        core.filter()
      end
    else
      debug.log('unchanged')
    end
  end)
end

---Check autoindent
---@param event cmp.TriggerEvent
---@param callback function
core.autoindent = function(event, callback)
  if event == types.cmp.TriggerEvent.TextChanged then
    local cursor_before_line = misc.get_cursor_before_line()
    local prefix = pattern.matchstr('[^[:blank:]]\\+$', cursor_before_line)
    if prefix then
      for _, key in ipairs(vim.split(vim.bo.indentkeys, ',')) do
        if vim.tbl_contains({ '=' .. prefix, '0=' .. prefix }, key) then
          return vim.schedule(function()
            if cursor_before_line == misc.get_cursor_before_line() then
              local indentkeys = vim.bo.indentkeys
              vim.bo.indentkeys = indentkeys .. ',!^F'
              keymap.feedkeys(keymap.t('<C-f>'), 'n', function()
                vim.bo.indentkeys = indentkeys
                callback()
              end)
            else
              callback()
            end
          end)
        end
      end
    end
  end
  callback()
end

---Invoke completion
---@param ctx cmp.Context
core.complete = function(ctx)
  if not misc.is_insert_mode() then
    return
  end

  core.set_context(ctx)

  local callback = function()
    local new = context.new(ctx)
    if new:changed(new.prev_context) and ctx == core.context then
      core.complete(new)
    else
      core.filter.timeout = core.THROTTLE_TIME
      core.filter()
    end
  end
  for _, s in ipairs(core.get_sources({ source.SourceStatus.WAITING, source.SourceStatus.COMPLETED })) do
    s:complete(ctx, callback)
  end

  core.filter.timeout = ctx.pumvisible and core.THROTTLE_TIME or 0
  core.filter()
end

---Update completion menu
core.filter = async.throttle(function()
  if not misc.is_insert_mode() then
    return
  end
  local ctx = core.get_context()

  -- To wait for processing source for that's timeout.
  local sources = {}
  for _, s in ipairs(core.get_sources({ source.SourceStatus.FETCHING, source.SourceStatus.COMPLETED })) do
    local time = core.SOURCE_TIMEOUT - s:get_fetching_time()
    if not s.incomplete and time > 0 then
      if #sources == 0 then
        core.filter.stop()
        core.filter.timeout = time + 1
        core.filter()
        return
      end
      break
    end
    table.insert(sources, s)
  end

  core.menu:update(ctx, sources)
  core.ghost_text(core.menu:get_first_entry())
end, core.THROTTLE_TIME)

---Confirm completion.
---@param e cmp.Entry
---@param option cmp.ConfirmOption
---@param callback function
core.confirm = function(e, option, callback)
  if not (e and not e.confirmed) then
    return
  end
  e.confirmed = true

  debug.log('entry.confirm', e:get_completion_item())

  local suspending = core.suspend()
  local ctx = core.get_context()

  -- Simulate `<C-y>` behavior.
  local confirm = {}
  table.insert(confirm, keymap.t(string.rep('<C-g>U<Left><Del>', ctx.cursor.character - misc.to_utfindex(e.context.cursor_before_line, e:get_offset()))))
  table.insert(confirm, e:get_word())
  keymap.feedkeys(table.concat(confirm, ''), 'nt', function()
    -- Restore to the requested state.
    local restore = {}
    table.insert(restore, keymap.t(string.rep('<C-g>U<Left><Del>', vim.fn.strchars(e:get_word()))))
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
        table.insert(keys, keymap.t(string.rep('<C-g>U<Left><Del>', e.context.cursor.character - completion_item.textEdit.range.start.character)))
      end

      local is_snippet = completion_item.insertTextFormat == types.lsp.InsertTextFormat.Snippet
      if is_snippet then
        table.insert(keys, keymap.t('<C-g>u') .. e:get_word() .. keymap.t('<C-g>u'))
        table.insert(keys, keymap.t(string.rep('<C-g>U<Left><Del>', vim.fn.strchars(e:get_word()))))
      else
        table.insert(keys, keymap.t('<C-g>u') .. completion_item.textEdit.newText .. keymap.t('<C-g>u'))
      end
      keymap.feedkeys(table.concat(keys, ''), 'n', function()
        if is_snippet then
          config.get().snippet.expand({
            body = completion_item.textEdit.newText,
            insert_text_mode = completion_item.insertTextMode,
          })
        end
        e:execute(vim.schedule_wrap(function()
          suspending()

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
core.reset = function()
  for _, s in pairs(core.sources) do
    s:reset()
  end
  core.menu:reset()

  core.get_context() -- To prevent new event
  core.ghost_text(nil)
end

return core
