local types = require('cmp.types')
local misc = require('cmp.utils.misc')

local compare = {}

-- offset
compare.offset = function(entry1, entry2)
  local diff = entry1:get_offset() - entry2:get_offset()
  if diff < 0 then
    return true
  elseif diff > 0 then
    return false
  end
end

-- exact
compare.exact = function(entry1, entry2)
  if entry1.exact ~= entry2.exact then
    return entry1.exact
  end
end

-- score
compare.score = function(entry1, entry2)
  local diff = entry2.score - entry1.score
  if diff < 0 then
    return true
  elseif diff > 0 then
    return false
  end
end

-- recently_used
compare.recently_used = setmetatable({
  records = {},
  add_entry = function(self, e)
    self.records[e.completion_item.label] = vim.loop.now()
  end,
}, {
  __call = function(self, entry1, entry2)
    local t1 = self.records[entry1.completion_item.label] or -1
    local t2 = self.records[entry2.completion_item.label] or -1
    if t1 ~= t2 then
      return t1 > t2
    end
  end,
})

-- kind
compare.kind = function(entry1, entry2)
  local kind1 = entry1:get_kind()
  kind1 = kind1 == types.lsp.CompletionItemKind.Text and 100 or kind1
  local kind2 = entry2:get_kind()
  kind2 = kind2 == types.lsp.CompletionItemKind.Text and 100 or kind2
  if kind1 ~= kind2 then
    if kind1 == types.lsp.CompletionItemKind.Snippet then
      return true
    end
    if kind2 == types.lsp.CompletionItemKind.Snippet then
      return false
    end
    local diff = kind1 - kind2
    if diff < 0 then
      return true
    elseif diff > 0 then
      return false
    end
  end
end

-- sortText
compare.sort_text = function(entry1, entry2)
  if misc.safe(entry1.completion_item.sortText) and misc.safe(entry2.completion_item.sortText) then
    local diff = vim.stricmp(entry1.completion_item.sortText, entry2.completion_item.sortText)
    if diff < 0 then
      return true
    elseif diff > 0 then
      return false
    end
  end
end

-- length
compare.length = function(entry1, entry2)
  local diff = #entry1.completion_item.label - #entry2.completion_item.label
  if diff < 0 then
    return true
  elseif diff > 0 then
    return false
  end
end

-- order
compare.order = function(entry1, entry2)
  local diff = entry1.id - entry2.id
  if diff < 0 then
    return true
  elseif diff > 0 then
    return false
  end
end

-- scopes
compare.scopes = setmetatable({
  scopes_map = {},
  update = function(self)
    local config = require('cmp').get_config()
    if not vim.tbl_contains(config.sorting.comparators, compare.scopes) then
      return
    end

    local ok, locals = pcall(require, 'nvim-treesitter.locals')
    if ok then
      local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
      local cursor_row = vim.api.nvim_win_get_cursor(win)[1] - 1
      local ts_utils = require('nvim-treesitter.ts_utils')

      -- Cursor scope.
      local cursor_scope = nil
      for _, scope in ipairs(locals.get_scopes(buf)) do
        if not cursor_scope then
          cursor_scope = scope
        else
          if scope:start() <= cursor_row and cursor_row <= scope:end_() then
            if math.abs(scope:end_() - scope:start()) < math.abs(cursor_scope:end_() - cursor_scope:start()) then
              cursor_scope = scope
            end
          end
        end
      end

      -- Definitions.
      local definitions = locals.get_definitions_lookup_table(buf)

      -- Narrow definitions.
      local depth = 0
      for scope in locals.iter_scope_tree(cursor_scope, buf) do
        -- Check scope's direct child.
        for _, definition in pairs(definitions) do
          if scope:id() == locals.containing_scope(definition.node, buf):id() then
            local text = ts_utils.get_node_text(definition.node)[1]
            if not self.scopes_map[text] then
              self.scopes_map[text] = depth
            end
          end
        end
        depth = depth + 1
      end
    end
  end,
}, {
  __call = function(self, entry1, entry2)
    local local1 = self.scopes_map[entry1:get_completion_item().label]
    local local2 = self.scopes_map[entry2:get_completion_item().label]
    if local1 ~= local2 then
      if local1 == nil then
        return false
      end
      if local2 == nil then
        return true
      end
      return local1 < local2
    end
  end,
})

return compare
