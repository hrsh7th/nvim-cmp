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
        local cmp_cmdline = vim.api.nvim_create_augroup('cmp_cmdline', { clear = true })
        vim.api.nvim_create_autocmd('CmdlineChanged', {
          group = cmp_cmdline,
          callback = function()
            emit('TextChanged')
          end,
        })

        vim.api.nvim_create_autocmd('CmdlineLeave', {
          group = cmp_cmdline,
          callback = _G.cmp.plugin.cmdline.leave,
        })
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
  for name in pairs(types.lsp.CompletionItemKind) do
    if type(name) == 'string' then
      vim.cmd(([[highlight default link CmpItemKind%sDefault CmpItemKind]]):format(name))
    end
  end
  highlight.inherit('CmpItemMenuDefault', 'Pmenu', {
    guibg = 'NONE',
    ctermbg = 'NONE',
  })
end)
_G.cmp.plugin.colorscheme()

if vim.fn.hlexists('CmpItemAbbr') ~= 1 then
  vim.cmd([[highlight default link CmpItemAbbr CmpItemAbbrDefault]])
end

if vim.fn.hlexists('CmpItemAbbrDeprecated') ~= 1 then
  vim.cmd([[highlight default link CmpItemAbbrDeprecated CmpItemAbbrDeprecatedDefault]])
end

if vim.fn.hlexists('CmpItemAbbrMatch') ~= 1 then
  vim.cmd([[highlight default link CmpItemAbbrMatch CmpItemAbbrMatchDefault]])
end

if vim.fn.hlexists('CmpItemAbbrMatchFuzzy') ~= 1 then
  vim.cmd([[highlight default link CmpItemAbbrMatchFuzzy CmpItemAbbrMatchFuzzyDefault]])
end

if vim.fn.hlexists('CmpItemKind') ~= 1 then
  vim.cmd([[highlight default link CmpItemKind CmpItemKindDefault]])
end
for name in pairs(types.lsp.CompletionItemKind) do
  if type(name) == 'string' then
    local hi = ('CmpItemKind%s'):format(name)
    if vim.fn.hlexists(hi) ~= 1 then
      vim.cmd(([[highlight default link %s %sDefault]]):format(hi, hi))
    end
  end
end

if vim.fn.hlexists('CmpItemMenu') ~= 1 then
  vim.cmd([[highlight default link CmpItemMenu CmpItemMenuDefault]])
end

vim.cmd([[command! CmpStatus lua require('cmp').status()]])

vim.cmd([[doautocmd <nomodeline> User CmpReady]])

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

local ___cmp___ = vim.api.nvim_create_augroup('___cmp___', { clear = true })
vim.api.nvim_create_autocmd('InsertEnter', {
  group = ___cmp___,
  callback = function()
    emit('InsertEnter')
  end,
})

vim.api.nvim_create_autocmd('InsertLeave', {
  group = ___cmp___,
  callback = function()
    emit('InsertLeave')
  end,
})

vim.api.nvim_create_autocmd({
  'TextChangedI',
  'TextChangedP',
}, {

  group = ___cmp___,
  callback = function()
    emit('TextChanged')
  end,
})

vim.api.nvim_create_autocmd('CursorMovedI', {
  group = ___cmp___,
  callback = function()
    emit('CursorMoved')
  end,
})

vim.api.nvim_create_autocmd('CompleteChanged', {
  group = ___cmp___,
  callback = function()
    emit('CompleteChanged')
  end,
})

vim.api.nvim_create_autocmd('CompleteDone', {
  group = ___cmp___,
  callback = function()
    emit('CompleteDone')
  end,
})

vim.api.nvim_create_autocmd('ColorScheme', {
  group = ___cmp___,
  callback = _G.cmp.plugin.colorscheme,
})

-- for entering cmdwin with `<C-f>`
vim.api.nvim_create_autocmd('CmdlineEnter', {
  group = ___cmp___,
  callback = _G.cmp.plugin.cmdline.enter,
})

-- -    autocmd CmdlineEnter * call v:lua.cmp.plugin.cmdline.enter()
vim.api.nvim_create_autocmd('CmdwinEnter', {
  group = ___cmp___,
  callback = _G.cmp.plugin.cmdline.leave,
})
