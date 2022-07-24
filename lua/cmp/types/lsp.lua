local misc = require('cmp.utils.misc')

---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/
---@class lsp
local lsp = {}

lsp.Position = {
  ---Convert lsp.Position to vim.Position
  ---@param buf integer|string
  ---@param position lsp.Position
  ---@return vim.Position
  to_vim = function(buf, position)
    if not vim.api.nvim_buf_is_loaded(buf) then
      vim.fn.bufload(buf)
    end
    local lines = vim.api.nvim_buf_get_lines(buf, position.line, position.line + 1, false)
    if #lines > 0 then
      return {
        row = position.line + 1,
        col = misc.to_vimindex(lines[1], position.character),
      }
    end
    return {
      row = position.line + 1,
      col = position.character + 1,
    }
  end,
  ---Convert vim.Position to lsp.Position
  ---@param buf integer|string
  ---@param position vim.Position
  ---@return lsp.Position
  to_lsp = function(buf, position)
    if not vim.api.nvim_buf_is_loaded(buf) then
      vim.fn.bufload(buf)
    end
    local lines = vim.api.nvim_buf_get_lines(buf, position.row - 1, position.row, false)
    if #lines > 0 then
      return {
        line = position.row - 1,
        character = misc.to_utfindex(lines[1], position.col),
      }
    end
    return {
      line = position.row - 1,
      character = position.col - 1,
    }
  end,
}

lsp.Range = {
  ---Convert lsp.Range to vim.Range
  ---@param buf integer|string
  ---@param range lsp.Range
  ---@return vim.Range
  to_vim = function(buf, range)
    return {
      start = lsp.Position.to_vim(buf, range.start),
      ['end'] = lsp.Position.to_vim(buf, range['end']),
    }
  end,

  ---Convert vim.Range to lsp.Range
  ---@param buf integer|string
  ---@param range vim.Range
  ---@return lsp.Range
  to_lsp = function(buf, range)
    return {
      start = lsp.Position.to_lsp(buf, range.start),
      ['end'] = lsp.Position.to_lsp(buf, range['end']),
    }
  end,
}

---@alias lsp.CompletionTriggerKind 1 | 2 | 3
lsp.CompletionTriggerKind = {
  Invoked = 1,
  TriggerCharacter = 2,
  TriggerForIncompleteCompletions = 3,
}

---@alias lsp.InsertTextFormat 1 | 2
lsp.InsertTextFormat = {}
lsp.InsertTextFormat.PlainText = 1
lsp.InsertTextFormat.Snippet = 2

---@alias lsp.InsertTextMode 1 | 2
lsp.InsertTextMode = {
  AsIs = 1,
  AdjustIndentation = 2,
}

---@alias lsp.MarkupKind 'plaintext' | 'markdown'
lsp.MarkupKind = {
  PlainText = 'plaintext',
  Markdown = 'markdown',
}

---@alias lsp.CompletionItemTag 1
lsp.CompletionItemTag = {
  Deprecated = 1,
}

---@alias lsp.CompletionItemKind 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25
lsp.CompletionItemKind = {
  Text = 1,
  Method = 2,
  Function = 3,
  Constructor = 4,
  Field = 5,
  Variable = 6,
  Class = 7,
  Interface = 8,
  Module = 9,
  Property = 10,
  Unit = 11,
  Value = 12,
  Enum = 13,
  Keyword = 14,
  Snippet = 15,
  Color = 16,
  File = 17,
  Reference = 18,
  Folder = 19,
  EnumMember = 20,
  Constant = 21,
  Struct = 22,
  Event = 23,
  Operator = 24,
  TypeParameter = 25,
}
lsp.CompletionItemKind = vim.tbl_add_reverse_lookup(lsp.CompletionItemKind)

---@class lsp.CompletionContext
---@field public triggerKind lsp.CompletionTriggerKind
---@field public triggerCharacter string|nil

---@class lsp.CompletionList
---@field public isIncomplete boolean
---@field public items lsp.CompletionItem[]

---@alias lsp.CompletionResponse lsp.CompletionList|lsp.CompletionItem[]|nil

---@class lsp.MarkupContent
---@field public kind lsp.MarkupKind
---@field public value string

---@class lsp.Position
---@field public line integer
---@field public character integer

---@class lsp.Range
---@field public start lsp.Position
---@field public end lsp.Position

---@class lsp.Command
---@field public title string
---@field public command string
---@field public arguments any[]|nil

---@class lsp.TextEdit
---@field public range lsp.Range|nil
---@field public newText string

---@alias lsp.InsertReplaceTextEdit lsp.internal.InsertTextEdit|lsp.internal.ReplaceTextEdit

---@class lsp.internal.InsertTextEdit
---@field public insert lsp.Range
---@field public newText string

---@class lsp.internal.ReplaceTextEdit
---@field public insert lsp.Range
---@field public newText string

---@class lsp.CompletionItemLabelDetails
---@field public detail string|nil
---@field public description string|nil

---@class lsp.Cmp
---@field public kind_text string
---@field public kind_hl_group string

---@class lsp.CompletionItem
---@field public label string
---@field public labelDetails lsp.CompletionItemLabelDetails|nil
---@field public kind lsp.CompletionItemKind|nil
---@field public tags lsp.CompletionItemTag[]|nil
---@field public detail string|nil
---@field public documentation lsp.MarkupContent|string|nil
---@field public deprecated boolean|nil
---@field public preselect boolean|nil
---@field public sortText string|nil
---@field public filterText string|nil
---@field public insertText string|nil
---@field public insertTextFormat lsp.InsertTextFormat
---@field public insertTextMode lsp.InsertTextMode
---@field public textEdit lsp.TextEdit|lsp.InsertReplaceTextEdit|nil
---@field public additionalTextEdits lsp.TextEdit[]
---@field public commitCharacters string[]|nil
---@field public command lsp.Command|nil
---@field public data any|nil
---@field public cmp lsp.Cmp|nil
---
---TODO: Should send the issue for upstream?
---@field public word string|nil
---@field public dup boolean|nil

return lsp
