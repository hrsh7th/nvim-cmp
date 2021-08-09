local spec = require('cmp.utils.spec')

local keymap = require('cmp.utils.keymap')

describe('keymap', function()
  before_each(spec.before)

  it('to_keymap', function()
    assert.are.equal(keymap.to_keymap('\n'), '<CR>')
    assert.are.equal(keymap.to_keymap('<CR>'), '<CR>')
    assert.are.equal(keymap.to_keymap('|'), '<Bar>')
  end)

  it('escape', function()
    assert.are.equal(keymap.escape('<C-d>'), '<LT>C-d>')
    assert.are.equal(keymap.escape('<C-d><C-f>'), '<LT>C-d><LT>C-f>')
    assert.are.equal(keymap.escape('<LT>C-d>'), '<LT>C-d>')
  end)
end)
