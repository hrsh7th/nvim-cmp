local cache = require('cmp.utils.cache')
local char = require('cmp.utils.char')
local misc = require('cmp.utils.misc')
local str = require('cmp.utils.str')
local config = require('cmp.config')
local lsp = require('cmp.types.lsp')

---@class cmp.Entry
---@field public id number
---@field public cache cmp.Cache
---@field public score number
---@field public context cmp.Context
---@field public source cmp.Source
---@field public completion_item lsp.CompletionItem
---@field public resolved_completion_item lsp.CompletionItem|nil
---@field public resolved_callbacks fun()[]
---@field public resolving boolean
---@field public confirmed boolean
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
  return self
end

---Make offset value
---@return number
entry.get_offset = function(self)
  return self.cache:ensure('get_offset', function()
    local offset = self.context.offset
    if misc.safe(self.completion_item.textEdit) then
      local range = misc.safe(self.completion_item.textEdit.insert) or misc.safe(self.completion_item.textEdit.range)
      if range then
        local c = vim.str_byteindex(self.context.cursor_line, range.start.character) + 1
        for idx = c, self.context.offset do
          if not char.is_white(string.byte(self.context.cursor_line, idx)) then
            offset = math.min(offset, idx)
            break
          end
        end
      end
    else
      -- NOTE
      -- The VSCode does not implement this but it's useful if the server does not care about word patterns.
      -- We should care about this performance.
      local word = self:get_word()
      for idx = #self.context.offset_before_line, #self.context.offset_before_line - #word, -1 do
        if char.is_semantic_index(self.context.offset_before_line, idx) then
          local c = string.byte(self.context.offset_before_line, idx)
          if char.is_white(c) then
            break
          end
          local match = true
          for i = 1, #self.context.offset_before_line - idx + 1 do
            local c1 = string.byte(word, i)
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

---Create word for vim.CompletedItem
---@return string
entry.get_word = function(self)
  return self.cache:ensure('get_word', function()
    local word
    if misc.safe(self.completion_item.textEdit) then
      word = str.trim(self.completion_item.textEdit.newText)
      word = str.get_word(word, string.byte(self.context.cursor_after_line, 1))
    elseif misc.safe(self.completion_item.insertText) then
      word = str.trim(self.completion_item.insertText)
      if self.completion_item.insertTextFormat == lsp.InsertTextFormat.Snippet then
        word = str.get_word(word)
      end
    else
      word = str.trim(self.completion_item.label)
    end
    return word
  end)
end

---Get word start position in filter_text
entry.get_word_start_offset = function(self)
  return self.cache:ensure('get_word_start_offset', function()
    return string.find(self:get_filter_text(), self:get_word(), 1, true) or 1
  end)
end

---Create filter text
---@return string
entry.get_filter_text = function(self)
  return self.cache:ensure({ 'get_filter_text' }, function()
    local word
    if misc.safe(self.completion_item.filterText) then
      word = self.completion_item.filterText
    else
      word = str.trim(self.completion_item.label)
    end

    -- @see https://github.com/clangd/clangd/issues/815
    if misc.safe(self.completion_item.textEdit) then
      local diff = self.context.offset - self:get_offset()
      if diff > 0 then
        if char.is_symbol(string.byte(self.context.cursor_line, self:get_offset())) then
          local prefix = string.sub(self.context.cursor_line, self:get_offset(), self:get_offset() + diff)
          if string.find(word, prefix, 1, true) ~= 1 then
            word = prefix .. word
          end
        end
      end
    end

    return word
  end)
end

---Get LSP's insert text
---@return string
entry.get_insert_text = function(self)
  return self.cache:ensure('get_insert_text', function()
    if misc.safe(self.completion_item.textEdit) then
      return str.trim(self.completion_item.textEdit.newText)
    elseif misc.safe(self.completion_item.insertText) then
      return str.trim(self.completion_item.insertText)
    end
    return str.trim(self.completion_item.label)
  end)
end

---Make vim.CompletedItem
---@param offset number
---@return vim.CompletedItem
entry.get_vim_item = function(self, offset)
  return self.cache:ensure({ 'get_vim_item', offset }, function()
    local item = self:get_completion_item()
    local word = self:get_word()
    local abbr = str.trim(self.completion_item.label)

    if offset ~= self:get_offset() then
      word = string.sub(self.context.cursor_before_line, offset, self:get_offset() - 1) .. word
    end

    if item.insertTextFormat == lsp.InsertTextFormat.Snippet then
      local insert_text = self:get_insert_text()
      if not (word == insert_text or (word .. '$0') == insert_text or (word .. '${0}') == insert_text) then
        abbr = abbr .. '~'
      end
    end

    local menu = nil
    if misc.safe(item.labelDetails) then
      menu = ''
      if misc.safe(item.labelDetails.parameters) then
        menu = menu .. item.labelDetails.parameters
      end
      if misc.safe(item.labelDetails.type) then
        menu = menu .. item.labelDetails.type
      end
      if misc.safe(item.labelDetails.qualifier) then
        menu = menu .. item.labelDetails.qualifier
      end
    end

    return config.get().format(self, word, abbr, menu)
  end)
end

---Get commit characters
---@return string[]
entry.get_commit_characters = function(self)
  local commit_characters = {}
  local completion_item = self:get_completion_item()
  misc.concat(commit_characters, misc.safe(completion_item.commitCharacters) or {})
  misc.concat(commit_characters, config.get().commit_characters(self))
  return commit_characters
end

---Return insert range
---@return vim.Range|nil
entry.get_insert_range = function(self)
  local insert_range
  if misc.safe(self.completion_item.textEdit) then
    if misc.safe(self.completion_item.textEdit.insert) then
      insert_range = lsp.Range.to_vim(self.context.bufnr, self.completion_item.textEdit.insert)
    else
      insert_range = lsp.Range.to_vim(self.context.bufnr, self.completion_item.textEdit.range)
    end
  else
    insert_range = {
      start = {
        row = self.context.insert_range.start.row,
        col = math.min(self.context.insert_range.start.col, self:get_offset()),
      },
      ['end'] = self.context.insert_range['end'],
    }
  end
  return insert_range
end

---Return replace range
---@return vim.Range|nil
entry.get_replace_range = function(self)
  return self.cache:ensure('get_replace_range', function()
    local replace_range
    if misc.safe(self.completion_item.textEdit) then
      if misc.safe(self.completion_item.textEdit.replace) then
        replace_range = lsp.Range.to_vim(self.context.bufnr, self.completion_item.textEdit.replace)
      else
        replace_range = lsp.Range.to_vim(self.context.bufnr, self.completion_item.textEdit.range)
      end
    else
      replace_range = {
        start = {
          row = self.context.replace_range.start.row,
          col = math.min(self.context.replace_range.start.col, self:get_offset()),
        },
        ['end'] = self.context.replace_range['end'],
      }
    end
    return replace_range
  end)
end

---Get resolved completion item if possible.
---@return lsp.CompletionItem
entry.get_completion_item = function(self)
  if self.resolved_completion_item then
    return self.resolved_completion_item
  end
  return self.completion_item
end

---Create documentation
---@return lsp.MarkupContent
entry.get_documentation = function(self)
  local item = self:get_completion_item()
  if not item.documentation then
    return nil
  end
  if type(item.documentation) == 'string' then
    return {
      kind = 'plaintext',
      value = item.documentation,
    }
  end
  return item.documentation
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
      self.resolved_completion_item = misc.safe(completion_item) or self.completion_item
      for _, c in ipairs(self.resolved_callbacks) do
        c()
      end
    end)
  end
end

return entry
