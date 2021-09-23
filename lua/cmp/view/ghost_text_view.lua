local config = require('cmp.config')
local str = require('cmp.utils.str')
local types = require('cmp.types')

---@class cmp.GhostTextView
local ghost_text_view = {}

ghost_text_view.ns = vim.api.nvim_create_namespace('cmp:GHOST_TEXT')

ghost_text_view.new = function()
  local self = setmetatable({}, { __index = ghost_text_view })
  self.win = nil
  self.entry = nil
  vim.api.nvim_set_decoration_provider(ghost_text_view.ns, {
    on_win = function(_, win)
      return win == self.win
    end,
    on_line = function()
      local c = config.get().experimental.ghost_text
      if not c then
        return
      end

      if not self.entry then
        return
      end

      local cursor = vim.api.nvim_win_get_cursor(0)
      if string.sub(vim.api.nvim_get_current_line(), cursor[2] + 1) ~= '' then
        return
      end

      local diff = 1 + cursor[2] - self.entry:get_offset()
      local text = self.entry:get_insert_text()
      if self.entry.completion_item.insertTextFormat == types.lsp.InsertTextFormat.Snippet then
        text = vim.lsp.util.parse_snippet(text)
      end
      text = string.sub(str.oneline(text), diff + 1)
      if #text > 0 then
        vim.api.nvim_buf_set_extmark(0, ghost_text_view.ns, cursor[1] - 1, cursor[2], {
          right_gravity = false,
          virt_text = { { text, c.hl_group or 'Comment' } },
          virt_text_pos = 'overlay',
          hl_mode = 'combine',
          ephemeral = true,
        })
      end
    end
  })
  return self
end

---Show ghost text
---@param e cmp.Entry
ghost_text_view.show = function(self, e)
  self.win = vim.api.nvim_get_current_win()
  self.entry = e
end

ghost_text_view.hide = function(self)
  self.win = nil
  self.entry = nil
end

return ghost_text_view

