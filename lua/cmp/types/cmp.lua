local cmp = {}

---@alias cmp.ConfirmBehavior "'insert'" | "'replace'"
cmp.ConfirmBehavior = {}
cmp.ConfirmBehavior.Insert = 'insert'
cmp.ConfirmBehavior.Replace = 'replace'

---@alias cmp.SelectBehavior "'insert'" | "'select'"
cmp.SelectBehavior = {}
cmp.SelectBehavior.Insert = 'insert'
cmp.SelectBehavior.Select = 'select'

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

---@alias cmp.PreselectMode "'item'" | "'None'"
cmp.PreselectMode = {}
cmp.PreselectMode.Item = 'item'
cmp.PreselectMode.None = 'none'

---@class cmp.ContextOption
---@field public reason cmp.ContextReason|nil

---@class cmp.ConfirmOption
---@field public behavior cmp.ConfirmBehavior

---@class cmp.SelectOption
---@field public behavior cmp.SelectBehavior

---@class cmp.SnippetExpansionParams
---@field public body string
---@field public insert_text_mode number

---@class cmp.Setup
---@field public __call fun(c: cmp.ConfigSchema)
---@field public buffer fun(c: cmp.ConfigSchema)
---@field public global fun(c: cmp.ConfigSchema)

---@class cmp.SourceBaseApiParams
---@field public option table

---@class cmp.SourceCompletionApiParams : cmp.SourceBaseApiParams
---@field public context cmp.Context
---@field public offset number
---@field public completion_context lsp.CompletionContext

---@class cmp.ConfigSchema
---@field private revision number
---@field public enabled fun():boolean|boolean
---@field public preselect cmp.PreselectMode
---@field public completion cmp.CompletionConfig
---@field public documentation cmp.DocumentationConfig|"false"
---@field public confirmation cmp.ConfirmationConfig
---@field public sorting cmp.SortingConfig
---@field public formatting cmp.FormattingConfig
---@field public snippet cmp.SnippetConfig
---@field public event cmp.EventConfig
---@field public mapping table<string, fun(core: cmp.Core, fallback: function)>
---@field public sources cmp.SourceConfig[]
---@field public experimental cmp.ExperimentalConfig

---@class cmp.CompletionConfig
---@field public autocomplete cmp.TriggerEvent[]
---@field public completeopt string
---@field public keyword_pattern string
---@field public keyword_length number
---@field public get_trigger_characters fun(trigger_characters: string[]): string[]

---@class cmp.DocumentationConfig
---@field public border string[]
---@field public winhighlight string
---@field public maxwidth number|nil
---@field public maxheight number|nil
---@field public zindex number|nil

---@class cmp.ConfirmationConfig
---@field public default_behavior cmp.ConfirmBehavior
---@field public get_commit_characters fun(commit_characters: string[]): string[]

---@class cmp.SortingConfig
---@field public priority_weight number
---@field public comparators function[]

---@class cmp.FormattingConfig
---@field public format fun(entry: cmp.Entry, vim_item: vim.CompletedItem): vim.CompletedItem

---@class cmp.SnippetConfig
---@field public expand fun(args: cmp.SnippetExpansionParams)

---@class cmp.EventConfig
---@field on_confirm_done function(e: cmp.Entry)

---@class cmp.ExperimentalConfig
---@field public native_menu boolean
---@field public ghost_text cmp.GhostTextConfig|"false"

---@class cmp.GhostTextConfig
---@field hl_group string

---@class cmp.SourceConfig
---@field public name string
---@field public opts table
---@field public priority number|nil
---@field public keyword_pattern string
---@field public keyword_length number
---@field public max_item_count number

return cmp
