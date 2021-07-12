local cmp = {}

---@alias cmp.ConfirmBehavior "'insert'" | "'replace'"
cmp.ConfirmBehavior = {}
cmp.ConfirmBehavior.Insert = 'insert'
cmp.ConfirmBehavior.Replace = 'replace'

---@class cmp.MatcherConfig
---@field max_word_bound number
---@field prefix_start_offset number

---@class cmp.ConfirmOption
---@field public behavior cmp.ConfirmBehavior

---@class cmp.SnippetExpansionParams
---@field public body string

---@class cmp.DocumentationConfig
---@field border string[]
---@field winhighlight string
---@field maxwidth number|nil
---@field maxheight number|nil

---@class cmp.SnippetConfig
---@field expand fun(args: cmp.SnippetExpansionParams)

---@class cmp.ConfigSchema
---@field private revision number
---@field public default_confirm_behavior cmp.ConfirmBehavior
---@field public commit_characters fun(e:cmp.Entry):string[]
---@field public format fun(entry: cmp.Entry, word: string, abbr: string, menu: string): vim.CompletedItem
---@field public compare fun(entry1: cmp.Entry, entry2: cmp.Entry): number
---@field public documentation cmp.DocumentationConfig
---@field public snippet cmp.SnippetConfig

return cmp

