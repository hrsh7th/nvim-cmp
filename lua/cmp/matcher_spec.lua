local spec = require('cmp.utils.spec')

local matcher = require('cmp.matcher')

describe('matcher', function()
  before_each(spec.before)

  it('match', function()
    ---@type cmp.MatcherOption
    local option = {
      cheap = false,
      prefix_start_offset = 1,
    }
    assert.is.truthy(matcher.match('', 'a', option) >= 1)
    assert.is.truthy(matcher.match('a', 'a', option) >= 1)
    assert.is.truthy(matcher.match('ab', 'a', option) == 0)
    assert.is.truthy(matcher.match('ab', 'ab', option) > matcher.match('ab', 'a_b', option))
    assert.is.truthy(matcher.match('ab', 'a_b_c', option) > matcher.match('ac', 'a_b_c', option))

    assert.is.truthy(matcher.match('bora', 'border-radius', option) >= 1)
    assert.is.truthy(matcher.match('woroff', 'word_offset', option) >= 1)
    assert.is.truthy(matcher.match('call', 'call', option) >= matcher.match('call', 'condition_all', option))
    assert.is.truthy(matcher.match('Buffer', 'Buffer', option) >= matcher.match('Buffer', 'buffer', option))
    assert.is.truthy(matcher.match('fmodify', 'fnamemodify', option) >= 1)
    assert.is.truthy(matcher.match('candlesingle', 'candle#accept#single', option) >= 1)
  end)

  it('debug', function()
    ---@type cmp.MatcherOption
    local option = {
      prefix_start_offset = 1,
      cheap = true,
      debug = true,
    }
    matcher.match('c', 'Console', option)
    matcher.match('cn', 'Console', option)
    matcher.match('cl', 'ConsoleLog', option)
  end)
end)
