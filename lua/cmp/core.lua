local debug = require('cmp.utils.debug')
local char = require('cmp.utils.char')
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

---@type cmp.Menu
core.menu = menu.new({
  on_select = function(e)
    for _, c in ipairs(e:get_commit_characters()) do
      keymap.listen('i', c, core.on_keymap)
    end
  end,
})

---@type table<number, cmp.Source>
core.sources = {}

---@type cmp.Context
core.context = context.new()

---Register source
---@param s cmp.Source
core.register_source = function(s)
  core.sources[s.id] = s
end

---Unregister source
---@param source_id string
core.unregister_source = function(source_id)
  core.sources[source_id] = nil
end

---Get new context
---@param option cmp.ContextOption
---@return cmp.Context
core.get_context = function(option)
  local prev = core.context:clone()
  prev.prev_context = nil
  core.context = context.new(prev, option)
  return core.context
end

---Get sources that sorted by priority
---@param statuses cmp.SourceStatus[]
---@return cmp.Source[]
core.get_sources = function(statuses)
  local sources = {}
  for _, c in pairs(config.get().sources) do
    for _, s in pairs(core.sources) do
      if c.name == s.name then
        if not statuses or vim.tbl_contains(statuses, s.status) then
          if s:is_available() then
            table.insert(sources, s)
          end
        end
      end
    end
  end
  return sources
end

---Keypress handler
core.on_keymap = function(keys, fallback)
  for key, action in pairs(config.get().mapping) do
    if key == keys then
      if type(action) == 'function' then
        return action(core, fallback)
      else
        return action.invoke(core, fallback)
      end
    end
  end

  --Commit character. NOTE: This has a lot of cmp specific implementation to make more user-friendly.
  local chars = keymap.t(keys)
  local e = core.menu:get_selected_entry()
  if e and vim.tbl_contains(e:get_commit_characters(), chars) then
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
  local ctx = core.get_context({ reason = types.cmp.ContextReason.Auto })

  -- Skip autocompletion when the item is selected manually.
  if ctx.pumvisible and not vim.tbl_isempty(vim.v.completed_item) then
    return
  end

  debug.log(('ctx: `%s`'):format(ctx.cursor_before_line))
  if ctx:changed(ctx.prev_context) then
    debug.log('changed')
    core.menu:restore(ctx)

    if vim.tbl_contains(config.get().completion.autocomplete, event) then
      core.complete(ctx)
    else
      core.filter.timeout = 50
      core.filter()
    end
  else
    debug.log('unchanged')
  end
end

---Invoke completion
---@param ctx cmp.Context
core.complete = function(ctx)
  local callback = vim.schedule_wrap(function()
    local new = context.new(ctx)
    if new:changed(new.prev_context) then
      core.complete(new)
    else
      core.filter.timeout = 50
      core.filter()
    end
  end)
  for _, s in ipairs(core.get_sources()) do
    s:complete(ctx, callback)
  end

  core.filter.timeout = ctx.pumvisible and 50 or 0
  core.filter()
end

---Update completion menu
core.filter = async.throttle(function()
  local ctx = core.get_context()

  -- To wait for processing source for that's timeout.
  for _, s in ipairs(core.get_sources({ source.SourceStatus.FETCHING })) do
    local time = core.SOURCE_TIMEOUT - s:get_fetching_time()
    if time > 0 then
      core.filter.stop()
      core.filter.timeout = time + 1
      core.filter()
      return
    end
  end

  core.menu:update(ctx, core.get_sources())
end, 50)

---Confirm completion.
---@param e cmp.Entry
---@param option cmp.ConfirmOption
---@param callback function
core.confirm = vim.schedule_wrap(function(e, option, callback)
  if not (e and not e.confirmed) then
    return
  end
  e.confirmed = true

  debug.log('entry.confirm', e)

  local ctx = context.new()
  keymap.feedkeys('<C-g>U' .. string.rep('<BS>', ctx.cursor.col - e.context.cursor.col), 'n', function()
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

    local is_snippet = true
    is_snippet = is_snippet and completion_item.insertTextFormat == types.lsp.InsertTextFormat.Snippet
    is_snippet = is_snippet and vim.lsp.util.parse_snippet(completion_item.textEdit.newText) ~= completion_item.textEdit.newText

    local keys = ''
    if completion_item.textEdit.range['end'].character > e.context.cursor.character then
      keys = keys .. string.rep('<C-g>U<Right><BS>', completion_item.textEdit.range['end'].character - e.context.cursor.character)
    end
    if e.context.cursor.character > completion_item.textEdit.range.start.character then
      keys = keys .. string.rep('<BS>', e.context.cursor.character - completion_item.textEdit.range.start.character)
    end

    if is_snippet then
      keys = keys .. '<C-g>u' .. e:get_word() .. '<C-g>u'
      keys = keys .. string.rep('<BS>', vim.fn.strchars(e:get_word()))
    else
      keys = keys .. '<C-g>u' .. completion_item.textEdit.newText .. '<C-g>u'
    end
    keymap.feedkeys(keys, 'n', function()
      if is_snippet then
        config.get().snippet.expand({
          body = completion_item.textEdit.newText,
          insert_text_mode = completion_item.insertTextMode,
        })
      end
      e:execute(function()
        if config.get().event.on_confirm_done then
          config.get().event.on_confirm_done(e)
        end
        if callback then
          callback()
        end
      end)
    end)
  end)
end)

---Reset current completion state
core.reset = function()
  for _, s in pairs(core.sources) do
    s:reset()
  end
  core.menu:reset()

  core.get_context() -- To prevent new event
end

return core
