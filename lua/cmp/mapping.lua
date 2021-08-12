local types = require('cmp.types')

local mapping = {}

mapping.complete = function()
  return function(core)
    core.complete(core.get_context({ reason = types.cmp.ContextReason.Manual }))
  end
end

mapping.close = function()
  return function(core, fallback)
    if vim.fn.pumvisible() == 1 then
      core.close()
    else
      fallback()
    end
  end
end

mapping.scroll = function(delta)
  return function(core, fallback)
    if core.menu.float:is_visible() then
      core.menu.float:scroll(delta)
    else
      fallback()
    end
  end
end

mapping.next_item = function()
  return function(_, fallback)
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-n>', 'n'))
    else
      fallback()
    end
  end
end

mapping.prev_item = function()
  return function(_, fallback)
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-p>', 'n'))
    else
      fallback()
    end
  end
end

mapping.confirm = function(option)
  option = option or {}
  return function(core, fallback)
    local e = core.menu:get_selected_entry() or (option.select and core.menu:get_first_entry() or nil)
    if e then
      core.confirm(e, {
        behavior = option.behavior,
      }, function()
        core.complete(core.get_context({ reason = types.cmp.ContextReason.TriggerOnly }))
      end)
    else
      fallback()
    end
  end
end

return mapping
