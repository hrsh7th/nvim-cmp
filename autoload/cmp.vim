let s:TextEdit = vital#cmp#import('VS.LSP.TextEdit')

"
" cmp#apply_text_edits
"
function! cmp#apply_text_edits(bufnr, text_edits) abort
  call s:TextEdit.apply(a:bufnr, a:text_edits)
endfunction

