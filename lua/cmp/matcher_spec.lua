local spec = require('cmp.utils.spec')

local matcher = require('cmp.matcher')

describe('matcher', function()
  before_each(spec.before)

  it('match', function()
    assert.is.truthy(matcher.match('', 'a') >= 1)
    assert.is.truthy(matcher.match('a', 'a') >= 1)
    assert.is.truthy(matcher.match('ab', 'a') == 0)
    assert.is.truthy(matcher.match('ab', 'ab') > matcher.match('ab', 'a_b'))
    assert.is.truthy(matcher.match('ab', 'a_b_c') > matcher.match('ac', 'a_b_c'))

    assert.is.truthy(matcher.match('bora', 'border-radius') >= 1)
    assert.is.truthy(matcher.match('woroff', 'word_offset') >= 1)
    assert.is.truthy(matcher.match('call', 'call') >= matcher.match('call', 'condition_all'))
    assert.is.truthy(matcher.match('Buffer', 'Buffer') >= matcher.match('Buffer', 'buffer'))
    assert.is.truthy(matcher.match('fmodify', 'fnamemodify') >= 1)
    assert.is.truthy(matcher.match('candlesingle', 'candle#accept#single') >= 1)
  end)
end)
