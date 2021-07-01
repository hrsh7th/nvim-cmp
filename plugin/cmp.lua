if vim.g.loaded_cmp then
  return
end
vim.g.loaded_cmp = true

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

if vim.fn.hlexists('CmpReplaceRange') == 0 then
  vim.cmd [[highlight link CmpReplaceRange Folded]]
end

