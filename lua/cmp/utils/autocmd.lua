local debug = require('cmp.utils.debug')

local autocmd = {}

autocmd.group = vim.api.nvim_create_augroup('___cmp___', { clear = true })

autocmd.events = {}

local function create_autocmd(event)
  vim.api.nvim_create_autocmd(event, {
    desc = ('nvim-cmp: autocmd: %s'):format(event),
    group = autocmd.group,
    callback = function()
      autocmd.emit(event)
    end,
  })
end

---Subscribe autocmd
---@param events string|string[]
---@param callback function
---@return function
autocmd.subscribe = function(events, callback)
  events = type(events) == 'string' and { events } or events

  for _, event in ipairs(events) do
    if not autocmd.events[event] then
      autocmd.events[event] = {}
      create_autocmd(event)
    end
    table.insert(autocmd.events[event], callback)
  end

  return function()
    for _, event in ipairs(events) do
      for i, callback_ in ipairs(autocmd.events[event]) do
        if callback_ == callback then
          table.remove(autocmd.events[event], i)
          break
        end
      end
    end
  end
end

---Emit autocmd
---@param event string
autocmd.emit = function(event)
  debug.log(' ')
  debug.log(string.format('>>> %s', event))
  autocmd.events[event] = autocmd.events[event] or {}
  for _, callback in ipairs(autocmd.events[event]) do
    callback()
  end
end

---Resubscribe to events
---@param events string[]
autocmd.resubscribe = function(events)
  -- Delete the autocommands if present
  local found = vim.api.nvim_get_autocmds({
    group = autocmd.group,
    event = events,
  })
  for _, to_delete in ipairs(found) do
    vim.api.nvim_del_autocmd(to_delete.id)
  end

  -- Recreate if event is known
  for _, event in ipairs(events) do
    if autocmd.events[event] then
      create_autocmd(event)
    end
  end
end

return autocmd
