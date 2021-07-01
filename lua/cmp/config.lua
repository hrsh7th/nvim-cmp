local misc = require'cmp.utils.misc'

---@class cmp.Config
---@field public commit_characters fun(e:cmp.Entry)|string[]|nil
---@field public format fun(entry: cmp.Entry, word: string, abbr: string): vim.CompletedItem

local config = {}

---@type cmp.Config
config.global = {
  commit_characters = function(e)
    local chars = { '\n', '\t' }
    if not string.find(e:get_word_and_abbr().word, '.', 1, true) then
      table.insert(chars, '.')
    end
    if vim.tbl_contains({
      vim.lsp.protocol.CompletionItemKind.Snippet,
      vim.lsp.protocol.CompletionItemKind.Method,
      vim.lsp.protocol.CompletionItemKind.Function
    }, e:get_completion_item().kind) then
      table.insert(chars, '(')
    end
    return chars
  end,
  default_insert_mode = 'replace',
  format = function(entry, word, abbr)
    return {
      word = word,
      abbr = abbr,
      kind = vim.lsp.protocol.CompletionItemKind[misc.safe(entry.completion_item.kind) or 1]
        or vim.lsp.protocol.CompletionItemKind[1],
      equal = 1,
      empty = 1,
      dup = 1,
      user_data = {
        cmp = entry.id
      }
    }
  end
}

---@return cmp.Config
config.get = function()
  return config.global
end

return config

