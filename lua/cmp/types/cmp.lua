local cmp = {}

---@alias cmp.ConfirmBehavior "'insert'" | "'replace'"
cmp.ConfirmBehavior = {}
cmp.ConfirmBehavior.Insert = 'insert'
cmp.ConfirmBehavior.Replace = 'replace'

---@alias cmp.PreselectMode "'item'" | "'always'" | "'none'"
cmp.PreselectMode = {}
cmp.PreselectMode.Item = 'item'
cmp.PreselectMode.Always = 'always'
cmp.PreselectMode.None = 'none'

---@alias cmp.ContextReason "'auto'" | "'manual'" | "'none'"
cmp.ContextReason = {}
cmp.ContextReason.Auto = 'auto'
cmp.ContextReason.Manual = 'manual'
cmp.ContextReason.None = 'none'

---@class cmp.ContextOption
---@field public reason cmp.ContextReason|nil

---@class cmp.ConfirmOption
---@field public behavior cmp.ConfirmBehavior

---@class cmp.SnippetExpansionParams
---@field public body string

---@class cmp.Setup
---@field public __call fun(c: cmp.ConfigSchema)
---@field public buffer fun(c: cmp.ConfigSchema)
---@field public global fun(c: cmp.ConfigSchema)

---@class cmp.CompletionRequest
---@field public context cmp.Context
---@field public option table
---@field public completion_context lsp.CompletionContext

---@class cmp.ConfigSchema
---@field private revision number
---@field public autocomplete boolean
---@field public keyword_pattern string
---@field public snippet cmp.SnippetConfig
---@field public preselect cmp.PreselectConfig
---@field public commit_characters cmp.CommitCharactersConfig
---@field public documentation cmp.DocumentationConfig
---@field public menu cmp.MenuConfig
---@field public confirm cmp.ConfirmConfig
---@field public sources cmp.SourceConfig[]

---@class cmp.SnippetConfig
---@field public expand fun(args: cmp.SnippetExpansionParams)

---@class cmp.PreselectConfig
---@field public mode cmp.PreselectMode

---@class cmp.CommitCharactersConfig
---@field public resolve fun(e: cmp.Entry): string[]

---@class cmp.DocumentationConfig
---@field public border string[]
---@field public winhighlight string
---@field public maxwidth number|nil
---@field public maxheight number|nil

---@class cmp.MenuConfig
---@field public sort fun(entries: cmp.Entry[]): cmp.Entry[]
---@field public format fun(entry: cmp.Entry, suggeset_offset: number): vim.CompletedItem

---@class cmp.ConfirmConfig
---@field public default_behavior cmp.ConfirmBehavior

---@class cmp.SourceConfig
---@field public name string
---@field public unique boolean
---@field public sortable boolean
---@field public opts table

return cmp

