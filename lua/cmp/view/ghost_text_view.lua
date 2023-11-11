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

   [","] = true,
   ["."] = true,

   [":"] = true,
   [";"] = true,


   ["["] = true,
   ["]"] = true,

   ["{"] = true,
   ["}"] = true,

   ["("] = true,
   [")"] = true,

   [">"] = true,
   ["="] = true,
   ["<"] = true,

   ["$"] = true,
   ["&"] = true,
   ["#"] = true,

   ["^"] = true,
   ["%"] = true,
   ["+"] = true,
   ["-"] = true,
   ["*"] = true,
   ["/"] = true,
   ["\\"] = true,
   ["\""] = true,
   ["\'"] = true,
}

local function hl_iscleared(hl_name)
   return  vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = hl_name }))
end

local function get_hl(r, pos)
   pos = pos - 1
   local result = vim.inspect_pos(0, r, pos)
   local lsp_hls = result.semantic_tokens
   if #lsp_hls ~= 0 then
      local hl
      local priority = 0
      for _,lsp_hl in pairs(lsp_hls)  do
         local opts = lsp_hl.opts
         if priority < opts.priority and
            not hl_iscleared(opts.hl_group_link)
         then
            hl = opts.hl_group_link
            priority = opts.priority
         end
      end
      if hl then
         return hl
      end
   end
   local ts_hls = result.treesitter
   if #ts_hls ~= 0 then
      for i = #ts_hls,0,-1 do
         if not hl_iscleared(ts_hls[i].hl_group_link) then
            return ts_hls[i].hl_group_link
         end
      end
   end
   local syntax_hls = result.syntax
   if #syntax_hls ~= 0 then
      -- FIXME: checking if a highlight group in sytnax_hls is cleared crashes neovim with error 139
      -- couldn't track the exact highlight group
      return syntax_hls[#syntax_hls].hl_group_link
   end
   return "Normal"
end

local cached_line
local cached_nodes
local cached_line_row
local function gen_hl_nodes(begin_text,begin_hl,row,col,line)
   col = col + 1
   row = row - 1
   if cached_line_row == row and cached_line == line:sub(col) then
      cached_nodes[1] = { begin_text, begin_hl }
      return cached_nodes
   end
   local nodes = { { begin_text, begin_hl } }
   local node_start = col
   for i = col, #line, 1 do
      local char = line:sub(i, i)
      if ignored_chars[char] then
         if node_start == i then
            local text = line:sub(node_start, i)
            local hl = char == ' ' and 'Normal' or get_hl(row,i)
            table.insert(nodes,{ text,hl })
            node_start = i + 1
            goto continue
         end
         local text = line:sub(node_start, i - 1)
         table.insert(nodes,{ text, get_hl(row, node_start)})
         node_start = i + 1
         local hl = char == ' ' and 'Normal' or get_hl(row,i)
         table.insert(nodes,{ char,hl })
      end
      if i == #line then
         local text = line:sub(node_start)
         table.insert(nodes,{ text, get_hl(row, node_start)})
      end
      ::continue::
   end
   cached_nodes = nodes
   cached_line_row = row
   cached_line = line:sub(col)
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
      if not has_inline then
        if type(c) == 'table' and c.inline_emulation then
          local text = self.text_gen(self, line, col)
          local nodes = gen_hl_nodes(
            text,c.hl_group or 'Comment',
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
        else
          if string.sub(line, col + 1) ~= '' then
            return
          end
        end
      end
     local text = self.text_gen(self, line, col)

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
