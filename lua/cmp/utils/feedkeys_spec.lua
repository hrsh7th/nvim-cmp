local spec = require('cmp.utils.spec')
local keymap = require('cmp.utils.keymap')

local feedkeys = require('cmp.utils.feedkeys')

describe('feedkeys', function()
  before_each(spec.before)

  it('dot-repeat', function()
    local reg
    feedkeys.call(keymap.t('iaiueo<Esc>'), 'nx', function()
      reg = vim.fn.getreg('.')
    end)
    assert.are.equal(reg, keymap.t('aiueo'))
  end)

  it('textwidth', function()
    vim.cmd([[setlocal textwidth=6]])
    feedkeys.call(keymap.t('iaiueo '), 'nx')
    feedkeys.call(keymap.t('aaiueoaiueo'), 'nx')
    assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
      'aiueo aiueoaiueo',
    })
  end)

  it('autoindent', function()
    vim.cmd([[setlocal indentkeys+==end]])
    feedkeys.call(keymap.t('iif<CR><Tab>end') .. keymap.autoindent(), 'nx')
    assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
      'if',
      'end'
    })
  end)
end)
