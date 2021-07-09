local config = require'cmp.config'
local debug = require'cmp.utils.debug'

---@class cmp.Menu
---@field public offset number
---@field public items vim.CompletedItem
---@field public context cmp.Context
local menu = {}

---Create menu
---@return cmp.Menu
menu.new = function()
  local self = setmetatable({}, { __index = menu })
  self:reset()
  return self
end

---Reset menu
menu.reset = function(self)
  self.offset = nil
  self.items = {}
  self.context = nil
  if vim.tbl_contains({ 'i', 'ic' }, vim.api.nvim_get_mode().mode) then
    vim.fn.complete(1, {})
  end
end

---Update menu
---@param ctx cmp.Context
---@param sources cmp.Source[]
---@return cmp.Menu
menu.update = function(self, ctx, sources)
  if not (ctx.mode == 'i' or ctx.mode == 'ic') then
    return
  end

  local entries = {}
  local offset = ctx.offset
  for _, s in ipairs(sources) do
    local i = 1
    for _, e in ipairs(s:get_entries(ctx)) do
      local j = i
      while j <= #entries do
        local cmp = config.get().compare(e, entries[j])
        if cmp <= 0 then
          table.insert(entries, j, e)
          i = j + 1
          break
        end
        j = j + 1
      end
      if j > #entries then
        table.insert(entries, e)
        i = j + 1
      end
      offset = math.min(offset, e:get_offset())
    end
  end

  local items = {}
  local abbrs = {}
  for _, e in ipairs(entries) do
    local item = e:get_vim_item(offset)
    if not abbrs[item.abbr] then
      table.insert(items, item)
      abbrs[item.abbr] = true
    end
  end

  self.offset = offset
  self.items = items
  self.context = ctx

  if vim.fn.pumvisible() == 0 and #items == 0 then
    debug.log('menu/not-show')
    return
  end
  debug.log('menu/show', offset, #self.items)
  vim.fn.complete(offset, self.items)
end

---Restore previous menu
---@param ctx cmp.Context
menu.restore = function(self, ctx)
  if not (ctx.mode == 'i' or ctx.mode == 'ic') then
    return
  end

  if not ctx.pumvisible then
    if #self.items > 0 then
      if self.offset <= ctx.cursor.col then
        debug.log('menu/restore')
        vim.fn.complete(self.offset, self.items)
      end
    end
  end
end

return menu

