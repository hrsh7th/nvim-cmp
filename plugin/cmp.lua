if vim.g.loaded_cmp then
  return
end
vim.g.loaded_cmp = true

local cmp = require'cmp'
local misc = require'cmp.utils.misc'

-- TODO: https://github.com/neovim/neovim/pull/14661
vim.cmd [[
  augroup cmp
    autocmd!
    autocmd InsertEnter * lua require'cmp'._on_event('InsertEnter')
    autocmd TextChangedI,TextChangedP * lua require'cmp'._on_event('TextChanged')
    autocmd CompleteChanged * lua require'cmp'._on_event('CompleteChanged')
    autocmd InsertLeave * lua require'cmp'._on_event('InsertLeave')
  augroup END
]]

if vim.fn.hlexists('CmpDocumentation') == 0 then
  vim.cmd [[highlight link CmpDocumentation NormalFloat]]
end

if vim.fn.hlexists('CmpDocumentationBorder') == 0 then
  vim.cmd [[highlight link CmpDocumentationBorder NormalFloat]]
end

---@param callback fun()
misc.set(_G, { 'cmp', 'complete' }, function()
  cmp.complete()
  return vim.api.nvim_replace_termcodes('<Ignore>', true, true, true)
end)

