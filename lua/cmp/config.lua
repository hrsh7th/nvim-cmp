local misc = require'cmp.utils.misc'
local cache = require "cmp.utils.cache"
local lsp = require "cmp.types.lsp"

---@class cmp.ConfigSchema
---@field private revision number
---@field public default_insert_mode "'replace'" | "'insert'"
---@field public commit_characters fun(e:cmp.Entry):string[]
---@field public format fun(entry: cmp.Entry, word: string, abbr: string): vim.CompletedItem
---@field public sort fun(entry1: cmp.Entry, entry2: cmp.Entry): number

local default = {
  revision = 1,

  default_insert_mode = 'replace',

  ---@param e cmp.Entry
  ---@return string[]
  commit_characters = function(e)
    local chars = { '\n' }
    if not string.find(e:get_word(), '.', 1, true) then
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

  ---@see https://github.com/microsoft/vscode/blob/main/src/vs/editor/contrib/suggest/suggest.ts#L302
  ---@param entry1 cmp.Entry
  ---@param entry2 cmp.Entry
  ---@return number
  sort = function(entry1, entry2)
    -- score
    if entry1.score ~= entry2.score then
      return entry2.score - entry1.score
    end

    -- kind (NOTE: cmp's specific implementation to lower the `Text` kind)
    local kind1 = entry1.completion_item.kind or 1
    if kind1 == lsp.CompletionItemKind.Text then
      kind1 = 100
    end
    local kind2 = entry2.completion_item.kind or 1
    if kind2 == lsp.CompletionItemKind.Text then
      kind2 = 100
    end
    if kind1 ~= kind2 then
      return kind1 - kind2
    end

    -- sortText
    if misc.safe(entry1.completion_item.sortText) and misc.safe(entry2.completion_item.sortText) then
      local diff = vim.stricmp(entry1.completion_item.sortText, entry2.completion_item.sortText)
      if diff ~= 0 then
        return diff
      end
    end

    -- label
    local diff = vim.stricmp(entry1.completion_item.label, entry2.completion_item.label)
    if diff ~= 0 then
      return diff
    end

    return 0
  end,

  ---@param entry cmp.Entry
  ---@param word string
  ---@param abbr string
  ---@return vim.CompletedItem
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

---@class cmp.Config
---@field public g cmp.ConfigSchema
local config = {}

---@type cmp.utils.Cache
config.cache = cache.new()

---@type table<number, cmp.ConfigSchema>
config.bufs = { [0] = default }

---Set configuration for global or specified buffer
---@param c cmp.ConfigSchema
---@param bufnr number|nil
config.set = function(c, bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr or 0
  config.bufs[bufnr] = c
  config.bufs[bufnr].revision = config.bufs[bufnr].revision + 1
end

---@return cmp.ConfigSchema
config.get = function()
  local buf = config.bufs[vim.api.nvim_get_current_buf()] or default
  return config.cache:ensure({ buf.revision }, function()
    if buf == default then
      return default
    end
    return default
  end)
end

return config

