local M = {}
local emit = require('cmp.utils.autocmd').emit

function M.autocmd()
  local ___cmp___ = vim.api.nvim_create_augroup('___cmp___', { clear = true })
  vim.api.nvim_create_autocmd('InsertEnter', {
    group = ___cmp___,
    callback = function()
      emit('InsertEnter')
    end,
    desc = 'nvim-cmp: emits autocmd event for InsertEnter',
  })

  vim.api.nvim_create_autocmd('InsertLeave', {
    group = ___cmp___,
    callback = function()
      emit('InsertLeave')
    end,
    desc = 'nvim-cmp: emits autocmd event for InsertLeave',
  })

  vim.api.nvim_create_autocmd({
    'TextChangedI',
    'TextChangedP',
  }, {

    group = ___cmp___,
    callback = function()
      emit('TextChanged')
    end,
    desc = 'nvim-cmp: emits autocmd event for TextChangedI and TextChangedP',
  })

  vim.api.nvim_create_autocmd('CursorMovedI', {
    group = ___cmp___,
    callback = function()
      emit('CursorMoved')
    end,
    desc = 'nvim-cmp: emits autocmd event for CursorMovedI',
  })

  vim.api.nvim_create_autocmd('CompleteChanged', {
    group = ___cmp___,
    callback = function()
      emit('CompleteChanged')
    end,
    desc = 'nvim-cmp: emits autocmd event for CompleteChanged',
  })

  vim.api.nvim_create_autocmd('CompleteDone', {
    group = ___cmp___,
    callback = function()
      emit('CompleteDone')
    end,
    desc = 'nvim-cmp: emits autocmd event for CompleteDone',
  })

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = ___cmp___,
    callback = _G.cmp.plugin.colorscheme,
    desc = 'nvim-cmp: calling _G.cmp.plugin.colorscheme on ColorScheme event',
  })

  -- for entering cmdwin with `<C-f>`
  vim.api.nvim_create_autocmd('CmdlineEnter', {
    group = ___cmp___,
    callback = _G.cmp.plugin.cmdline.enter,
    desc = 'nvim-cmp: calling _G.cmp.plugin.cmdline.enter on CmdlineEnter event',
  })

  vim.api.nvim_create_autocmd('CmdwinEnter', {
    group = ___cmp___,
    callback = _G.cmp.plugin.cmdline.leave,
    desc = 'nvim-cmp: calling _G.cmp.plugin.cmdline.leave on CmdwinEnter',
  })
end

function M.cmdline_mode()
  local cmp_cmdline = vim.api.nvim_create_augroup('cmp-cmdline', { clear = true })
  vim.api.nvim_create_autocmd('CmdlineChanged', {
    group = cmp_cmdline,
    callback = function()
      emit('TextChanged')
    end,
    desc = 'nvim-cmp: emits autocmd TextChanged event on CmdlineChanged',
  })

  vim.api.nvim_create_autocmd('CmdlineLeave', {
    group = cmp_cmdline,
    callback = _G.cmp.plugin.cmdline.leave,
    desc = 'nvim-cmp: calling _G.cmp.plugin.cmdline.leave on CmdlineLeave event',
  })
end

return M
