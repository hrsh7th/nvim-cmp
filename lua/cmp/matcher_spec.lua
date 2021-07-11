local spec = require('cmp.utils.spec')

local matcher = require('cmp.matcher')

describe('matcher', function()
  before_each(spec.before)

  it('match', function()
    ---@type cmp.MatcherConfig
    local config = {
      max_word_bound = 100,
      prefix_start_offset = 1,
    }
    assert.is.truthy(matcher.match('', 'a', config) >= 1)
    assert.is.truthy(matcher.match('a', 'a', config) >= 1)
    assert.is.truthy(matcher.match('ab', 'a', config) == 0)
    assert.is.truthy(matcher.match('ab', 'ab', config) > matcher.match('ab', 'a_b', config))
    assert.is.truthy(matcher.match('ab', 'a_b_c', config) > matcher.match('ac', 'a_b_c', config))

    assert.is.truthy(matcher.match('bora', 'border-radius', config) >= 1)
    assert.is.truthy(matcher.match('woroff', 'word_offset', config) >= 1)
    assert.is.truthy(matcher.match('call', 'call', config) >= matcher.match('call', 'condition_all', config))
    assert.is.truthy(matcher.match('Buffer', 'Buffer', config) >= matcher.match('Buffer', 'buffer', config))
    assert.is.truthy(matcher.match('fmodify', 'fnamemodify', config) >= 1)
    assert.is.truthy(matcher.match('candlesingle', 'candle#accept#single', config) >= 1)
  end)
end)
