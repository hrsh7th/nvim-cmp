local async = require'cmp.utils.async'
local cache = require'cmp.utils.cache'
local char = require'cmp.utils.char'
local misc = require'cmp.utils.misc'
local str = require "cmp.utils.str"
local config = require'cmp.config'
local lsp = require "cmp.types.lsp"

---@class cmp.Entry
---@field public id number
---@field public cache cmp.utils.Cache
---@field public score number
---@field public context cmp.Context
---@field public source cmp.Source
---@field public completion_item lsp.CompletionItem
---@field public resolved_completion_item lsp.CompletionItem|nil
---@field public resolved_callbacks fun()[]
---@field public resolving boolean
---@field public confirmed boolean
---@field public insert_range vim.Range
---@field public replace_range vim.Range
local entry = {}

---Create new entry
---@param ctx cmp.Context
---@param source cmp.Source
---@param completion_item lsp.CompletionItem
---@return cmp.Entry
entry.new = function(ctx, source, completion_item)
  local self = setmetatable({}, { __index = entry })
  self.id = misc.id('entry')
  self.cache = cache.new()
  self.score = 0
  self.context = ctx
  self.source = source
  self.completion_item = completion_item
  self.resolved_completion_item = nil
  self.resolved_callbacks = {}
  self.resolving = false
  self.confirmed = false

  if misc.safe(self.completion_item.textEdit) then
    if misc.safe(self.completion_item.textEdit.insert) then
      self.insert_range = lsp.Range.to_vim(ctx.bufnr, self.completion_item.textEdit.insert)
    else
      self.insert_range = lsp.Range.to_vim(ctx.bufnr, self.completion_item.textEdit.range)
    end
  end
  self.insert_range = self.insert_range or ctx.insert_range

  if misc.safe(self.completion_item.textEdit) then
    if misc.safe(self.completion_item.textEdit.replace) then
      self.replace_range = lsp.Range.to_vim(ctx.bufnr, self.completion_item.textEdit.replace)
    else
      self.replace_range = lsp.Range.to_vim(ctx.bufnr, self.completion_item.textEdit.range)
    end
  end
  self.replace_range = self.replace_range or ctx.replace_range

  return self
end

---Make offset value
---@return number
entry.get_offset = function(self)
  return self.cache:ensure('get_offset', function()
    local offset = self.context.offset
    local word_and_abbr = self:get_word_and_abbr()
    if misc.safe(self.completion_item.textEdit) then
      local c = string.byte(word_and_abbr.word, 1)
      for _, range in ipairs({ self.completion_item.textEdit.insert or vim.NIL, self.completion_item.textEdit.range or vim.NIL }) do
        if misc.safe(range) then
          for idx = range.start.character + 1, self.context.offset do
            if c == string.byte(self.context.cursor_line, idx) then
              offset = math.min(offset, idx)
            end
          end
        end
      end
    else
      -- NOTE
      -- The VSCode does not implement this but it's useful if the server does not care about word patterns.
      -- We should care about this performance.
      for idx = #self.context.offset_before_line, #self.context.offset_before_line - #word_and_abbr.word + 1, -1 do
        local c = string.byte(self.context.offset_before_line, idx)
        if char.is_white(c) then
          break
        end
        if char.is_semantic_index(self.context.offset_before_line, idx) then
          local match = true
          for i = 1, #self.context.offset_before_line - idx + 1  do
            local c1 = string.byte(word_and_abbr.word, i)
            local c2 = string.byte(self.context.offset_before_line, idx + i - 1)
            if not c1 or not c2 or c1 ~= c2 then
              match = false
              break
            end
          end
          if match then
            offset = math.min(offset, idx)
          end
        end
      end
    end
    return offset
  end)
end

---Create word and abbr for vim.CompletedItem
---@return table<string, string>
entry.get_word_and_abbr = function(self)
  return self.cache:ensure('get_word_and_abbr', function()
    --- create word and abbr.
    local word
    local abbr
    local expandable = false
    if self.completion_item.insertTextFormat == 2 then
      abbr = str.trim(self.completion_item.label)
      if misc.safe(self.completion_item.textEdit) then
        word = str.trim(self.completion_item.textEdit.newText)
        word = str.get_word(word)
        expandable = true
      elseif misc.safe(self.completion_item.insertText) then
        word = str.trim(self.completion_item.insertText)
        word = str.get_word(word)
        expandable = true
      else
        word = str.trim(self.completion_item.label)
      end
    else
      word = str.trim(self.completion_item.insertText or self.completion_item.label)
      abbr = str.trim(self.completion_item.label)
    end
    return { word = word or '', abbr = abbr or '', expandable = expandable, }
  end)
end

---Make vim.CompletedItem
---@param offset number
---@return vim.CompletedItem
entry.get_vim_item = function(self, offset)
  return self.cache:ensure({ 'get_vim_item', offset }, function()
    local word_and_abbr = self:get_word_and_abbr()
    local word = word_and_abbr.word
    local abbr = word_and_abbr.abbr
    local expandable = word_and_abbr.expandable

    local own_offset = self:get_offset()
    if misc.safe(self.completion_item.textEdit) and offset ~= own_offset then
      word = string.sub(self.context.offset_before_line, offset, own_offset - 1) .. word
    end

    if expandable then
      abbr = abbr .. '~'
    end

    return config.get().format(self, word, abbr)
  end)
end

---Create filter text
---@return string
entry.get_filter_text = function(self)
  return self.cache:ensure('get_filter_text', function()
    if misc.safe(self.completion_item.filterText) then
      return self.completion_item.filterText
    end
    return self.completion_item.label
  end)
end

---Return sort text
---@return string
entry.get_sort_text = function(self)
  return self.cache:ensure('get_sort_text', function()
    if misc.safe(self.completion_item.sortText) then
      return self.completion_item.sortText
    end
    return self.completion_item.label
  end)
end

---Get commit characters
---@return string[]
entry.get_commit_characters = function(self)
  local commit_characters = {}
  local completion_item = self:get_completion_item()
  if completion_item.commitCharacters then
    misc.merge(commit_characters, commit_characters)
  end
  if type(config.get().commit_characters) =='function' then
    misc.merge(commit_characters, config.get().commit_characters(self))
  else
    misc.merge(commit_characters, config.get().commit_characters)
  end
  return commit_characters
end

---Return replace range if it's different with insert range.
---@param ctx cmp.Context
---@return vim.Range|nil
entry.get_replace_range = function(self, ctx)
  local same = true
  same = same and self.insert_range.start.row == self.replace_range.start.row
  same = same and self.insert_range.start.col == self.replace_range.start.col
  same = same and self.insert_range['end'].row == self.replace_range['end'].row
  same = same and self.insert_range['end'].col == self.replace_range['end'].col
  if same then
    return nil
  end
  return self.replace_range
end

---Get resolved completion item if possible.
---@return lsp.CompletionItem
entry.get_completion_item = function(self)
  if self.resolved_completion_item then
    return self.resolved_completion_item
  end
  return self.completion_item
end

---Confirm completion item
---@param offset number
---@param callback fun()|nil
entry.confirm = function(self, offset, callback)
  -- resolve
  async.sync(function(done)
    self:resolve(done)
  end, 1000)

  -- confirm
  local completion_item = misc.copy(self:get_completion_item())
  if not misc.safe(completion_item.textEdit) then
    completion_item.textEdit = {}
    completion_item.textEdit.newText = misc.safe(completion_item.insertText) or completion_item.label
  end
  if config.get().default_insert_mode == 'replace' then
    completion_item.textEdit.range = lsp.Range.from_vim('%', self.replace_range)
  else
    completion_item.textEdit.range = lsp.Range.from_vim('%', self.insert_range)
  end
  vim.fn['cmp#confirm']({
    request_offset = self.context.cursor.col,
    suggest_offset = offset,
    completion_item = completion_item,
  })

  -- execute
  async.sync(function(done)
    self:execute(done)
  end, 1000)

  self.confirmed = true

  if callback then
    callback()
  end
end

---Execute completion item's command.
---@param callback fun()
entry.execute = function(self, callback)
  self.source:execute(self:get_completion_item(), callback)
end

---Resolve completion item.
---@param callback fun()
entry.resolve = function(self, callback)
  if self.resolved_completion_item then
    return callback()
  end
  table.insert(self.resolved_callbacks, callback)
  if not self.resolving then
    self.resolving = true
    self.source:resolve(self.completion_item, function(completion_item)
      self.resolved_completion_item = completion_item
      for _, c in ipairs(self.resolved_callbacks) do
        c()
      end
    end)
  end
end

return entry

