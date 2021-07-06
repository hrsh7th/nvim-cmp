local binary = require'cmp.utils.binary'
local debug = require'cmp.utils.debug'
local matcher = require'cmp.matcher'

local menu = {}

---@alias cmp.FilterKind "1" | "2"
menu.FilterKind = {}
menu.FilterKind.CONTINUE = 1
menu.FilterKind.REFRESH = 2

---@class cmp.State
---@field public offset number|nil
---@field public entries cmp.Entry[]
---@field public filtered_entries cmp.Entry[]
---@field public context cmp.Context
menu.state = {}
menu.state.offset = nil
menu.state.entries = {}
menu.state.filtered_entries = {}
menu.state.filtered_items = {}
menu.state.context = nil

---Get active item
---@return cmp.Entry|nil
menu.get_active_item = function()
  -- TODO: vim.v.completed_item would remain even after completion so it may cause bugs.
  local completed_item = vim.v.completed_item
  if not completed_item or not completed_item.word or not completed_item.user_data then
    return nil
  end

  local id = completed_item.user_data.cmp
  for _, e in ipairs(menu.state.filtered_entries) do
    if e.id == id then
      return e
    end
  end
  return nil
end

---Get selected item
---@return cmp.Entry|nil
menu.get_selected_item = function()
  local info = vim.fn.complete_info({ 'items', 'selected' })
  if info.selected == -1 then
    return nil
  end

  local completed_item = info.items[math.max(info.selected, 0) + 1]
  if not completed_item or not completed_item.word or not completed_item.user_data then
    return nil
  end

  local id = completed_item.user_data.cmp
  for _, e in ipairs(menu.state.filtered_entries) do
    if e.id == id then
      return e
    end
  end
  return nil
end

---Show completion menu
---@param ctx cmp.Context
menu.update = function(ctx, sources)
  if not (ctx.mode == 'i' or ctx.mode == 'ic') then
    return
  end

  local filtered_entries = {}
  local filtered_items = {}
  local offset = ctx.offset
  for _, s in ipairs(sources) do
    if s.offset ~= nil then
      local input = string.sub(ctx.cursor_line, s.offset, ctx.cursor.col - 1)
      for _, e in ipairs(s.entries) do
        e.score = matcher.match(input, e:get_filter_text())
        if e.score >= 1 then
          offset = math.min(offset, e:get_offset())
          local idx = binary.search(filtered_entries, e, function(a, b)
            -- score
            if a.score ~= b.score then
              return b.score - a.score
            end

            -- sortText
            local a_sort_text = a:get_sort_text()
            local b_sort_text = b:get_sort_text()
            if a_sort_text ~= b_sort_text then
              return vim.stricmp(a_sort_text, b_sort_text)
            end

            return a.id - b.id
          end)
          table.insert(filtered_entries, idx, e)
          table.insert(filtered_items, idx, e:get_vim_item(menu.state.offset))
        end
      end
    end
  end
  menu.state.offset = offset
  menu.state.filtered_entries = filtered_entries
  menu.state.filtered_items = filtered_items
  menu.state.context = ctx

  if vim.fn.pumvisible() == 0 and #filtered_entries == 0 then
    debug.log('menu/not-show')
    return
  end
  debug.log('menu/show', offset, #menu.state.filtered_items)
  vim.fn.complete(offset, menu.state.filtered_items)
end

---Reset current state
menu.reset = function()
  menu.state = {}
  menu.state.offset = nil
  menu.state.entries = {}
  menu.state.filtered_entries = {}
  menu.state.filtered_items = {}
  menu.state.context = nil
  if vim.fn.pumvisible() == 1 then
    vim.fn.complete(1, {})
  end
end

---Restore previous menu
menu.restore = function(ctx)
  if not (ctx.mode == 'i' or ctx.mode == 'ic') then
    return
  end

  if not ctx.pumvisible then
    if #menu.state.filtered_items > 0 then
      if menu.state.offset <= ctx.cursor.col then
        debug.log('menu/restore')
        vim.fn.complete(menu.state.offset, menu.state.filtered_items)
      end
    end
  end
end

return menu

