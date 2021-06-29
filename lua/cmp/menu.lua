local entry = require'cmp.entry'
local binary = require'cmp.utils.binary'
local matcher = require'cmp.matcher'

local menu = {}

menu.FilterKind = {}
menu.FilterKind.REFRESH = 1
menu.FilterKind.INCREMENTAL = 2

---@class cmp.menu.State
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

---Set source
---@param ctx cmp.Context
---@param source cmp.Source
menu.set = function(ctx, source)
  menu.state.offset = ctx.offset

  local i = 1
  while i <= #menu.state.entries do
    if menu.state.entries[i].source == source then
      if i < #source.items then
        local e = entry.new(ctx, source, source.items[i])
        menu.state.entries[i] = e
        menu.state.offset = math.min(menu.state.offset, e:get_offset())
      else
        if i < #menu.state.entries then
          menu.state.entries[i] = menu.state.entries[#menu.state.entries]
          menu.state.entries[#menu.state.entries] = nil
          i = i - 1
        else
          menu.state.entries[#menu.state.entries] = nil
          break
        end
      end
    end
    i = i + 1
  end
  while i <= #source.items do
    local e = entry.new(ctx, source, source.items[i])
    menu.state.entries[i] = e
    menu.state.offset = math.min(menu.state.offset, e:get_offset())
    i = i + 1
  end
end

---Get active item
---@return cmp.Entry|nil
menu.get_active_item = function()
  local completed_item = vim.v.completed_item
  if not completed_item or not completed_item.word or not completed_item.user_data then
    return nil
  end

  local id = completed_item.user_data.cmp
  for _, e in ipairs(menu.state.entries) do
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
  for _, e in ipairs(menu.state.entries) do
    if e.id == id then
      return e
    end
  end
  return nil
end

---Show completion menu
---@param ctx cmp.Context
menu.update = function(ctx, filter_kind)
  if not (ctx.mode == 'i' or ctx.mode == 'ic') then
    return
  end

  local filtered_entries = {}
  local filtered_items = {}
  local input = string.sub(ctx.cursor_line, menu.state.offset or 1, ctx.cursor.col - 1)
  local entries = filter_kind == menu.FilterKind.INCREMENTAL and menu.state.filtered_entries or menu.state.entries
  local preselect = 2
  for _, e in ipairs(entries) do
    e.score = matcher.match(input, e:get_filter_text())
    if e.score >= 1 then
      local idx = binary.search(filtered_entries, e, function(a, b)
        -- score
        if a.score ~= b.score then
          return b.score - a.score
        end

        -- sortText
        local a_sort_text = a:get_sort_text()
        local b_sort_text = b:get_sort_text()
        if a_sort_text ~= b_sort_text then
          return a_sort_text > b_sort_text and 1 or -1
        end

        return 0
      end)
      if preselect > idx then
        preselect = preselect + 1
      end
      if e.completion_item.preselect then
        preselect = math.min(idx, preselect)
      end
      table.insert(filtered_entries, idx, e)
      table.insert(filtered_items, idx, e:get_vim_item(menu.state.offset))
    end
  end
  menu.state.filtered_entires = filtered_entries
  menu.state.filtered_items = filtered_items
  menu.state.context = ctx
  vim.fn.complete(menu.state.offset, menu.state.filtered_items)
  if preselect <= #entries then
    vim.api.nvim_select_popupmenu_item(preselect - 1, false, false, {})
  end
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
        vim.fn.complete(menu.state.offset, menu.state.filtered_items)
      end
    end
  end
end

return menu

