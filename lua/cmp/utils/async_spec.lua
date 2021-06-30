local async = require "cmp.utils.async"

describe('utils.async', function()

  it('sync', function()
    local v1, v2 = async.sync(function(done)
      vim.defer_fn(function()
        done(1, 2)
      end, 100)
    end, 500)
    assert.are.equal(v1, 1)
    assert.are.equal(v2, 2)
  end)

end)

