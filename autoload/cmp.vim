let s:Position = vital#cmp#import('VS.LSP.Position')
let s:TextEdit = vital#cmp#import('VS.LSP.TextEdit')
let s:CompletionItem = vital#cmp#import('VS.LSP.CompletionItem')

"
" cmp#apply_text_edits
"
function! cmp#apply_text_edits(bufnr, text_edits) abort
  call s:TextEdit.apply(a:bufnr, a:text_edits)
endfunction

"
" cmp#confirm
"
function! cmp#confirm(args) abort
  call s:CompletionItem.confirm({
  \   'suggest_position': s:Position.vim_to_lsp('%', [line('.'), a:args.suggest_offset]),
  \   'request_position': s:Position.vim_to_lsp('%', [line('.'), a:args.request_offset]),
  \   'current_position': s:Position.vim_to_lsp('%', [line('.'), col('.')]),
  \   'current_line': getline('.'),
  \   'completion_item': a:args.completion_item,
  \   'expand_snippet': s:get_expand_snippet(),
  \ })
endfunction

"
" get_expand_snippet
"
function! s:get_expand_snippet() abort
  return { args -> vsnip#anonymous(args.body) }
endfunction

