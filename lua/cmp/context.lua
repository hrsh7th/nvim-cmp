local misc = require'cmp.utils.misc'
local pattern = require "cmp.utils.pattern"

local DEFAULT_PATTERN = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]]

---@class cmp.Context
---@field public id string
---@field public prev_context cmp.Context
---@field public pumvisible boolean
---@field public pumselect  boolean
---@field public filetype string
---@field public mode string
---@field public bufnr number
---@field public cursor vim.Position
---@field public cursor_line string
---@field public cursor_after_line string
---@field public cursor_before_line string
---@field public offset number
---@field public offset_after_line string
---@field public offset_before_line string
---@field public input string
---@field public before_char string
---@field public insert_range vim.Range
---@field public replace_range vim.Range
local context = {}

---Create new empty context
---@return cmp.Context
context.empty = function()
  local ctx = context.new({}) -- dirty hack to prevent recursive call `context.empty`.
  ctx.bufnr = -1
  ctx.cursor = {}
  ctx.cursor.row = -1
  ctx.cursor.col = -1
  return ctx
end

---Create new context
---@param prev_context cmp.Context
---@return cmp.Context
context.new = function(prev_context, option)
  option = option or {}

  local self = setmetatable({}, { __index = context })
  local completeinfo = vim.fn.complete_info({ 'selected', 'mode', 'pum_visible' })
  self.id = misc.id('context')
  self.prev_context = prev_context or context.empty()
  self.manual = option.manual or false
  self.pumvisible = completeinfo.pum_visible ~= 0
  self.pumselect = completeinfo.selected ~= -1
  self.filetype = vim.api.nvim_buf_get_option(0, 'filetype')
  self.mode = vim.api.nvim_get_mode().mode
  self.bufnr = vim.api.nvim_get_current_buf()
  self.cursor = {}
  self.cursor.row = vim.api.nvim_win_get_cursor(0)[1]
  self.cursor.col = vim.api.nvim_win_get_cursor(0)[2] + 1
  self.cursor_line = vim.api.nvim_get_current_line()
  self.cursor_before_line = string.sub(self.cursor_line, 1, self.cursor.col - 1)
  self.cursor_after_line = string.sub(self.cursor_line, 1, self.cursor.col - 1)
  self.offset = pattern.offset(DEFAULT_PATTERN .. '$', self.cursor_before_line) or self.cursor.col
  self.offset_before_line = string.sub(self.cursor_line, 1, self.offset - 1)
  self.offset_after_line = string.sub(self.cursor_line, self.offset)
  self.input = string.sub(self.cursor_line, self.offset, self.cursor.col - 1)
  self.before_char = string.sub(self.cursor_line, self.cursor.col - 1, self.cursor.col - 1)
  self.insert_range = {
    start = {
      row = self.cursor.row,
      col = self.offset,
    },
    ['end'] = {
      row = self.cursor.row,
      col = self.cursor.col
    }
  }
  self.replace_range = {
    start = {
      row = self.cursor.row,
      col = self.offset,
    },
    ['end'] = {
      row = self.cursor.row,
      col = (function()
        local _, e = pattern.offset('^' .. DEFAULT_PATTERN, self.offset_after_line)
        if e then
          return self.offset + e - 1
        end
        return self.insert_range['end'].col
      end)()
    }
  }
  return self
end

---Return if keyword was beginning or not.
---@return boolean
context.is_keyword_beginning = function(self)
  local prev = self.prev_context
  local curr = self

  return (prev.offset ~= curr.offset or prev.input == '') and curr.input ~= ''
end

---if cursor moves from left to right.
---@param self cmp.Context
context.is_forwarding = function(self)
  local prev = self.prev_context
  local curr = self

  return prev.cursor.col < curr.cursor.col
end

---Return if this context is continueing previous context.
context.maybe_continue = function(self, suggest_offset)
  local prev = self.prev_context
  local curr = self

  if curr.bufnr ~= prev.bufnr then
    return false
  end
  if curr.cursor.row ~= prev.cursor.row then
    return false
  end
  if suggest_offset then
    if curr.cursor.col < suggest_offset then
      return false
    end
  end
  return true
end

---Return if this context is changed from previous context or not.
---@return boolean
context.changed = function(self)
  local prev = self.prev_context
  local curr = self

  if self.pumvisible then
    if vim.v.completed_item and vim.v.completed_item.word then
      return false
    end
  end

  if curr.bufnr ~= prev.bufnr then
    return true
  end
  if curr.cursor.row ~= prev.cursor.row then
    return true
  end
  if curr.cursor.col ~= prev.cursor.col then
    return true
  end

  return false
end

---Shallow clone
context.clone = function(self)
  local cloned = {}
  for k, v in pairs(self) do
    cloned[k] = v
  end
  return cloned
end

return context

