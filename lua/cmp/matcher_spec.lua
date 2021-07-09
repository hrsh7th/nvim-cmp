local spec = require'cmp.utils.spec'

local matcher = require "cmp.matcher"

describe('matcher', function()

  before_each(spec.before)

  it('match', function()
    assert.are_not.equal(matcher.match('', 'a'), 0)
    assert.are_not.equal(matcher.match('a', 'a'), 0)
    assert.are.equal(matcher.match('ab', 'a'), 0)

    assert.is.truthy(matcher.match('ab', 'ab') > matcher.match('ab', 'a_b'))
    assert.is.truthy(matcher.match('ab', 'a_b_c') > matcher.match('ac', 'a_b_c'))
    assert.is.truthy(matcher.match('abc', 'ab') == 0)
  end)

end)
