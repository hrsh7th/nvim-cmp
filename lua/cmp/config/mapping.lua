local mapping
mapping = setmetatable({
  modes = function(definitions)
    return mapping(function(fallback)
      if api.is_insert_mode() and definitions.i then
        return definitions.i(fallback)
      elseif api.is_cmdline_mode() and definitions.c then
        return definitions.c(fallback)
      elseif api.is_select_mode() and definitions.s then
        return definitions.s(fallback)
      else
        fallback()
      end
    end, vim.tbl_keys(definitions))
  end,
}, {
  __call = function(_, invoke, modes)
    if type(invoke) == 'function' then
      return {
        invoke = function(...)
          invoke(...)
        end,
        modes = modes or { 'i' },
      }
    end
    return invoke
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

---Select next completion item.
mapping.select_next_item = function(option)
  return function(fallback)
    if not require('cmp').select_next_item(option) then
      fallback()
    end
  end
end

---Select prev completion item.
mapping.select_prev_item = function(option)
  return function(fallback)
    if not require('cmp').select_prev_item(option) then
      fallback()
    end
  end
end

---Confirm selection
mapping.confirm = function(option)
  return function(fallback)
    if not require('cmp').confirm(option) then
      fallback()
    end
  end
end

return mapping
