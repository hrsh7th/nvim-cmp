local keymap = require'cmp.utils.keymap'
local char = require'cmp.utils.char'
local context = require'cmp.context'
local source = require'cmp.source'
local menu = require'cmp.menu'

local core = {}

---@type table<number, cmp.Source>
core.sources = {}

---@type cmp.Context
core.context = context.new()

---Register source
---@param s cmp.Source
core.register_source = function(s)
  core.sources[s.id] = s
  s:subscribe(function(req_ctx, change_kind)
    if change_kind == source.ChangeKind.UPDATE then
      menu.set(req_ctx, s)
      menu.update(core.get_context(), menu.FilterKind.REFRESH)
    else
      menu.update(core.get_context(), menu.FilterKind.INCREMENTAL)
    end
  end)
end

---Unregister source
---@param source_id string
core.unregister_source = function(source_id)
  local s = core.sources[source_id]
  if s then
    s:reset()
    s:unsubscribe()
  end
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
---@return cmp.Source[]
core.get_sources = function(ctx)
  local sources = {}
  for _, s in pairs(core.sources) do
    if s:match(ctx) then
      table.insert(sources, s)
    end
  end
  return sources
end

---Check auto-completion
core.autocomplete = function()
  local ctx = core.get_context()
  if ctx:is_new_context() then
    core.complete(ctx)
  end
end

---Invoke completion
---@param ctx cmp.Context
core.complete = function(ctx)
  local completion = false
  for _, s in ipairs(core.get_sources(ctx)) do
    completion = s:complete(ctx) or completion
  end
  if not completion then
    menu.update(ctx)
  else
    menu.restore(ctx)
  end
end

---Select completion item
core.select = function()
  local e = menu.get_selected_item()
  if e then
    for _, c in ipairs(e:get_commit_characters()) do
      keymap.listen(c, (function(_)
        return function()
          return core.on_commit_char(_)
        end
      end)(c))
    end
  end
end

---On commit character typed
---@param c string
core.on_commit_char = function(c)
  local e = menu.get_selected_item()
  if not (e and not e.confirmed) then
    return true
  end

  if not vim.tbl_contains(e:get_commit_characters(), c) then
    return true
  end

  vim.schedule(function()
    core.confirm(e)

    -- NOTE: This is cmp specific implementation to support commitCharacters more user friendly.
    local ctx = core.get_context()
    local word = e:get_word_and_abbr().word
    if string.sub(ctx.cursor_before_line, -#word, ctx.cursor.col - 1) == word then
      local key = keymap.t(keymap.to_key(c))
      if char.is_printable(string.byte(key)) then
        vim.fn.feedkeys(key, 'ni')
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
  vim.fn.complete(1, {}) -- Close current menu TODO: adhoc
end

---Reset current completion state
core.reset = function()
  local ctx = core.get_context()
  for _, s in ipairs(core.get_sources(ctx)) do
    s:reset(ctx)
  end
  menu.reset()
end

return core

