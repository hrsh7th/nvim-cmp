local spec = require('cmp.utils.spec')

local matcher = require('cmp.matcher')

describe('matcher', function()
  before_each(spec.before)

  it('match', function()
    assert.are_not.equal(matcher.match('', 'a', 1), 0)
    assert.are_not.equal(matcher.match('a', 'a', 1), 0)
    assert.are.equal(matcher.match('ab', 'a', 1), 0)

    assert.is.truthy(matcher.match('ab', 'ab', 1) > matcher.match('ab', 'a_b', 1))
    assert.is.truthy(matcher.match('ab', 'a_b_c', 1) > matcher.match('ac', 'a_b_c', 1))
    assert.is.truthy(matcher.match('abc', 'ab', 1) == 0)
  end)
end)
