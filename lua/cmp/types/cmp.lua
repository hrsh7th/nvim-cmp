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

---@alias cmp.ItemField "'abbr'" | "'kind'" | "'menu'"
cmp.ItemField = {}
cmp.ItemField.Abbr = 'abbr'
cmp.ItemField.Kind = 'kind'
cmp.ItemField.Menu = 'menu'

---
--- core
---

---@class cmp.WindowOption
---@field public max_width number
---@field public max_height number
---@field public zindex number
---@field public border string|string[]
---@field public highlight string

---@class cmp.ContextOption
---@field public reason cmp.ContextReason|nil

---@class cmp.ConfirmOption
---@field public behavior cmp.ConfirmBehavior
---@field public commit_character? string

---@class cmp.SelectOption
---@field public behavior cmp.SelectBehavior

---@class cmp.CompleteOption
---@field public reason? cmp.ContextReason
---@field public config? cmp.ConfigSchema

---@class cmp.Mapping
---@field public i nil|function(fallback: function): void
---@field public c nil|function(fallback: function): void
---@field public x nil|function(fallback: function): void
---@field public s nil|function(fallback: function): void

---
--- Custom
---

---@class cmp.CompletionView
---@field public on_open function(offset: number, entries: cmp.Entry[]): void
---@field public on_close fun()
---@field public on_abort fun()
---@field public select fun(index: number, behavior: cmp.SelectBehavior)

---
--- Source API
---

---@class cmp.SourceApiParams: cmp.SourceConfig

---@class cmp.SourceCompletionApiParams : cmp.SourceConfig
---@field public offset number
---@field public context cmp.Context
---@field public completion_context lsp.CompletionContext

---@class cmp.Setup
---@field public __call fun(c: cmp.ConfigSchema)
---@field public buffer fun(c: cmp.ConfigSchema)
---@field public global fun(c: cmp.ConfigSchema)
---@field public cmdline fun(type: string, c: cmp.ConfigSchema)

---
--- Configuration Schema
---

---@class cmp.ConfigSchema
---@field private revision number
---@field public enabled boolean|fun():boolean
---@field public preselect cmp.PreselectMode
---@field public mapping table<string, cmp.Mapping>
---@field public snippet cmp.SnippetConfig
---@field public completion cmp.CompletionConfig
---@field public formatting cmp.FormattingConfig
---@field public matching cmp.MatchingConfig
---@field public sorting cmp.SortingConfig
---@field public confirmation cmp.ConfirmationConfig
---@field public sources cmp.SourceConfig[]
---@field public view cmp.ViewConfig
---@field public experimental cmp.ExperimentalConfig

---@class cmp.CompletionConfig
---@field public autocomplete cmp.TriggerEvent[]
---@field public completeopt string
---@field public get_trigger_characters fun(trigger_characters: string[]): string[]
---@field public keyword_length number
---@field public keyword_pattern string

---@class cmp.ConfirmationConfig
---@field public default_behavior cmp.ConfirmBehavior
---@field public get_commit_characters fun(commit_characters: string[]): string[]

---@class cmp.MatchingConfig
---@field public disallow_fuzzy_matching boolean
---@field public disallow_partial_matching boolean
---@field public disallow_prefix_unmatching boolean

---@class cmp.SortingConfig
---@field public priority_weight number
---@field public comparators function[]

---@class cmp.FormattingConfig
---@field public fields cmp.ItemField[]
---@field public format fun(entry: cmp.Entry, vim_item: vim.CompletedItem): vim.CompletedItem

---@class cmp.SnippetConfig
---@field public expand fun(args: { body: string, insert_text_mode: lsp.InsertTextMode })

---@class cmp.ExperimentalConfig
---@field public ghost_text { hl_group: string }|"false"

---@class cmp.SourceConfig
---@field public name string
---@field public option table|nil
---@field public priority number|nil
---@field public trigger_characters string[]|nil
---@field public keyword_pattern string|nil
---@field public keyword_length number|nil
---@field public max_item_count number|nil
---@field public group_index number|nil

---@class cmp.ViewConfig
---@field public completion cmp.CompletionViewConfig
---@field public documentation cmp.DocumentationViewConfig

---@class cmp.CompletionViewConfig
---@field name string
---@field option table|nil

---@class cmp.DocumentationViewConfig
---@field name string
---@field option table|nil

return cmp

