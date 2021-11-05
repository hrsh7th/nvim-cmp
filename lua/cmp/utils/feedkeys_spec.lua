local spec = require('cmp.utils.spec')
local keymap = require('cmp.utils.keymap')

local feedkeys = require('cmp.utils.feedkeys')

describe('feedkeys', function()
  before_each(spec.before)

  it('dot-repeat', function()
    feedkeys.call(keymap.t('iaiueo<Esc>'), 'n', function()
      assert.are.equal(vim.fn.getreg('.'), keymap.t('aiueo'))
    end)
    feedkeys.call('', 'nx')
  end)
end)
