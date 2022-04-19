if vim.g.loaded_cmp then
  return
end
vim.g.loaded_cmp = true

local api = require('cmp.utils.api')
local misc = require('cmp.utils.misc')
local types = require('cmp.types')
local config = require('cmp.config')
local highlight = require('cmp.utils.highlight')
local emit = require('cmp.utils.autocmd').emit
local autocmds = require('cmp.autocmds')

misc.set(_G, { 'cmp', 'plugin', 'cmdline', 'leave' }, function()
  if vim.fn.expand('<afile>') ~= '=' then
    vim.cmd([[
      augroup cmp-cmdline
        autocmd!
      augroup END
    ]])
    emit('CmdlineLeave')
  end
end)

misc.set(_G, { 'cmp', 'plugin', 'cmdline', 'enter' }, function()
  if config.is_native_menu() then
    return
  end
  if vim.fn.expand('<afile>') ~= '=' then
    vim.schedule(function()
      if api.is_cmdline_mode() then
        autocmds.cmdline_mode()
        emit('CmdlineEnter')
      end
    end)
  end
end)

misc.set(_G, { 'cmp', 'plugin', 'colorscheme' }, function()
  highlight.inherit('CmpItemAbbrDefault', 'Pmenu', {
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpItemAbbrDeprecatedDefault', 'Comment', {
    gui = 'NONE',
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpItemAbbrMatchDefault', 'Pmenu', {
    gui = 'NONE',
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpItemAbbrMatchFuzzyDefault', 'Pmenu', {
    gui = 'NONE',
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpItemKindDefault', 'Special', {
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpItemMenuDefault', 'Pmenu', {
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  for name in pairs(types.lsp.CompletionItemKind) do
    if type(name) == 'string' then
      vim.cmd(([[highlight default link CmpItemKind%sDefault CmpItemKind]]):format(name))
    end
  end
end)
_G.cmp.plugin.colorscheme()

vim.cmd([[
  highlight default link CmpItemAbbr CmpItemAbbrDefault
  highlight default link CmpItemAbbrDeprecated CmpItemAbbrDeprecatedDefault
  highlight default link CmpItemAbbrMatch CmpItemAbbrMatchDefault
  highlight default link CmpItemAbbrMatchFuzzy CmpItemAbbrMatchFuzzyDefault
  highlight default link CmpItemKind CmpItemKindDefault
  highlight default link CmpItemMenu CmpItemMenuDefault
]])

for name in pairs(types.lsp.CompletionItemKind) do
  if type(name) == 'string' then
    local hi = ('CmpItemKind%s'):format(name)
    if vim.fn.hlexists(hi) ~= 1 then
      vim.cmd(([[highlight default link %s %sDefault]]):format(hi, hi))
    end
  end
end

if vim.on_key then
  vim.on_key(function(keys)
    if keys == vim.api.nvim_replace_termcodes('<C-c>', true, true, true) then
      vim.schedule(function()
        if not api.is_suitable_mode() then
          require('cmp.utils.autocmd').emit('InsertLeave')
        end
      end)
    end
  end, vim.api.nvim_create_namespace('cmp.plugin'))
end

vim.cmd([[command! CmpStatus lua require('cmp').status()]])

vim.cmd([[doautocmd <nomodeline> User CmpReady]])

autocmds.autocmd()
