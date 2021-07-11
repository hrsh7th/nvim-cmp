local spec = require('cmp.utils.spec')

local matcher = require('cmp.matcher')

describe('matcher', function()
  before_each(spec.before)

  it('match', function()
    assert.is.truthy(matcher.match('', 'a', 1) >= 1)
    assert.is.truthy(matcher.match('a', 'a', 1) >= 1)
    assert.is.truthy(matcher.match('ab', 'a', 1) == 0)
    assert.is.truthy(matcher.match('ab', 'ab', 1) > matcher.match('ab', 'a_b', 1))
    assert.is.truthy(matcher.match('ab', 'a_b_c', 1) > matcher.match('ac', 'a_b_c', 1))

    assert.is.truthy(matcher.match('bora', 'border-radius', 1) >= 1)
    assert.is.truthy(matcher.match('woroff', 'word_offset', 1) >= 1)
    assert.is.truthy(matcher.match('call', 'call', 1) >= matcher.match('call', 'condition_all', 1))
    assert.is.truthy(matcher.match('Buffer', 'Buffer', 1) >= matcher.match('Buffer', 'buffer', 1))
    assert.is.truthy(matcher.match('fmodify', 'fnamemodify', 1) >= 1)
    assert.is.truthy(matcher.match('candlesingle', 'candle#accept#single', 1) >= 1)
  end)
end)
