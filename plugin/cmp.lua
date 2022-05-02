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
  highlight.inherit('CmpItemAbbrDefault', 'Pmenu', { bg = 'NONE', default = true })
  highlight.inherit('CmpItemAbbrDeprecatedDefault', 'Comment', { bg = 'NONE', default = true })
  highlight.inherit('CmpItemAbbrMatchDefault', 'Pmenu', { bg = 'NONE', default = true })
  highlight.inherit('CmpItemAbbrMatchFuzzyDefault', 'Pmenu', { bg = 'NONE', default = true })
  highlight.inherit('CmpItemKindDefault', 'Special', { bg = 'NONE', default = true })
  highlight.inherit('CmpItemMenuDefault', 'Pmenu', { bg = 'NONE', default = true })
  for name in pairs(types.lsp.CompletionItemKind) do
    if type(name) == 'string' then
      vim.api.nvim_set_hl(0, ('CmpItemKind%sDefault'):format(name), { link = 'CmpItemKind', default = true })
    end
  end
end)
_G.cmp.plugin.colorscheme()

vim.api.nvim_set_hl(0, 'CmpItemAbbr', { link = 'CmpItemAbbrDefault', default = true })
vim.api.nvim_set_hl(0, 'CmpItemAbbrDeprecated', { link = 'CmpItemAbbrDeprecatedDefault', default = true })
vim.api.nvim_set_hl(0, 'CmpItemAbbrMatch', { link = 'CmpItemAbbrMatchDefault', default = true })
vim.api.nvim_set_hl(0, 'CmpItemAbbrMatchFuzzy', { link = 'CmpItemAbbrMatchFuzzyDefault', default = true })
vim.api.nvim_set_hl(0, 'CmpItemKind', { link = 'CmpItemKindDefault', default = true })
vim.api.nvim_set_hl(0, 'CmpItemMenu', { link = 'CmpItemMenuDefault', default = true })

for name in pairs(types.lsp.CompletionItemKind) do
  if type(name) == 'string' then
    local hi = ('CmpItemKind%s'):format(name)
    if vim.fn.hlexists(hi) ~= 1 then
      vim.api.nvim_set_hl(0, hi, { link = ('%sDefault'):format(hi), default = true })
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

vim.api.nvim_create_user_command('CmpStatus', function()
  require('cmp').status()
end, { desc = 'Check status of cmp sources' })

vim.cmd([[doautocmd <nomodeline> User CmpReady]])

autocmds.autocmd()
