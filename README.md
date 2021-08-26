# nvim-cmp

A completion plugin for neovim coded by Lua.


Status
====================

can be used. feedbacks are wanted.


Concept
====================

- Support pairs-wise plugin automatically
- Fully customizable via Lua functions
- Fully supported LSP's Completion capabilities
  - Snippets
  - CommitCharacters
  - TriggerCharacters
  - TextEdit and InsertReplaceTextEdit
  - AdditionalTextEdits
  - Markdown documentation
  - Execute commands (Some LSP server needs it to auto-importing. e.g. `sumneko_lua` or `purescript-language-server`)
  - Preselect
  - CompletionItemTags


Setup
====================

First, You should install nvim-cmp itself and completion sources by your favorite plugin manager.

The `nvim-cmp` sources can be found in [here](https://github.com/topics/nvim-cmp).

```viml
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-nvim-lua'
```

Then setup configuration.

```viml
" Setup global configuration. More on configuration below.
lua <<EOF
  local cmp = require('cmp')
  cmp.setup {
    snippet = {
      expand = function(args)
        -- You must install `vim-vsnip` if you use the following as-is.
        vim.fn['vsnip#anonymous'](args.body)
      end
    },

    -- You can set mapping if you want.
    mapping = {
      ['<C-p>'] = cmp.mapping.select_prev_item(),
      ['<C-n>'] = cmp.mapping.select_next_item(),
      ['<C-d>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.close(),
      ['<CR>'] = cmp.mapping.confirm({
        behavior = cmp.ConfirmBehavior.Insert,
        select = true,
      })
    },

    -- You should specify your *installed* sources.
    sources = {
      { name = 'buffer' },
    },
  }
EOF

" Setup buffer configuration (nvim-lua source only enables in Lua filetype).
autocmd FileType lua lua require'cmp'.setup.buffer {
\   sources = {
\     { name = 'buffer' },
\     { name = 'nvim_lua' },
\   },
\ }
```


Configuration
====================

The default configuration can be found in [here](./lua/cmp/config/default.lua)

You can use your own configuration like this:

```lua
local cmp = require'cmp'
cmp.setup {
  ...
  completion = {
    autocomplete = { ... },
  },
  sorting = {
    priority_weight = 2.,
    comparators = { ... },
  },
  mapping = {
    ...
  },
  sources = { ... },
  ...
}
```

#### mapping (type: table<string, fun(fallback: function)>)

Define mappings with `cmp.mapping` helper.

You can use the following functions as mapping configuration like this.

```lua
mapping = {
  ['<C-p>'] = cmp.mapping.select_prev_item(),
  ['<C-n>'] = cmp.mapping.select_next_item(),
  ['<C-d>'] = cmp.mapping.scroll_docs(-4),
  ['<C-f>'] = cmp.mapping.scroll_docs(4),
  ['<C-Space>'] = cmp.mapping.complete(),
  ['<C-e>'] = cmp.mapping.close(),
  ['<CR>'] = cmp.mapping.confirm({
    behavior = cmp.ConfirmBehavior.Replace,
    select = true,
  })
}
```

- *cmp.mapping.select_prev_item()*
- *cmp.mapping.select_next_item()*
- *cmp.mapping.scroll_docs(number)*
- *cmp.mapping.complete()*
- *cmp.mapping.close()*
- *cmp.mapping.abort()*
- *cmp.mapping.confirm({ select = bool, behavior = cmp.ConfirmBehavior.{Insert,Replace} })*

In addition, You can specify vim's mode to those mapping functions.

```lua
mapping = {
  ...
  ['<Tab>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 's' })
  ...
}
```

You can specify your custom mapping function.

```lua
mapping = {
  ['<Tab>'] = function(fallback)
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-n>', true, true, true), 'n')
    elseif vim.fn['vsnip#available']() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<Plug>(vsnip-expand-or-jump)', true, true, true), '')
    else
      fallback()
    end
  end,
}
```

#### completion.autocomplete (type: cmp.TriggerEvent[])

Which events should trigger `autocompletion`.

If you leave this empty or `nil`, `nvim-cmp` does not perform completion automatically.
You can still use manual completion though (like omni-completion).

Default: `{ types.cmp.TriggerEvent.TextChanged }`

#### completion.keyword_pattern (type: string)

The default keyword pattern.  This value will be used if a source does not set a source specific pattern.

Default: `[[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]]`

#### completion.keyword_length (type: number)

The minimal length of a word to complete; e.g., do not try to complete when the
length of the word to the left of the cursor is less than `keyword_length`.

Default: `1`


#### completion.completeopt (type: string)

vim's `completeopt` setting. Warning: Be careful when changing this value.

Default: `menu,menuone,noselect`

#### documentation (type: false | cmp.DocumentationConfig)

A documentation configuration or false to disable feature.

#### documentation.border (type: string[])

A border characters for documentation window.

#### documentation.winhighlight (type: string)

A neovim's `winhighlight` option for documentation window.

#### documentation.maxwidth (type: number)

A documentation window's max width.

#### documentation.maxheight (type: number)

A documentation window's max height.

#### confirmation.default_behavior (type: cmp.ConfirmBehavior)

A default `cmp.ConfirmBehavior` value when to use confirmed by commitCharacters

Default: `cmp.ConfirmBehavior.Insert`

#### formatting.deprecated (type: boolean)

Specify deprecated candidate should be marked as deprecated or not.

Default: `true`


#### formatting.format (type: fun(entry: cmp.Entry, vim_item: vim.CompletedItem): vim.CompletedItem)

A function to customize completion menu.

The return value is defined by vim. See `:help complete-items`.

You can display the fancy icons to completion-menu with [lspkind-nvim](https://github.com/onsails/lspkind-nvim).

Please see [FAQ](#how-to-show-name-of-item-kind-and-source-like-compe) if you would like to show symbol-text (e.g. function) and source (e.g. LSP) like compe.

```lua
local lspkind = require('lspkind')
cmp.setup {
  formatting = {
    format = function(entry, vim_item)
      vim_item.kind = lspkind.presets.default[vim_item.kind]
      return vim_item
    end
  }
}
```

#### event.on_confirm_done (type: fun(entry: cmp.Entry))

A callback function called when the item is confirmed.

#### sorting.priority_weight (type: number)

When sorting completion items before displaying them, boost each item's score
based on the originating source. Each source gets a base priority of `#sources -
(source_index - 1)`, and we then multiply this by `priority_weight`:

`score = score + ((#sources - (source_index - 1)) * sorting.priority_weight)`

Default: `2`

#### sorting.comparators (type: function[])

When sorting completion items, the sort logic tries each function in
`sorting.comparators` consecutively when comparing two items. The first function
to return something other than `nil` takes precedence.

Each function must return `boolean|nil`.

Default:
```lua
{
  compare.offset,
  compare.exact,
  compare.score,
  compare.kind,
  compare.sort_text,
  compare.length,
  compare.order,
}
```

#### preselect (type: cmp.PreselectMode)

Specify preselect mode. The following modes are available.

- cmp.Preselect.Item
  - If the item has `preselect = true`, nvim-cmp will preselect it.
- cmp.Preselect.None
  - Disable preselect feature.

Default: `cmp.PreselectMode.Item`


FAQ
====================

#### How to set up like nvim-compe's `preselect = 'always'`?

You can use the following configuration.

```lua
cmp.setup {
  completion = {
    completeopt = 'menu,menuone,noinsert',
  }
}
```

#### I dislike auto-completion

You can use `nvim-cmp` without auto-completion like this.

```lua
cmp.setup {
  completion = {
    autocomplete = false
  }
}
```

#### nvim-cmp is slow.

I've optimized nvim-cmp as much as possible, but there are currently some known / unfixable issues.

1. `cmp-buffer` source and too large buffer

The `cmp-buffer` source makes index of the current buffer so if the current buffer is too large, will be slowdown main UI thread.

1. some language servers

For example, `typescript-language-server` will returns 15k items to the client.
In such case, the time near the 100ms will be consumed just to parse payloads as JSON.

#### How to setup supertab-like mapping?

This is supertab-like mapping for [LuaSnip](https://github.com/L3MON4D3/LuaSnip)

```lua
local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end
local check_back_space = function()
  local col = vim.fn.col '.' - 1
  return col == 0 or vim.fn.getline('.'):sub(col, col):match '%s' ~= nil
end
local luasnip = require("luasnip")

-- supertab-like mapping
mapping = {
  ["<tab>"] = cmp.mapping(function(fallback)
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(t("<C-n>"), "n")
    elseif luasnip.expand_or_jumpable() then
      vim.fn.feedkeys(t("<Plug>luasnip-expand-or-jump"), "")
    elseif check_back_space() then
      vim.fn.feedkeys(t("<tab>"), "n")
    else
      fallback()
    end
  end, {
    "i",
    "s",
  }),
  ["<S-tab>"] = cmp.mapping(function(fallback)
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(t("<C-p>"), "n")
    elseif luasnip.jumpable(-1) then
      vim.fn.feedkeys(t("<Plug>luasnip-jump-prev"), "")
    else
      fallback()
    end
  end, {
    "i",
    "s",
  }),
}
```

#### How to show name of item kind and source (like compe)?

```lua
formatting = {
  format = function(entry, vim_item)
    -- fancy icons and a name of kind
    vim_item.kind = require("lspkind").presets.default[vim_item.kind]
      .. " "
      .. vim_item.kind
    -- set a name for each source
    vim_item.menu = ({
      buffer = "[Buffer]",
      nvim_lsp = "[LSP]",
      luasnip = "[LuaSnip]",
      nvim_lua = "[Lua]",
      latex_symbols = "[Latex]",
    })[entry.source.name]
    return vim_item
  end,
},
```

Source creation
====================

If you publish `nvim-cmp` source to GitHub, please add `nvim-cmp` topic for the repo.

You should read [cmp types](/lua/cmp/types) and [LSP spec](https://microsoft.github.io/language-server-protocol/specifications/specification-current/) to create sources.

- The `complete` function is required but others can be omitted.
- The `callback` argument must always be called.
- The custom source only can use `require('cmp')`.
- The custom source can specify `word` property to CompletionItem. (It isn't an LSP specification but supported as a special case.)

```lua
local source = {}

---Source constructor.
source.new = function()
  local self = setmetatable({}, { __index = source })
  self.your_awesome_variable = 1
  return self
end

---Return the source name for some information.
source.get_debug_name = function()
  return 'example'
end

---Return the source is available or not.
---@return boolean
function source:is_available()
  return true
end

---Return keyword pattern which will be used...
---  1. Trigger keyword completion
---  2. Detect menu start offset
---  3. Reset completion state
---@param params cmp.SourceBaseApiParams
---@return string
function source:get_keyword_pattern(params)
  return '???'
end

---Return trigger characters.
---@param params cmp.SourceBaseApiParams
---@return string[]
function source:get_trigger_characters(params)
  return { ??? }
end

---Invoke completion (required).
---  If you want to abort completion, just call the callback without arguments.
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(params, callback)
  callback({
    { label = 'January' },
    { label = 'February' },
    { label = 'March' },
    { label = 'April' },
    { label = 'May' },
    { label = 'June' },
    { label = 'July' },
    { label = 'August' },
    { label = 'September' },
    { label = 'October' },
    { label = 'November' },
    { label = 'December' },
  })
end

---Resolve completion item that will be called when the item selected or before the item confirmation.
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:resolve(completion_item, callback)
  callback(completion_item)
end

---Execute command that will be called when after the item confirmation.
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:execute(completion_item, callback)
  callback(completion_item)
end

return source
```
