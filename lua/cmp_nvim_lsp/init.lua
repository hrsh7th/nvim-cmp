local cmp = require('cmp')
local source = require('cmp_nvim_lsp.source')

vim.cmd([[
  augroup nvim_lsp
    autocmd!
    autocmd InsertEnter * lua require'cmp_nvim_lsp'()
  augroup END
]])

local source_ids = {}

return function()
  local active_client_ids = {}
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    active_client_ids[client.id] = true
    if not source_ids[client.id] then
      source_ids[client.id] = cmp.register_source('nvim_lsp', source.new(client))
    end
  end
  for _, client in ipairs(vim.lsp.buf_get_clients(0)) do
    active_client_ids[client.id] = true
    if not source_ids[client.id] then
      source_ids[client.id] = cmp.register_source('nvim_lsp', source.new(client))
    end
  end
  for client_id, source_id in pairs(source_ids) do
    if not active_client_ids[client_id] then
      cmp.unregister_source(source_id)
    end
  end
end
