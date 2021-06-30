if exists('g:loaded_cmp')
  finish
endif
let g:loaded_cmp = v:true

augroup cmp
  autocmd!
  autocmd InsertEnter * lua require'cmp'._on_event('InsertEnter')
  autocmd TextChangedI,TextChangedP * lua require'cmp'._on_event('TextChanged')
  autocmd CompleteChanged * lua require'cmp'._on_event('CompleteChanged')
  autocmd InsertLeave * lua require'cmp'._on_event('InsertLeave')
augroup END

if !hlexists('CmpReplaceRange')
  highlight link CmpReplaceRange Folded
endif

