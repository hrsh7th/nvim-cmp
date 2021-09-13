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

  it('_evacuate', function()
    local s = function(cmd, keys, buf)
      spec.before()
      vim.cmd(cmd)
      local existing = vim.tbl_filter(function(map)
        return map.lhs == keys
      end, keymap._getmaps('i'))[1] or {
        lhs = keys,
        rhs = keys,
        expr = 0,
        nowait = 0,
        noremap = 1,
      }
      local fallback = keymap._evacuate('i', existing)
      vim.api.nvim_feedkeys('i' .. keymap.t(fallback), 'x', true)
      assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, true), buf)
    end
    s([[]], '(', { '(' })
    s([[imap <expr> ( '<C-r>="("<CR>']], '(', { '(' })
    s([[imap ( (]], '(', { '(' })
  end)

end)
