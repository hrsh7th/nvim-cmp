local cmp = {}

---@alias cmp.ConfirmBehavior "'insert'" | "'replace'"
cmp.ConfirmBehavior = {}
cmp.ConfirmBehavior.Insert = 'insert'
cmp.ConfirmBehavior.Replace = 'replace'

---@class cmp.Setup
---@field public __call fun(c: cmp.ConfigSchema)
---@field public buffer fun(c: cmp.ConfigSchema)
---@field public global fun(c: cmp.ConfigSchema)

---@class cmp.ConfirmOption
---@field public behavior cmp.ConfirmBehavior

---@class cmp.SnippetExpansionParams
---@field public body string

---@class cmp.DocumentationConfig
---@field public border string[]
---@field public winhighlight string
---@field public maxwidth number|nil
---@field public maxheight number|nil

---@class cmp.SnippetConfig
---@field public expand fun(args: cmp.SnippetExpansionParams)

---@class cmp.SourceConfig
---@field public name string
---@field public opts any

---@class cmp.ConfigSchema
---@field private revision number
---@field public default_confirm_behavior cmp.ConfirmBehavior
---@field public commit_characters fun(e:cmp.Entry):string[]
---@field public format fun(entry: cmp.Entry, word: string, abbr: string, menu: string): vim.CompletedItem
---@field public compare fun(entry1: cmp.Entry, entry2: cmp.Entry): number
---@field public documentation cmp.DocumentationConfig
---@field public snippet cmp.SnippetConfig
---@field public sources cmp.SourceConfig[]

return cmp

