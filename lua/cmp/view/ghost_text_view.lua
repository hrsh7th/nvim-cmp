local config = require('cmp.config')
local str = require('cmp.utils.str')
local types = require('cmp.types')

---@class cmp.GhostTextView
local ghost_text_view = {}

ghost_text_view.ns = vim.api.nvim_create_namespace('cmp:GHOST_TEXT')

ghost_text_view.new = function()
  local self = setmetatable({}, { __index = ghost_text_view })
  return self
end

---Show ghost text
---@param e cmp.Entry
ghost_text_view.show = function(_, e)
  vim.api.nvim_buf_clear_namespace(0, ghost_text_view.ns, 0, -1)

  local c = config.get().experimental.ghost_text
  if not c then
    return
  end

  if not e then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = vim.api.nvim_get_current_line()
  local after = string.sub(current_line, cursor[2] + 1)
  if after ~= '' then
    return
  end

  local diff = 1 + cursor[2] - e:get_offset()
  local text = e:get_insert_text()
  if e.completion_item.insertTextFormat == types.lsp.InsertTextFormat.Snippet then
    text = vim.lsp.util.parse_snippet(text)
  end
  text = string.sub(str.oneline(text), diff + 1)
  if #text > 0 then
    vim.api.nvim_buf_set_extmark(0, ghost_text_view.ns, cursor[1] - 1, cursor[2], {
      right_gravity = false,
      virt_text = { { text, c.hl_group or 'Comment' } },
      virt_text_pos = 'overlay',
      hl_mode = 'combine',
      priority = 1,
    })
  end
end

ghost_text_view.hide = function()
  vim.api.nvim_buf_clear_namespace(0, ghost_text_view.ns, 0, -1)
end

return ghost_text_view
