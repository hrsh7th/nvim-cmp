local cmp = {}

---@alias cmp.ConfirmBehavior "'insert'" | "'replace'"
cmp.ConfirmBehavior = {}
cmp.ConfirmBehavior.Insert = 'insert'
cmp.ConfirmBehavior.Replace = 'replace'

---@alias cmp.ContextReason "'auto'" | "'manual'" | "'none'"
cmp.ContextReason = {}
cmp.ContextReason.Auto = 'auto'
cmp.ContextReason.Manual = 'manual'
cmp.ContextReason.TriggerOnly = 'triggerOnly'
cmp.ContextReason.None = 'none'

---@alias cmp.TriggerEvent "'InsertEnter'" | "'TextChanged'"
cmp.TriggerEvent = {}
cmp.TriggerEvent.InsertEnter = 'InsertEnter'
cmp.TriggerEvent.TextChanged = 'TextChanged'

---@alias cmp.ScrollDirection "'up'" | "'down'"
cmp.ScrollDirection = {}
cmp.ScrollDirection.Up = 'up'
cmp.ScrollDirection.Down = 'down'

---@class cmp.ContextOption
---@field public reason cmp.ContextReason|nil

---@class cmp.ConfirmOption
---@field public behavior cmp.ConfirmBehavior

---@class cmp.SnippetExpansionParams
---@field public body string
---@field public insert_text_mode number

---@class cmp.Setup
---@field public __call fun(c: cmp.ConfigSchema)
---@field public buffer fun(c: cmp.ConfigSchema)
---@field public global fun(c: cmp.ConfigSchema)

---@class cmp.CompletionRequest
---@field public context cmp.Context
---@field public option table
---@field public offset number
---@field public completion_context lsp.CompletionContext

---@class cmp.ConfigSchema
---@field private revision number
---@field public completion cmp.CompletionConfig
---@field public documentation cmp.DocumentationConfig
---@field public confirmation cmp.ConfirmationConfig
---@field public sorting cmp.SortingConfig
---@field public formatting cmp.FormattingConfig
---@field public snippet cmp.SnippetConfig
---@field public mapping table<string, cmp.MappingConfig>
---@field public sources cmp.SourceConfig[]

---@class cmp.CompletionConfig
---@field public autocomplete cmp.TriggerEvent[]
---@field public completeopt string
---@field public keyword_pattern string
---@field public keyword_length number

---@class cmp.DocumentationConfig
---@field public border string[]
---@field public winhighlight string
---@field public maxwidth number|nil
---@field public maxheight number|nil

---@class cmp.ConfirmationConfig
---@field public default_behavior cmp.ConfirmBehavior

---@class cmp.SortingConfig
---@field public priority_weight number
---@field public comparators function[]

---@class cmp.FormattingConfig
---@field public format fun(entry: cmp.Entry, suggeset_offset: number): vim.CompletedItem

---@class cmp.SnippetConfig
---@field public expand fun(args: cmp.SnippetExpansionParams)

---@class cmp.SourceConfig
---@field public name string
---@field public opts table

---@alias cmp.MappingConfig cmp.ConfirmMapping | cmp.CompleteMapping | cmp.CloseMapping | cmp.ItemNextMapping | cmp.ItemPrevMapping | cmp.ScrollUpMapping | cmp.ScrollDownMapping

---@class cmp.ConfirmMapping
---@field public type '"confirm"'
---@field public select boolean
---@field public behavior cmp.ConfirmBehavior

---@class cmp.CompleteMapping
---@field public type '"complete"'

---@class cmp.CloseMapping
---@field public type '"close"'

---@class cmp.ItemNextMapping
---@field public type '"item.next"'
---@field public delta number

---@class cmp.ItemPrevMapping
---@field public type '"item.prev"'
---@field public delta number

---@class cmp.ScrollUpMapping
---@field public type '"scroll.up"'
---@field public delta number

---@class cmp.ScrollDownMapping
---@field public type '"scroll.down"'
---@field public delta number

return cmp

