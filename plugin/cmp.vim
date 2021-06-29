if exists('g:loaded_cmp')
  finish
endif
let g:loaded_cmp = v:true

augroup cmp
  autocmd!
  autocmd InsertLeave * lua require'cmp'._on_event('InsertLeave')
  autocmd TextChangedI,TextChangedP * lua require'cmp'._on_event('TextChanged')
  autocmd CompleteChanged * lua require'cmp'._on_event('CompleteChanged')
augroup END

