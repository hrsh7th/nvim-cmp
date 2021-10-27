local api = require('cmp.utils.api')

local mapping
mapping = setmetatable({}, {
  __call = function(_, invoke, modes)
    if type(invoke) == 'function' then
      return {
        invoke = function(...)
          invoke(...)
        end,
        modes = modes or { 'i' },
        __type = 'mapping',
      }
    elseif type(invoke) == 'table' then
      if invoke.__type == 'mapping' then
        return invoke
      else
        return mapping(function(fallback)
          if api.is_insert_mode() and invoke.i then
            return invoke.i(fallback)
          elseif api.is_cmdline_mode() and invoke.c then
            return invoke.c(fallback)
          elseif api.is_select_mode() and invoke.s then
            return invoke.s(fallback)
          else
            fallback()
          end
        end, vim.tbl_keys(invoke))
      end
    end
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
      local release = require('cmp').core:suspend()
      fallback()
      vim.schedule(release)
    end
  end
end

---Select prev completion item.
mapping.select_prev_item = function(option)
  return function(fallback)
    if not require('cmp').select_prev_item(option) then
      local release = require('cmp').core:suspend()
      fallback()
      vim.schedule(release)
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
