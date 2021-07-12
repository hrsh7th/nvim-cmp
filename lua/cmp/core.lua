local keymap = require('cmp.utils.keymap')
local debug = require('cmp.utils.debug')
local char = require('cmp.utils.char')
local async = require('cmp.utils.async')
local context = require('cmp.context')
local source = require('cmp.source')
local menu = require('cmp.menu')
local misc = require('cmp.utils.misc')
local config = require('cmp.config')
local cmp = require('cmp.types.cmp')
local lsp = require('cmp.types.lsp')

local core = {}

---@type cmp.Menu
core.menu = menu.new(function(c, fallback)
  core.on_commit_character(c, fallback)
end)

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
---@return cmp.Context
core.get_context = function()
  local prev = core.context:clone()
  prev.prev_context = nil
  core.context = context.new(prev)
  return core.context
end

---Get sources that sorted by priority
---@param ctx cmp.Context
---@param statuses cmp.SourceStatus[]
---@return cmp.Source[]
core.get_sources = function(ctx, statuses)
  local sources = {}
  for _, c in ipairs(config.get().sources) do
    for _, s in pairs(core.sources) do
      if c.name == s.name and s:match(ctx) then
        if not statuses or vim.tbl_contains(statuses, s.status) then
          table.insert(sources, s)
        end
      end
    end
  end
  return sources
end

---Check auto-completion
core.autocomplete = function()
  local ctx = core.get_context()

  if core.has_active_entry() then
    return
  end

  debug.log(('ctx: `%s`'):format(ctx.cursor_before_line))
  if ctx:changed(ctx.prev_context) then
    debug.log('changed')
    core.complete(ctx)
  else
    debug.log('unchanged')
  end
end

---Invoke completion
---@param ctx cmp.Context
core.complete = function(ctx)
  core.menu:restore(ctx)
  for _, s in ipairs(core.get_sources(ctx, { source.SourceStatus.WAITING, source.SourceStatus.COMPLETED })) do
    s:complete(ctx, function()
      local new = context.new(ctx)
      if new:changed(new.prev_context) then
        core.complete(core.get_context())
      end
    end)
  end
  core.filter()
end

---Update completion menu
core.filter = async.throttle(function()
  local ctx = core.get_context()
  core.menu:update(ctx, core.get_sources(ctx, { source.SourceStatus.FETCHING, source.SourceStatus.COMPLETED }))
end, 100)

---Select completion item
core.select = function()
  core.menu:select(context.new())
end

---On commit character typed
---@param c string
---@param fallback fun()
core.on_commit_character = function(c, fallback)
  local e = core.menu:get_selected_entry()
  if not (e and not e.confirmed) then
    return fallback()
  end

  if not vim.tbl_contains(e:get_commit_characters(), c) then
    return fallback()
  end

  -- Handle commit characters.
  -- NOTE: This has a lot of cmp specific implementation to make more user-friendly.
  vim.schedule(function()
    local key = keymap.t(keymap.to_key(c))

    -- It's annoying that if invoke 'replace' when the user type '.' so we prevent it.
    core.confirm(e, {
      behavior = char.is_printable(string.byte(key)) and 'insert' or 'replace',
    }, function()
      local ctx = core.get_context()
      local word = e:get_word()
      if string.sub(ctx.cursor_before_line, -#word, ctx.cursor.col - 1) == word and char.is_printable(string.byte(key)) then
        -- Don't reset current completion because reset/filter will occur by the fallback chars.
        fallback()
      else
        core.reset()
      end
    end)
  end)
end

---Confirm completion.
---@param e cmp.Entry
---@param option cmp.ConfirmOption
---@param callback function
core.confirm = function(e, option, callback)
  if not (e and not e.confirmed) then
    return
  end

  debug.log('entry.confirm', e:get_completion_item())

  --@see https://github.com/microsoft/vscode/blob/main/src/vs/editor/contrib/suggest/suggestController.ts#L334
  local pre = context.new()
  if #(misc.safe(e.completion_item.additionalTextEdits) or {}) == 0 then
    local new = context.new(pre)
    e:resolve(function()
      -- has no additionalTextEdits.
      local text_edits = misc.safe(e:get_completion_item().additionalTextEdits) or {}
      if #text_edits == 0 then
        return
      end

      -- cursor.row changed.
      if pre.cursor.row ~= new.cursor.row then
        return
      end

      -- check additionalTextEdits.
      local has_cursor_line_text_edit = (function()
        for _, text_edit in ipairs(text_edits) do
          local srow = text_edit.range.start.line + 1
          local erow = text_edit.range['end'].line + 1
          if srow <= new.cursor.row and new.cursor.row <= erow then
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

  -- confirm
  local completion_item = misc.copy(e:get_completion_item())
  if not misc.safe(completion_item.textEdit) then
    completion_item.textEdit = {}
    completion_item.textEdit.newText = misc.safe(completion_item.insertText) or completion_item.label
  end
  local behavior = option.behavior or config.get().default_confirm_behavior
  if behavior == cmp.ConfirmBehavior.Replace then
    completion_item.textEdit.range = lsp.Range.from_vim('%', e:get_replace_range())
  else
    completion_item.textEdit.range = lsp.Range.from_vim('%', e:get_insert_range())
  end
  vim.fn['cmp#confirm']({
    request_offset = e.context.cursor.col,
    suggest_offset = e:get_offset(),
    completion_item = completion_item,
  })

  -- execute
  e:execute(function()
    e.confirmed = true
    callback()
  end)
end

---Get current active entry
---@return boolean
core.has_active_entry = function()
  local completed_item = vim.v.completed_item or {}
  if vim.fn.pumvisible() == 0 or not completed_item.user_data then
    return false
  end
  return completed_item.user_data.cmp ~= nil
end

---Reset current completion state
core.reset = function()
  for _, s in pairs(core.sources) do
    s:reset()
  end
  core.menu:reset()

  core.get_context()
end

return core
