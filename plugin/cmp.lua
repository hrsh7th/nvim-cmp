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
    autocmd InsertEnter * lua require'cmp.autocmd'.emit('InsertEnter')
    autocmd InsertLeave * lua require'cmp.autocmd'.emit('InsertLeave')
    autocmd TextChangedI,TextChangedP * lua require'cmp.autocmd'.emit('TextChanged')
    autocmd CompleteChanged * lua require'cmp.autocmd'.emit('CompleteChanged')
    autocmd CompleteDone * lua require'cmp.autocmd'.emit('CompleteDone')
  augroup END
]]

if vim.fn.hlexists('CmpDocumentation') == 0 then
  vim.cmd [[highlight link CmpDocumentation NormalFloat]]
end

if vim.fn.hlexists('CmpDocumentationBorder') == 0 then
  vim.cmd [[highlight link CmpDocumentationBorder NormalFloat]]
end

