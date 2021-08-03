# nvim-cmp

A completion plugin for neovim written in Lua.


Status
====================

not yet stable but ok to use (for testing).

Development
====================

You should read [type definitions](/lua/cmp/types) and [LSP spec](https://microsoft.github.io/language-server-protocol/specifications/specification-current/) to develop core or sources.

### Overview

`nvim-cmp` emphasizes compatibility with the VSCode behavior and the LSP specification but there are some little differences.

1. In `nvim-cmp`, the `CompletionItem` can have `word` and `dup` property that introduced by vim's completion mechanism.


### Create custom source

The example source is here.

- The `complete` function is required but others can be omitted.
- The `callback` argument must always be called.

```lua
local source = {}

---Create source.
source.new = function()
  local self = setmetatable({}, { __index = source })
  self.your_awesome_variable = 1
  return self
end

---Return keyword pattern which will be used by the followings.
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

---Invoke completion.
---@param request  cmp.CompletionRequest
---@param callback fun(response: lsp.CompletionResponse|nil)
---NOTE: This method is required.
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

