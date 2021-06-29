local misc = require'cmp.utils.misc'

---@class cmp.Config
---@field public commit_characters string[]|nil
---@field public format fun(entry: cmp.Entry, word: string, abbr: string): vim.CompletedItem

local config = {}

---@type cmp.Config
config.global = {
  commit_characters = { '\n', '\t' },
  format = function(entry, word, abbr)
    return {
      word = word,
      abbr = abbr,
      kind = vim.lsp.protocol.CompletionItemKind[misc.safe(entry.completion_item.kind) or 1] or vim.lsp.protocol.CompletionItemKind[1],
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

