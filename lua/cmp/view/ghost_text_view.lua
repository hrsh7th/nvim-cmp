local config = require('cmp.config')
local misc = require('cmp.utils.misc')
local str = require('cmp.utils.str')
local api = require('cmp.utils.api')

---@class cmp.GhostTextView
local ghost_text_view = {}

ghost_text_view.ns = vim.api.nvim_create_namespace('cmp:GHOST_TEXT')

local has_inline = (function()
  return (pcall(function()
    local id = vim.api.nvim_buf_set_extmark(0, ghost_text_view.ns, 0, 0, {
      virt_text = { { ' ', 'Comment' } },
      virt_text_pos = 'inline',
      hl_mode = 'combine',
      ephemeral = false,
    })
    vim.api.nvim_buf_del_extmark(0, ghost_text_view.ns, id)
  end))
end)()

local ignored_chars = {
   [" "] = true,
   [":"] = true,
   [","] = true,
   [";"] = true,
   ["["] = true,
   ["]"] = true,
   ["{"] = true,
   ["}"] = true,
   ["("] = true,
   [")"] = true,
   ["."] = true,
}

local function ts_get_hl(r, start_pos)
   local hl = "Normal"
   local result = vim.inspect_pos(0, r, start_pos).treesitter
   if #result ~= 0 then
      hl = result[#result].hl_group_link
      if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = hl })) then
         -- lets hope the 2nd last one is valid
         hl = result[#result - 1].hl_group_link
      end
   end
   return hl
end

local function gen_ts_nodes(begin_text,begin_hl,row,col,line)
   local nodes = { { begin_text, begin_hl } }
   col = col + 1
   local start_pos = col
   for i = col, #line, 1 do
      local char = line:sub(i, i)
      if ignored_chars[char] then
         local text
         if i ~= start_pos then
            text = line:sub(start_pos, i - 1)
         else
            -- else we matched 2 ignored_chars
            text = line:sub(start_pos, i)
            -- we could use a cache here to for operators to reduce the inspect_pos calls
            -- but i am not sure how to do that reliably since for example by has # as a comment but lua has it as the size operator
            -- also this means #nodes gets in the line below gets fully highlighted as an operator
            nodes[#nodes + 1] = { text,"Normal" }
            start_pos = i + 1
            goto continue
         end
         local hl = ts_get_hl(row, start_pos - 1)
         nodes[#nodes + 1] = { text, hl }
         start_pos = i + 1
         nodes[#nodes + 1] = { char, "Normal" }
      end
      if i == #line then
         local text = line:sub(start_pos)
         local hl
         if ignored_chars[text] then
            hl = {text,"Normal"}
         else
            hl = ts_get_hl(row, start_pos - 1)
         end

         nodes[#nodes + 1] = { text, hl }
      end
      ::continue::
   end
   return nodes
end


ghost_text_view.new = function()
  local self = setmetatable({}, { __index = ghost_text_view })
  self.win = nil
  self.entry = nil
  vim.api.nvim_set_decoration_provider(ghost_text_view.ns, {
    on_win = function(_, win)
      return win == self.win
    end,
    on_line = function(_, _, _, on_row)
      local c = config.get().experimental.ghost_text
      if not c then
        return
      end

      if not self.entry then
        return
      end

      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      if on_row ~= row - 1 then
        return
      end

      local line = vim.api.nvim_get_current_line()
      local text = self.text_gen(self, line, col)
      if not has_inline then
         local nodes = gen_ts_nodes(
                text, type(c) == 'table' and c.hl_group or 'Comment',
               row,col,line
            )
        vim.api.nvim_buf_set_extmark(0, ghost_text_view.ns, row - 1, col, {
          right_gravity = false,
          virt_text = nodes,
          virt_text_pos = 'overlay',
          hl_mode = 'combine',
          ephemeral = true,
        })
        return
      end

      if #text > 0 then
        vim.api.nvim_buf_set_extmark(0, ghost_text_view.ns, row - 1, col, {
          right_gravity = false,
          virt_text = { { text, type(c) == 'table' and c.hl_group or 'Comment' } },
          virt_text_pos = has_inline and 'inline' or 'overlay',
          hl_mode = 'combine',
          ephemeral = true,
        })
      end
    end,
  })
  return self
end

---Generate the ghost text
---  This function calculates the bytes of the entry to display calculating the number
---  of character differences instead of just byte difference.
ghost_text_view.text_gen = function(self, line, cursor_col)
  local word = self.entry:get_insert_text()
  word = str.oneline(word)
  local word_clen = vim.str_utfindex(word)
  local cword = string.sub(line, self.entry:get_offset(), cursor_col)
  local cword_clen = vim.str_utfindex(cword)
  -- Number of characters from entry text (word) to be displayed as ghost thext
  local nchars = word_clen - cword_clen
  -- Missing characters to complete the entry text
  local text
  if nchars > 0 then
    text = string.sub(word, vim.str_byteindex(word, word_clen - nchars) + 1)
  else
    text = ''
  end
  return text
end

---Show ghost text
---@param e cmp.Entry
ghost_text_view.show = function(self, e)
  if not api.is_insert_mode() then
    return
  end
  local c = config.get().experimental.ghost_text
  if not c then
    return
  end
  local changed = e ~= self.entry
  self.win = vim.api.nvim_get_current_win()
  self.entry = e
  if changed then
    misc.redraw(true) -- force invoke decoration provider.
  end
end

ghost_text_view.hide = function(self)
  if self.win and self.entry then
    self.win = nil
    self.entry = nil
    misc.redraw(true) -- force invoke decoration provider.
  end
end

return ghost_text_view
