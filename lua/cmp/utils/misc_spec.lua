local spec = require('cmp.utils.spec')

local misc = require('cmp.utils.misc')

describe('misc', function()
  before_each(spec.before)

  describe('merge', function()
    it('replaces values from the left', function()
      local merged = misc.merge({
        recipient = 'World',
        new_key = 'I am new',
      }, {
        greeting = 'Hello',
        recipient = 'Handsome',
      })
      assert.are.equal(merged.greeting, 'Hello')
      assert.are.equal(merged.recipient, 'World')
      assert.are.equal(merged.new_key, 'I am new')
    end)

    it('merges subkeys of tables from the left', function()
      local merged = misc.merge({
        x = {
          c = 12,
        },
      }, {
        x = {
          a = 1,
          b = 2,
          c = 3,
        },
      })
      assert.are.same(merged.x, { a = 1, b = 2, c = 12 })
    end)

    it('does not change tables when merging empty table', function()
      local merged = misc.merge({
        tbl = {},
        other = {},
      }, {
        tbl = { hello = 'world' },
        other = 'hello',
      })
      assert.are.same(merged, {
        tbl = { hello = 'world' },
        other = {},
      })
    end)

    it('replaces non-tables types', function()
      local merged
      merged = misc.merge({
        arr = { 'hello' },
        num = 42,
        boo = false,
        str = 'world',
      }, {
        arr = { 'see ya' },
        num = 41,
        boo = true,
        str = 'land',
      })
      assert.are.same(merged.arr, { 'hello' })
      assert.are.equal(merged.num, 42)
      assert.are.equal(merged.boo, false)
      assert.are.equal(merged.str, 'world')
    end)
  end)
end)
