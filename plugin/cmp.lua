if vim.g.loaded_cmp then
  return
end
vim.g.loaded_cmp = true

local api = require "cmp.utils.api"
local misc = require('cmp.utils.misc')
local config = require('cmp.config')
local highlight = require('cmp.utils.highlight')

-- TODO: https://github.com/neovim/neovim/pull/14661
vim.cmd [[
  augroup ___cmp___
    autocmd!
    autocmd InsertEnter * lua require'cmp.utils.autocmd'.emit('InsertEnter')
    autocmd InsertLeave * lua require'cmp.utils.autocmd'.emit('InsertLeave')
    autocmd TextChangedI,TextChangedP * lua require'cmp.utils.autocmd'.emit('TextChanged')
    autocmd CursorMovedI * lua require'cmp.utils.autocmd'.emit('CursorMoved')
    autocmd CompleteChanged * lua require'cmp.utils.autocmd'.emit('CompleteChanged')
    autocmd CompleteDone * lua require'cmp.utils.autocmd'.emit('CompleteDone')
    autocmd ColorScheme * call v:lua.cmp.plugin.colorscheme()
    autocmd CmdlineEnter * call v:lua.cmp.plugin.cmdline.enter()
    autocmd CmdlineLeave * call v:lua.cmp.plugin.cmdline.leave()
    autocmd TermEnter * call v:lua.cmp.plugin.term.enter()
    autocmd TermLeave * call v:lua.cmp.plugin.term.leave()
  augroup END
]]

local term_timer = vim.loop.new_timer()
misc.set(_G, { 'cmp', 'plugin', 'term', 'enter' }, function()
  require('cmp.utils.autocmd').emit('InsertEnter')

  local cursor = api.get_cursor()
  term_timer:start(100, 100, vim.schedule_wrap(function()
    local new_cursor = api.get_cursor()
    if cursor[1] ~= new_cursor[1] or cursor[2] ~= new_cursor[2] then
      cursor = new_cursor
      require('cmp.utils.autocmd').emit('TextChanged')
    end
  end))
end)
misc.set(_G, { 'cmp', 'plugin', 'term', 'leave' }, function()
  term_timer:stop()
  require('cmp.utils.autocmd').emit('InsertLeave')
end)

misc.set(_G, { 'cmp', 'plugin', 'cmdline', 'enter' }, function()
  if config.get().experimental.native_menu then
    return
  end
  local cmdtype = vim.fn.expand('<afile>')
  if cmdtype ~= '=' then
    if api.is_cmdline_mode() then
      vim.cmd [[
        augroup cmp-cmdline
          autocmd!
          autocmd CmdlineChanged * lua require'cmp.utils.autocmd'.emit('TextChanged')
        augroup END
      ]]
      require('cmp.utils.autocmd').emit('InsertEnter')
    end
  end
end)
misc.set(_G, { 'cmp', 'plugin', 'cmdline', 'leave' }, function()
  if config.get().experimental.native_menu then
    return
  end
  local cmdtype = vim.fn.expand('<afile>')
  if cmdtype ~= '=' then
    vim.cmd [[
      augroup cmp-cmdline
        autocmd!
      augroup END
    ]]
    require('cmp.utils.autocmd').emit('InsertLeave')
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

