if vim.g.loaded_cmp then
  return
end
vim.g.loaded_cmp = true

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

if vim.fn.hlexists('CmpDocumentation') == 0 then
  vim.api.nvim_command [[highlight link CmpDocumentation NormalFloat]]
end

if vim.fn.hlexists('CmpDocumentationBorder') == 0 then
  vim.api.nvim_command [[highlight link CmpDocumentationBorder NormalFloat]]
end

