# nvim-cmp

A completion plugin for neovim written in Lua.

Status
====================

not yet stable but ok to use (for testing).


Configuration
====================

First, You should install core and sources by your favorite plugin manager.

The `nvim-cmp` sources can be found in [here](https://github.com/topics/nvim-cmp).

```viml
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-buffer'
```

Then setup configuration.

```viml
" Setup global configuration
lua <<EOF
  require'cmp'.setup {
    -- You should change this example to your chosen snippet engine.
    snippet = {
      expand = function(args)
        -- You must install `vim-vsnip` if you set up as same as the following.
        vim.fn['vsnip#anonymous'](args.body)
      end
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

### completion.autocomplete (type: cmp.TriggerEvent[])

The autocompletion trigger events.

If you specify an empty table, nvim-cmp does not perform completion automatically.

But you can still use manual completion. It is similar to omni-completion.


### completion.keyword_pattern (type: string)

A default keyword pattern. This value will be used if the source has no source specific pattern.


### completion.keyword_length (type: number)

A minimum keyword length to completion.


### completion.completeopt (type: string)

A vim's `completeopt` setting. Warning: Be careful when changing this value.


### sorting.priority_weight (type: number)

A the source priority for sorting.

`score + ((#sources - (source_index - 1)) * sorting.priority_weight)`


### sorting.comparators (type: function[])

A comparator function list. The function must return `boolean|nil`.


Source creation
====================

If you publish `nvim-cmp` source to GitHub, please add `nvim-cmp` topic for the repo.

You should read [cmp types](/lua/cmp/types) and [LSP spec](https://microsoft.github.io/language-server-protocol/specifications/specification-current/) to create sources.

- The `complete` function is required but others can be omitted.
- The `callback` argument must always be called.

You can use only `require('cmp')` in the custom source.

```lua
local source = {}

---Source constructor.
source.new = function()
  local self = setmetatable({}, { __index = source })
  self.your_awesome_variable = 1
  return self
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

