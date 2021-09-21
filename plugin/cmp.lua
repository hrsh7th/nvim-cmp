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
    autocmd ColorScheme * call v:lua.cmp.plugin.colorscheme()
  augroup END
]]

vim.cmd [[inoremap <silent> <Plug>(cmp-autoindent) <Cmd>call v:lua.cmp.plugin.autoindent()<CR>]]
misc.set(_G, { 'cmp', 'plugin', 'autoindent' }, function()
  local startofline = vim.o.startofline
  local virtualedit = vim.o.virtualedit
  vim.o.startofline = false
  vim.o.virtualedit = 'all'
  vim.cmd [[normal! ==]]
  vim.o.startofline = startofline
  vim.o.virtualedit = virtualedit
end)

misc.set(_G, { 'cmp', 'plugin', 'colorscheme' }, function()
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

  highlight.inherit('CmpAbbr', 'Comment', {
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpKind', 'Special', {
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpMenu', 'Comment', {
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
end)
_G.cmp.plugin.colorscheme()

vim.cmd [[command! CmpStatus lua require('cmp').status()]]

