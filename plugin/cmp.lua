if vim.g.loaded_cmp then
  return
end
vim.g.loaded_cmp = true

local misc = require('cmp.utils.misc')

-- TODO: https://github.com/neovim/neovim/pull/14661
vim.cmd [[
  augroup cmp
    autocmd!
    autocmd InsertEnter * lua require'cmp.utils.autocmd'.emit('InsertEnter')
    autocmd InsertLeave * lua require'cmp.utils.autocmd'.emit('InsertLeave')
    autocmd TextChangedI,TextChangedP * lua require'cmp.utils.autocmd'.emit('TextChanged')
    autocmd CompleteChanged * lua require'cmp.utils.autocmd'.emit('CompleteChanged')
    autocmd CompleteDone * lua require'cmp.utils.autocmd'.emit('CompleteDone')
  augroup END
]]

vim.cmd [[inoremap <silent> <Plug>(cmp-autoindent) <Cmd>call v:lua.cmp.autoindent()<CR>]]
misc.set(_G, { 'cmp', 'autoindent' }, function()
  local startofline = vim.o.startofline
  local virtualedit = vim.o.virtualedit
  vim.o.startofline = false
  vim.o.virtualedit = 'all'
  vim.cmd [[normal! ==]]
  vim.o.startofline = startofline
  vim.o.virtualedit = virtualedit
end)

vim.cmd [[command! CmpStatus lua require('cmp').status()]]

vim.cmd [[doautocmd <nomodeline> User cmp#ready]]

