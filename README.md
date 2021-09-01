# nvim-cmp

A completion engine plugin for neovim written in Lua.
Completion sources are installed from external repositories and "sourced".


Status
====================

Can be used. Feedback wanted!


Concept
====================

- Provides a completion engine to handle completion sources
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

## Install

First, You should install `nvim-cmp` itself and completion sources and snippet engine by your favourite plugin manager.

The `nvim-cmp` sources can be found in [here](https://github.com/topics/nvim-cmp).

Using [vim-plug](https://github.com/junegunn/vim-plug):

```viml
" Install nvim-cmp
Plug 'hrsh7th/nvim-cmp'

" Install snippet engine (This example installs [hrsh7th/vim-vsnip](https://github.com/hrsh7th/vim-vsnip))
Plug 'hrsh7th/vim-vsnip'

" Install the buffer completion source
Plug 'hrsh7th/cmp-buffer'
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
-- Install nvim-cmp, and buffer source as a dependency
use {
  "hrsh7th/nvim-cmp",
  requires = {
    "hrsh7th/vim-vsnip",
    "hrsh7th/cmp-buffer",
  }
}
```

## Basic Configuration

First, You should do the following steps.

- You must set `snippet engine` up. See README.md of your choosen snippet engine.
- Remove `longest` from `completeopt`. See `:help completeopt`.

To use `nvim-cmp` with the default configuration:

```viml
lua <<EOF
  local cmp = require'cmp'
  cmp.setup({
    snippet = {
      expand = function(args)
        vim.fn["vsnip#anonymous"](args.body)
      end,
    },
    mapping = {
      ['<C-y>'] = cmp.mapping.confirm({ select = true }),
    },
    sources = {
      { name = '...' },
      ...
    }
  })
EOF
```

The default configuration can be found in [here](./lua/cmp/config/default.lua)

Advanced Configuration
====================

```viml
lua <<EOF
  local cmp = require'cmp'
  cmp.setup {
    ...
    completion = {
      autocomplete = { ... },
    },
    ...
    snippet = {
      ...
    },
    ...
    preselect = ...,
    ...
    documentation = {
      ...
    },
    ...

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
EOF
```

The configuration options will be merged with the default config.
If you want to remove the option, You can set the `false` instead.

#### mapping (type: table<string, fun(fallback: function)>)

Built in helper `cmd.mappings` are:

- *cmp.mapping.select_prev_item()*
- *cmp.mapping.select_next_item()*
- *cmp.mapping.scroll_docs(number)*
- *cmp.mapping.complete()*
- *cmp.mapping.close()*
- *cmp.mapping.abort()*
- *cmp.mapping.confirm({ select = bool, behavior = cmp.ConfirmBehavior.{Insert,Replace} })*

You can configure `nvim-cmp` to use these `cmd.mappings` like this:

```lua
mapping = {
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

In addition, the mapping mode can be specified. The default is insert mode (i).

```lua
mapping = {
  ...
  ['<Tab>'] = cmp.mapping(cmp.mapping.select_next_item(), { 'i', 's' })
  ...
}
```

You can specify your own custom mapping function.

```lua
local check_back_space = function()
  local col = vim.fn.col('.') - 1
  return col == 0 or vim.fn.getline('.'):sub(col, col):match('%s')
end

mapping = {
  ['<Tab>'] = function(fallback)
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-n>', true, true, true), 'n')
    elseif check_back_space() then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, true, true), 'n')
    elseif vim.fn['vsnip#available']() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<Plug>(vsnip-expand-or-jump)', true, true, true), '')
    else
      fallback()
    end
  end,
}
```

#### sources (type: table<string>)

Globals source lists are listed in the `source` table. These are applied to all
buffers. The order of the sources list helps define the source priority, see
the *sorting.priority_weight* options below.

It is possible to setup different source lists for different filetypes, this is
an example using the `FileType` autocommand to setup different sources for the
lua filetype.

```viml
" Setup buffer configuration (nvim-lua source only enables in Lua filetype).
autocmd FileType lua lua require'cmp'.setup.buffer {
\   sources = {
\     { name = 'nvim_lua' },
\     { name = 'buffer' },
\   },
\ }
```

Note that the source name isn't necessarily the source repository name.
Source names are defined in the source repository README files. For
example look at the [hrsh7th/cmp-buffer](https://github.com/hrsh7th/cmp-buffer)
source README which defines the source name as `buffer`.

#### completion.autocomplete (type: cmp.TriggerEvent[])

Which events should trigger `autocompletion`.

If you set this to `false`, `nvim-cmp` will not perform completion
automatically. You can still use manual completion though (like omni-completion
via the `cmp.mapping.complete` function).

Default: `{ types.cmp.TriggerEvent.TextChanged }`

#### completion.keyword_pattern (type: string)

The default keyword pattern.  This value will be used if a source does not set
a source specific pattern.

Default: `[[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]]`

#### completion.keyword_length (type: number)

The minimum length of a word to complete on; e.g., do not try to complete when the
length of the word to the left of the cursor is less than `keyword_length`.

Default: `1`

#### completion.get_trigger_characters (type: fun(trigger_characters: string[]): string[])

The function to resolve trigger_characters.

Default: `function(trigger_characters) return trigger_characters end`

#### completion.completeopt (type: string)

vim's `completeopt` setting. Warning: Be careful when changing this value.

Default: `menu,menuone,noselect`

#### documentation (type: false | cmp.DocumentationConfig)

A documentation configuration or false to disable feature.

#### documentation.border (type: string[])

Border characters used for documentation window.

#### documentation.winhighlight (type: string)

A neovim's `winhighlight` option for documentation window.

#### documentation.maxwidth (type: number)

The documentation window's max width.

#### documentation.maxheight (type: number)

The documentation window's max height.

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
  - If the item has `preselect = true`, `nvim-cmp` will preselect it.
- cmp.Preselect.None
  - Disable preselect feature.

Default: `cmp.PreselectMode.Item`


Programatic API
====================

You can use the following APIs.

#### `cmp.confirm({ select = boolean, behavior = cmp.ConfirmBehavior.{Insert,Replace} })`

Confirm current selected item if possible.

#### `cmp.complete()`

Invoke manual completion.

#### `cmp.close()`

Close current completion menu.

#### `cmp.abort()`

Close current completion menu and restore current line (similar to native `<C-e>` behavior).

#### `cmp.select_next_item()`

Select next completion item if possible.

#### `cmp.select_prev_item()`

Select prev completion item if possible.

#### `cmp.scroll_docs(delta)`

Scroll documentation window if possible.


FAQ
====================

#### What is the `pairs-wise plugin automatically supported`?

Some pairs-wise plugin set up the mapping automatically.
For example, `vim-endwise` will map `<CR>` even if you don't do any mapping instructions for the plugin.

But I think the user want to override `<CR>` mapping only when the mapping item is selected.

The `nvim-cmp` does it automatically.

The following configuration will be working as

1. If the completion-item is selected, will be working as `cmp.mapping.confirm`.
2. If the completion-item isn't selected, will be working as vim-endwise feature.

```lua
mapping = {
  ['<CR>'] = cmp.mapping.confirm()
}
```

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

I've optimized `nvim-cmp` as much as possible, but there are currently some known / unfixable issues.

1. `cmp-buffer` source and too large buffer
The `cmp-buffer` source makes index of the current buffer so if the current buffer is too large, will be slowdown main UI thread.

1. some language servers
For example, `typescript-language-server` will returns 15k items to the client.
In such case, the time near the 100ms will be consumed just to parse payloads as JSON.

1. You set `vim.lsp.set_log_level` up by yourself.
This setting will cause the filesystem operation for each LSP payloads.
This will extremely slow down nvim-cmp (and other LSP related features).

#### How to setup supertab-like mapping?

This is supertab-like mapping for [LuaSnip](https://github.com/L3MON4D3/LuaSnip)

```lua
local check_back_space = function()
  local col = vim.fn.col '.' - 1
  return col == 0 or vim.fn.getline('.'):sub(col, col):match '%s' ~= nil
end
local luasnip = require("luasnip")

local t = function(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

-- supertab-like mapping
mapping = {
  ["<Tab>"] = cmp.mapping(function(fallback)
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(t("<C-n>"), "n")
    elseif luasnip.expand_or_jumpable() then
      vim.fn.feedkeys(t("<Plug>luasnip-expand-or-jump"), "")
    elseif check_back_space() then
      vim.fn.feedkeys(t("<Tab>"), "n")
    else
      fallback()
    end
  end, {
    "i",
    "s",
  }),
  ["<S-Tab>"] = cmp.mapping(function(fallback)
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
    vim_item.kind = require("lspkind").presets.default[vim_item.kind] .. " " .. vim_item.kind

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

Warning: If the LSP spec is changed, nvim-comp will keep up to it without announcement.

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
function source:get_debug_name = function()
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
