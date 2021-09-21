if vim.g.loaded_cmp then
  return
end
vim.g.loaded_cmp = true

local misc = require('cmp.utils.misc')
local highlight = require('cmp.utils.highlight')

-- TODO: https://github.com/neovim/neovim/pull/14661
vim.cmd [[
  augroup cmp
    autocmd!
    autocmd InsertEnter * lua require'cmp.utils.autocmd'.emit('InsertEnter')
    autocmd InsertLeave * lua require'cmp.utils.autocmd'.emit('InsertLeave')
    autocmd InsertCharPre * lua require'cmp.utils.autocmd'.emit('InsertCharPre')
    autocmd TextChangedI,TextChangedP * lua require'cmp.utils.autocmd'.emit('TextChanged')
    autocmd CompleteChanged * lua require'cmp.utils.autocmd'.emit('CompleteChanged')
    autocmd CompleteDone * lua require'cmp.utils.autocmd'.emit('CompleteDone')
  augroup END
]]


highlight.inherit('CmpMatch', 'Normal', {
  gui = 'bold',
  guibg = 'NONE',
  ctermbg = 'NONE',
})
highlight.inherit('CmpMatchFuzzy', 'Normal', {
  gui = 'NONE',
  guibg = 'NONE',
  ctermbg = 'NONE',
})

vim.cmd [[command! CmpStatus lua require('cmp').status()]]

vim.cmd [[doautocmd <nomodeline> User cmp#ready]]

