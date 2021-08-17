local types = require('cmp.types')

local mapping = {}

mapping.mode = function(modes, action_or_invoke)
  local invoke = action_or_invoke
  if type(action_or_invoke) == 'table' then
    if type(action_or_invoke.invoke) == 'function' then
      invoke = action_or_invoke.invoke
    else
      error('`invoke` must be function or result of `cmp.mapping.mode`.')
    end
  end
  return {
    modes = modes,
    invoke = invoke,
  }
end

mapping.complete = function()
  return mapping.mode({ 'i' }, function(core)
    core.complete(core.get_context({ reason = types.cmp.ContextReason.Manual }))
  end)
end

mapping.close = function()
  return mapping.mode({ 'i' }, function(core, fallback)
    if vim.fn.pumvisible() == 1 then
      core.reset()
    else
      fallback()
    end
  end)
end

mapping.scroll = function(delta)
  return mapping.mode({ 'i' }, function(core, fallback)
    if core.menu.float:is_visible() then
      core.menu.float:scroll(delta)
    else
      fallback()
    end
  end)
end

mapping.next_item = function()
  return mapping.mode({ 'i' }, function(_, fallback)
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-n>', true, true, true), 'n')
    else
      fallback()
    end
  end)
end

mapping.prev_item = function()
  return mapping.mode({ 'i' }, function(_, fallback)
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<C-p>', true, true, true), 'n')
    else
      fallback()
    end
  end)
end

mapping.confirm = function(option)
  option = option or {}
  return mapping.mode({ 'i' }, function(core, fallback)
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
  end)
end

return mapping
