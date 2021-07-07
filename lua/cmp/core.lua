local keymap = require'cmp.utils.keymap'
local debug = require'cmp.utils.debug'
local char = require'cmp.utils.char'
local async = require'cmp.utils.async'
local context = require'cmp.context'
local source = require'cmp.source'
local menu = require'cmp.menu'

local core = {}

---@type table<number, cmp.Source>
core.sources = {}

---@type cmp.Context
core.context = context.new()

---@type number
core.namespace = vim.api.nvim_create_namespace('cmp')

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
  for _, s in pairs(core.sources) do
    if s:match(ctx) and (not statuses or vim.tbl_contains(statuses, s.status)) then
      table.insert(sources, s)
    end
  end
  return sources
end

---Check auto-completion
core.autocomplete = function()
  local ctx = core.get_context()
  debug.log(('ctx: `%s`'):format(ctx.cursor_before_line))
  if ctx:changed() then
    debug.log('changed')
    core.complete(ctx)
  else
    debug.log('unchanged')
  end
end

---Invoke completion
---@param ctx cmp.Context
core.complete = function(ctx)
  menu.restore(ctx)

  local triggered = false
  for _, s in ipairs(core.get_sources(ctx)) do
    triggered = s:complete(ctx, function()
      if #core.get_sources(ctx, { source.SourceStatus.FETCHING }) > 0 then
        core.update.timeout = 200
      else
        core.update.timeout = 0
      end
      core.update()
    end) or triggered
  end
  if not triggered then
    core.update.timeout = 0
    core.update()
  end
end

---Update completion menu
core.update = async.debounce(function()
  local ctx = core.get_context()
  menu.update(ctx, core.get_sources(ctx, { source.SourceStatus.FETCHING, source.SourceStatus.COMPLETED }))
end, 200)

---Select completion item
core.select = function()
  local e = menu.get_selected_item()
  if e then
    -- Add commit character listeners.
    for _, key in ipairs(e:get_commit_characters()) do
      keymap.listen(key, (function(k)
        return function(fallback)
          return core.on_commit_char(k, fallback)
        end
      end)(key))
    end

    -- Highlight replace range.
    vim.api.nvim_buf_clear_namespace(0, core.namespace, 0, -1)
    local replace_range = e:get_replace_range()
    if replace_range then
      local ctx = core.get_context()
      vim.api.nvim_buf_set_extmark(0, core.namespace, ctx.cursor.row - 1, ctx.cursor.col - 1, {
        end_line = ctx.cursor.row - 1,
        end_col = ctx.cursor.col + replace_range['end'].col - e.context.cursor.col - 1,
        hl_group = 'CmpReplaceRange',
      })
    end

    -- Documentation
  end
end

---On commit character typed
---@param c string
---@param fallback fun()
core.on_commit_char = function(c, fallback)
  local e = menu.get_selected_item()
  if not (e and not e.confirmed) then
    return fallback()
  end

  if not vim.tbl_contains(e:get_commit_characters(), c) then
    return fallback()
  end

  vim.schedule(function()
    core.confirm(e)

    -- NOTE: This is cmp specific implementation to support commitCharacters more user friendly.
    local ctx = core.get_context()
    local word = e:get_word()
    if string.sub(ctx.cursor_before_line, -#word, ctx.cursor.col - 1) == word then
      local key = keymap.t(keymap.to_key(c))
      if char.is_printable(string.byte(key)) then
        fallback()
      end
    end
  end)
end

---Confirm completion.
---@param e cmp.Entry
core.confirm = function(e)
  if not (e and not e.confirmed) then
    return
  end
  e:confirm(menu.state.offset)
  core.reset()
end

---Reset current completion state
core.reset = function()
  core.get_context() -- reset for new context
  menu.reset()
  for _, s in pairs(core.sources) do
    s:reset()
  end
  vim.api.nvim_buf_clear_namespace(0, core.namespace, 0, -1)
end

return core

