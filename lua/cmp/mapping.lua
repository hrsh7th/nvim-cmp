local misc = require('cmp.utils.misc')

local mapping = setmetatable({}, {
  __call = function(_, invoke, modes)
    return {
      invoke = function(...)
        invoke(...)
      end,
      modes = modes or { 'i' },
    }
  end,
})
---Invoke completion
mapping.complete = function()
  return function(fallback)
    if not require('cmp').complete() then
      fallback()
    end
  end
end

---Close current completion menu if it displayed.
mapping.close = function()
  return function(fallback)
    if not require('cmp').close() then
      fallback()
    end
  end
end

---Abort current completion menu if it displayed.
mapping.abort = function()
  return function(fallback)
    if not require('cmp').abort() then
      fallback()
    end
  end
end

---Scroll documentation window.
mapping.scroll_docs = function(delta)
  return function(fallback)
    if not require('cmp').scroll_docs(delta) then
      fallback()
    end
  end
end
mapping.scroll = misc.deprecated(mapping.scroll_docs, '`cmp.mapping.scroll` is deprecated. Please change it to `cmp.mapping.scroll_docs` instead.')

---Select next completion item.
mapping.select_next_item = function()
  return function(fallback)
    if not require('cmp').select_next_item() then
      fallback()
    end
  end
end
mapping.next_item = misc.deprecated(mapping.select_next_item, '`cmp.mapping.next_item` is deprecated. Please change it to `cmp.mapping.select_next_item` instead.')

---Select prev completion item.
mapping.select_prev_item = function()
  return function(fallback)
    if not require('cmp').select_prev_item() then
      fallback()
    end
  end
end
mapping.prev_item = misc.deprecated(mapping.select_prev_item, '`cmp.mapping.prev_item` is deprecated. Please change it to `cmp.mapping.select_prev_item` instead.')

---Confirm selection
mapping.confirm = function(option)
  return function(fallback)
    if not require('cmp').confirm(option) then
      fallback()
    end
  end
end

return mapping
