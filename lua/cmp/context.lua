local misc = require('cmp.utils.misc')
local pattern = require('cmp.utils.pattern')
local types = require('cmp.types')
local cache = require('cmp.utils.cache')

---@class cmp.Context
---@field public id string
---@field public cache cmp.Cache
---@field public prev_context cmp.Context
---@field public option cmp.ContextOption
---@field public pumvisible boolean
---@field public pumselect  boolean
---@field public filetype string
---@field public time number
---@field public mode string
---@field public bufnr number
---@field public virtcol number
---@field public cursor vim.Position|lsp.Position
---@field public cursor_line string
---@field public cursor_after_line string
---@field public cursor_before_line string
local context = {}

---Create new empty context
---@return cmp.Context
context.empty = function()
  local ctx = context.new({}) -- dirty hack to prevent recursive call `context.empty`.
  ctx.bufnr = -1
  ctx.input = ''
  ctx.cursor = {}
  ctx.cursor.row = -1
  ctx.cursor.col = -1
  return ctx
end

---Create new context
---@param prev_context cmp.Context
---@param option cmp.ContextOption
---@return cmp.Context
context.new = function(prev_context, option)
  option = option or {}

  local self = setmetatable({}, { __index = context })
  local completeinfo = vim.fn.complete_info({ 'selected', 'mode', 'pum_visible' })
  self.id = misc.id('context')
  self.cache = cache.new()
  self.prev_context = prev_context or context.empty()
  self.option = option or { reason = types.cmp.ContextReason.None }
  self.pumvisible = completeinfo.pum_visible ~= 0
  self.pumselect = completeinfo.selected ~= -1
  self.filetype = vim.api.nvim_buf_get_option(0, 'filetype')
  self.time = vim.loop.now()
  self.mode = vim.api.nvim_get_mode().mode
  self.bufnr = vim.api.nvim_get_current_buf()
  self.cursor_line = vim.api.nvim_get_current_line()
  self.virtcol = vim.fn.virtcol('.')
  self.cursor = {}
  local cursor = vim.api.nvim_win_get_cursor(0)
  self.cursor.row = cursor[1]
  self.cursor.col = cursor[2] + 1
  self.cursor.line = self.cursor.row - 1
  self.cursor.character = misc.to_utfindex(self.cursor_line, self.cursor.col)
  self.cursor_before_line = string.sub(self.cursor_line, 1, self.cursor.col - 1)
  self.cursor_after_line = string.sub(self.cursor_line, self.cursor.col)
  return self
end

---Return context creation reason.
---@return cmp.ContextReason
context.get_reason = function(self)
  return self.option.reason
end

---Get keyword pattern offset
---@return number|nil
context.get_offset = function(self, keyword_pattern)
  return self.cache:ensure({ 'get_offset', keyword_pattern, self.cursor_before_line }, function()
    return pattern.offset(keyword_pattern .. '$', self.cursor_before_line) or self.cursor.col
  end)
end

---if cursor moves from left to right.
---@param self cmp.Context
context.is_forwarding = function(self)
  local prev = self.prev_context
  local curr = self

  return prev.bufnr == curr.bufnr and prev.cursor.row == curr.cursor.row and prev.cursor.col < curr.cursor.col
end

---Return if this context is continueing previous context.
context.continue = function(self, offset)
  local prev = self.prev_context
  local curr = self

  if curr.bufnr ~= prev.bufnr then
    return false
  end
  if curr.cursor.row ~= prev.cursor.row then
    return false
  end
  if curr.cursor.col < offset then
    return false
  end
  return true
end

---Return if this context is changed from previous context or not.
---@return boolean
context.changed = function(self, ctx)
  local curr = self

  if self.pumvisible then
    local completed_item = vim.v.completed_item or {}
    if completed_item.word then
      return false
    end
  end

  if curr.bufnr ~= ctx.bufnr then
    return true
  end
  if curr.cursor.row ~= ctx.cursor.row then
    return true
  end
  if curr.cursor.col ~= ctx.cursor.col then
    return true
  end
  if curr:get_reason() == types.cmp.ContextReason.Manual then
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
