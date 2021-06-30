local core = require "cmp.core"
local source = require'cmp.source'

local cmp = {}

---Register completion sources
---@param name string
---@param s cmp.Source
---@return number
cmp.register_source = function(name, s)
  local src = source.new(name, s)
  core.register_source(src)
  return src.id
end

---Unregister completion source
---@param id number
cmp.unregister_source = function(id)
  core.unregister_source(id)
end

---Receive vim autocmds
---@param name string
cmp._on_event = function(name)
  if name == 'InsertEnter' then
    core.autocomplete();
  elseif name == 'TextChanged' then
    core.autocomplete();
  elseif name == 'CompleteChanged' then
    core.select()
  elseif name == 'InsertLeave' then
    vim.schedule(function()
      if not vim.tbl_contains({ 'i', 'ic' }, vim.api.nvim_get_mode().mode) then
        core.reset()
      end
    end)
  end
end

return cmp

