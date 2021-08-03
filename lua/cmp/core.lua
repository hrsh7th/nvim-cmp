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
local patch = require('cmp.utils.patch')

local core = {}

core.SOURCE_TIMEOUT = 500

---@type cmp.Menu
core.menu = menu.new()

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
          table.insert(sources, s)
        end
      end
    end
  end
  return sources
end

---Keypress handler
core.on_keymap = function(keys, fallback)
  -- Confirm character
  if config.get().confirmation.mapping[keys] then
    local c = config.get().confirmation.mapping[keys]
    local e = core.menu:get_selected_entry() or (c.select and core.menu:get_first_entry())
    if not e then
      return fallback()
    end
    return core.confirm(e, {
      behavior = c.behavior,
    })
  end

  --Commit character. NOTE: This has a lot of cmp specific implementation to make more user-friendly.
  local chars = keymap.t(keys)
  local e = core.menu:get_selected_entry()
  if e and vim.tbl_contains(e:get_commit_characters(), chars) then
    local is_printable = char.is_printable(string.byte(chars, 1))
    return core.confirm(e, {
      behavior = is_printable and 'insert' or 'replace',
    }, function()
      local ctx = core.get_context()
      local word = e:get_word()
      if string.sub(ctx.cursor_before_line, -#word, ctx.cursor.col - 1) == word and is_printable then
        fallback()
      end
    end)
  end

  fallback()
end

---Prepare completion
core.prepare = function()
  for keys in pairs(config.get().confirmation.mapping) do
    keymap.listen(keys, core.on_keymap)
  end
end

---Check auto-completion
core.autocomplete = function(event)
  local ctx = core.get_context({ reason = types.cmp.ContextReason.Auto })

  -- Skip autocompletion when the item is selected manually.
  if ctx.pumvisible and not vim.tbl_isempty(vim.v.completed_item) then
    return
  end

  debug.log(('ctx: `%s`'):format(ctx.cursor_before_line))
  if ctx:is_forwarding() then
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
  for _, s in ipairs(core.get_sources({ source.SourceStatus.WAITING, source.SourceStatus.COMPLETED })) do
    s:complete(ctx, function()
      local new = context.new(ctx)
      if new:changed(new.prev_context) then
        core.complete(new)
      else
        core.filter.timeout = 50
        core.filter()
      end
    end)
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

  debug.log('entry.confirm', e:get_completion_item())

  --@see https://github.com/microsoft/vscode/blob/main/src/vs/editor/contrib/suggest/suggestController.ts#L334
  local pre = context.new()
  if #(misc.safe(e:get_completion_item().additionalTextEdits) or {}) == 0 then
    local new = context.new(pre)
    e:resolve(function()
      local text_edits = misc.safe(e:get_completion_item().additionalTextEdits) or {}
      if #text_edits == 0 then
        return
      end

      local has_cursor_line_text_edit = (function()
        local minrow = math.min(pre.cursor.row, new.cursor.row)
        local maxrow = math.max(pre.cursor.row, new.cursor.row)
        for _, text_edit in ipairs(text_edits) do
          local srow = text_edit.range.start.line + 1
          local erow = text_edit.range['end'].line + 1
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
  end

  -- Prepare completion item for confirmation
  local completion_item = misc.copy(e:get_completion_item())
  if not misc.safe(completion_item.textEdit) then
    completion_item.textEdit = {}
    completion_item.textEdit.newText = misc.safe(completion_item.insertText) or completion_item.label
  end
  local behavior = option.behavior or config.get().confirmation.default_behavior
  if behavior == types.cmp.ConfirmBehavior.Replace then
    completion_item.textEdit.range = e:get_replace_range()
  else
    completion_item.textEdit.range = e:get_insert_range()
  end

  -- First, emulates vim's `<C-y>` behavior and then confirms LSP functionalities.
  patch.apply(
    pre,
    completion_item.textEdit.range,
    e:get_word(),
    vim.schedule_wrap(function()
      vim.fn['cmp#confirm']({
        request_offset = e.context.cursor.col,
        suggest_offset = e:get_offset(),
        completion_item = completion_item,
      })

      -- execute
      e:execute(function()
        core.reset()
        if callback then
          callback()
        end
      end)
    end)
  )
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
