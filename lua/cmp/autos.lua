local M = {}

local v = vim.version()
local has_native_autocmd = v.major >= 0 and v.minor >= 7

local emit = require('cmp.utils.autocmd').emit
local ___cmp___ = vim.api.nvim_create_augroup('___cmp___', { clear = true })

local function nvim_auto()
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
end

local function legacy_auto()
  vim.cmd([[
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
    autocmd CmdwinEnter * call v:lua.cmp.plugin.cmdline.leave() " for entering cmdwin with `<C-f>`
  augroup END
]])
end

local function nvim_cmdline_mode()
  local cmp_cmdline = vim.api.nvim_create_augroup('cmp-cmdline', { clear = true })
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
end

local function legacy_cmdline_mode()
  vim.cmd([[
	 	augroup cmp-cmdline
   	  autocmd!
   	  autocmd CmdlineChanged * lua require'cmp.utils.autocmd'.emit('TextChanged')
   	  autocmd CmdlineLeave * call v:lua.cmp.plugin.cmdline.leave()
   	augroup END
	 ]])
end

function M.autocmd()
  if has_native_autocmd then
    nvim_auto()
  else
    legacy_auto()
  end
end

function M.cmdline_mode()
  if has_native_autocmd then
    nvim_cmdline_mode()
  else
    legacy_cmdline_mode()
  end
end

return M
