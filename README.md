# nvim-cmp

A completion plugin for neovim written in Lua.


Status
====================

not yet stable but ok to use (for testing).


Features
====================

- Support pairs-wise plugin automatically
- Fully customizable via Lua functions (WIP)
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

First, You should install core and sources by your favorite plugin manager.

The `nvim-cmp` sources can be found in [here](https://github.com/topics/nvim-cmp).

```viml
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-buffer'
```

Then setup configuration.

```viml
" Setup global configuration. More on configuration below.
lua <<EOF
  local cmp = require('cmp')
  cmp.setup {
    -- You should change this example to your chosen snippet engine.
    snippet = {
      expand = function(args)
        -- You must install `vim-vsnip` if you set up as same as the following.
        vim.fn['vsnip#anonymous'](args.body)
      end
    },

    -- You must set mapping.
    mapping = {
      ['<C-p>'] = cmp.mapping.prev_item(),
      ['<C-n>'] = cmp.mapping.next_item(),
      ['<C-d>'] = cmp.mapping.scroll(-4),
      ['<C-f>'] = cmp.mapping.scroll(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.close(),
      ['<CR>'] = cmp.mapping.confirm({
        behavior = cmp.ConfirmBehavior.Replace,
        select = true,
      })
    },

    -- You should specify your *installed* sources.
    sources = {
      { name = 'buffer' }
    },
  }
EOF

" Setup buffer configuration
autocmd FileType markdown lua require'cmp'.setup.buffer {
\   sources = {
\     { name = 'buffer' },
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
    autocomplete = { .. },
    completeopt = 'menu,menuone,noselect',
    keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]],
    keyword_length = 1,
  },
  sorting = {
    priority_weight = 2.,
    comparators = { ... },
  },
  mapping = {
    ['<C-p>'] = cmp.mapping.prev_item(),
    ['<C-n>'] = cmp.mapping.next_item(),
    ['<C-d>'] = cmp.mapping.scroll(-4),
    ['<C-f>'] = cmp.mapping.scroll(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.close(),
    ['<CR>'] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    })
  },
  sources = { ... },
  ...
}
```

### mapping (type: table<string, fun(core: cmp.Core, fallback: function)>)

_TODO: This API is not stable yet. It can be changed with no announcement._

Define mappings with `cmp.mapping` helper.

The `cmp.mapping` helper has the below functions.

- *cmp.mapping.confirm({ select = true or false, behavior = cmp.ConfirmBehavior.Insert or cmp.ConfirmBehavior.Replace })*
- *cmp.mapping.complete()*
- *cmp.mapping.close()*
- *cmp.mapping.next_item()*
- *cmp.mapping.prev_item()*
- *cmp.mapping.scroll(delta = number)*

You can use `<Tab>`and `<S-Tab>` for navigating menu.

```lua
-- This is just an example of LusSnip integration. You have to adjust it yourself.
local luasnip = require'luasnip'
local cmp = require'cmp'
cmp.setup {
  mapping = {
    ['<Tab>'] = cmp.mapping.mode({ 'i', 's' }, function(_, fallback)
      if vim.fn.pumvisible() == 1 then
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-n>', true, true, true), 'n')
      elseif luasnip.expand_or_jumpable() then
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<Plug>luasnip-expand-or-jump', true, true, true), '')
      else
        fallback()
      end
    end),
    ['<S-Tab>'] = cmp.mapping.mode({ 'i', 's' }, function(_, fallback)
      if vim.fn.pumvisible() == 1 then
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-p>', true, true, true), 'n')
      elseif luasnip.jumpable(-1) then
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<Plug>luasnip-jump-prev', true, true, true), '')
      else
        fallback()
      end
    end)
  }
}
```

### completion.autocomplete (type: cmp.TriggerEvent[])

Which events should trigger `autocompletion`.

If you leave this empty or `nil`, `nvim-cmp` does not perform completion automatically.
You can still use manual completion though (like omni-completion).

Default: `{types.cmp.TriggerEvent.InsertEnter, types.cmp.TriggerEvent.TextChanged}`

### completion.keyword_pattern (type: string)

The default keyword pattern.  This value will be used if a source does not set a source specific pattern.

Default: `[[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]]`

### completion.keyword_length (type: number)

The minimal length of a word to complete; e.g., do not try to complete when the
length of the word to the left of the cursor is less than `keyword_length`.

Default: `1`


### completion.completeopt (type: string)

vim's `completeopt` setting. Warning: Be careful when changing this value.

Default: `menu,menuone,noselect`


### formatting.format (type: fun(entry: cmp.Entry, vim_item: vim.CompletedItem): vim.CompletedItem)

A function to customize completion menu.

You can display the fancy icons to completion-menu with [lspkind-nvim](https://github.com/onsails/lspkind-nvim).

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

### sorting.priority_weight (type: number)

When sorting completion items before displaying them, boost each item's score
based on the originating source. Each source gets a base priority of `#sources -
(source_index - 1)`, and we then multiply this by `priority_weight`:

`score = score + ((#sources - (source_index - 1)) * sorting.priority_weight)`

Default: `2`

### sorting.comparators (type: function[])

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
---@return string
function source:get_keyword_pattern()
  return '???'
end

---Return trigger characters.
---@return string[]
function source:get_trigger_characters()
  return { ??? }
end

---Invoke completion (required).
---  If you want to abort completion, just call the callback without arguments.
---@param request  cmp.CompletionRequest
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(request, callback)
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
