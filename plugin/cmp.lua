local api = require "cmp.utils.api"
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
    autocmd CmdlineEnter,InsertEnter * lua require'cmp.utils.autocmd'.emit('InsertEnter')
    autocmd CmdlineLeave,InsertLeave * lua require'cmp.utils.autocmd'.emit('InsertLeave')
    autocmd CmdlineChanged,TextChangedI,TextChangedP * lua require'cmp.utils.autocmd'.emit('TextChanged')
    autocmd CursorMovedI * lua require'cmp.utils.autocmd'.emit('CursorMoved')
    autocmd CompleteChanged * lua require'cmp.utils.autocmd'.emit('CompleteChanged')
    autocmd CompleteDone * lua require'cmp.utils.autocmd'.emit('CompleteDone')
    autocmd ColorScheme * call v:lua.cmp.plugin.colorscheme()
    autocmd TermEnter * call v:lua.cmp.plugin.polling_s()
    autocmd TermLeave * call v:lua.cmp.plugin.polling_e()
  augroup END
]]

local timer = vim.loop.new_timer()
misc.set(_G, { 'cmp', 'plugin', 'polling_s' }, function()
  require('cmp.utils.autocmd').emit('InsertEnter')
  local cursor = api.get_cursor()
  timer:start(1, 1, vim.schedule_wrap(function()
    local new_cursor = api.get_cursor()
    if cursor[1] ~= new_cursor[1] or cursor[2] ~= new_cursor[2] then
      require('cmp.utils.autocmd').emit('TextChanged')
    end
  end))
end)
misc.set(_G, { 'cmp', 'plugin', 'polling_e' }, function()
  timer:stop()
  require('cmp.utils.autocmd').emit('InsertLeave')
end)


misc.set(_G, { 'cmp', 'plugin', 'colorscheme' }, function()
  highlight.inherit('CmpItemAbbrDefault', 'Comment', {
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpItemAbbrDeprecatedDefault', 'Comment', {
    gui = 'NONE',
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpItemAbbrMatchDefault', 'Normal', {
    gui = 'bold',
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpItemAbbrMatchFuzzyDefault', 'Normal', {
    gui = 'NONE',
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpItemKindDefault', 'Special', {
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
  highlight.inherit('CmpItemMenuDefault', 'NonText', {
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
end)
_G.cmp.plugin.colorscheme()

if vim.fn.hlexists('CmpItemAbbr') ~= 1 then
  vim.cmd [[highlight! default link CmpItemAbbr CmpItemAbbrDefault]]
end

if vim.fn.hlexists('CmpItemAbbrDeprecated') ~= 1 then
  vim.cmd [[highlight! default link CmpItemAbbrDeprecated CmpItemAbbrDeprecatedDefault]]
end

if vim.fn.hlexists('CmpItemAbbrMatch') ~= 1 then
  vim.cmd [[highlight! default link CmpItemAbbrMatch CmpItemAbbrMatchDefault]]
end

if vim.fn.hlexists('CmpItemAbbrMatchFuzzy') ~= 1 then
  vim.cmd [[highlight! default link CmpItemAbbrMatchFuzzy CmpItemAbbrMatchFuzzyDefault]]
end

if vim.fn.hlexists('CmpItemKind') ~= 1 then
  vim.cmd [[highlight! default link CmpItemKind CmpItemKindDefault]]
end

if vim.fn.hlexists('CmpItemMenu') ~= 1 then
  vim.cmd [[highlight! default link CmpItemMenu CmpItemMenuDefault]]
end

vim.cmd [[command! CmpStatus lua require('cmp').status()]]

vim.cmd [[doautocmd <nomodeline> User cmp#ready]]

