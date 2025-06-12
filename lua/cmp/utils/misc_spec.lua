local spec = require('cmp.utils.spec')

local misc = require('cmp.utils.misc')

describe('misc', function()
  before_each(spec.before)

  it('copy', function()
    -- basic.
    local tbl, copy
    tbl = {
      a = {
        b = 1,
      },
    }
    copy = misc.copy(tbl)
    assert.are_not.equal(tbl, copy)
    assert.are_not.equal(tbl.a, copy.a)
    assert.are.same(tbl, copy)

    -- self reference.
    tbl = {
      a = {
        b = 1,
      },
    }
    tbl.a.c = tbl.a
    copy = misc.copy(tbl)
    assert.are_not.equal(tbl, copy)
    assert.are_not.equal(tbl.a, copy.a)
    assert.are_not.equal(tbl.a.c, copy.a.c)
    assert.are.same(tbl, copy)
  end)

  it('merge', function()
    local merged
    merged = misc.merge({
      a = {},
    }, {
      a = {
        b = 1,
      },
    })
    assert.are.equal(merged.a.b, 1)

    merged = misc.merge({
      a = {
        i = 1,
      },
    }, {
      a = {
        c = 2,
      },
    })
    assert.are.equal(merged.a.i, 1)
    assert.are.equal(merged.a.c, 2)

    merged = misc.merge({
      a = false,
    }, {
      a = {
        b = 1,
      },
    })
    assert.are.equal(merged.a, false)

    merged = misc.merge({
      a = misc.none,
    }, {
      a = {
        b = 1,
      },
    })
    assert.are.equal(merged.a, nil)

    merged = misc.merge({
      a = misc.none,
    }, {
      a = nil,
    })
    assert.are.equal(merged.a, nil)

    merged = misc.merge({
      a = nil,
    }, {
      a = misc.none,
    })
    assert.are.equal(merged.a, nil)
  end)
end)
