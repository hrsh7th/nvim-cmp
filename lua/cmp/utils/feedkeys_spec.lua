local spec = require('cmp.utils.spec')
local keymap = require('cmp.utils.keymap')

local feedkeys = require('cmp.utils.feedkeys')

describe('feedkeys', function()
  before_each(spec.before)

  it('dot-repeat', function()
    feedkeys.call(keymap.t('iaiueo<Esc>'), 'nx')
    assert.are.equal(vim.fn.getreg('.'), keymap.t('aiueo'))
  end)
  it('macro', function()
    vim.fn.setreg('q', '')
    vim.cmd([[normal! qq]])
    feedkeys.call(keymap.t('iaiueo'), 'nt')
    feedkeys.call(keymap.t('<Esc>'), 'nt', function()
      vim.cmd([[normal! q]])
      assert.are.equal(vim.fn.getreg('q'), keymap.t('iaiueo<Esc>'))
      print(vim.fn.getreg('q'))
    end)
  end)
end)
