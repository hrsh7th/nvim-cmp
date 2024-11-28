local spec = require('cmp.utils.spec')
local default_config = require('cmp.config.default')

local matcher = require('cmp.matcher')

describe('matcher', function()
  before_each(spec.before)

  it('match', function()
    local config = default_config()
    assert.is.truthy(matcher.match('', 'a', config.matching) >= 1)
    assert.is.truthy(matcher.match('a', 'a', config.matching) >= 1)
    assert.is.truthy(matcher.match('ab', 'a', config.matching) == 0)
    assert.is.truthy(matcher.match('ab', 'ab', config.matching) > matcher.match('ab', 'a_b', config.matching))
    assert.is.truthy(matcher.match('ab', 'a_b_c', config.matching) > matcher.match('ac', 'a_b_c', config.matching))

    assert.is.truthy(matcher.match('bora', 'border-radius', config.matching) >= 1)
    assert.is.truthy(matcher.match('woroff', 'word_offset', config.matching) >= 1)
    assert.is.truthy(matcher.match('call', 'call', config.matching) > matcher.match('call', 'condition_all', config.matching))
    assert.is.truthy(matcher.match('Buffer', 'Buffer', config.matching) > matcher.match('Buffer', 'buffer', config.matching))
    assert.is.truthy(matcher.match('luacon', 'lua_context', config.matching) > matcher.match('luacon', 'LuaContext', config.matching))
    assert.is.truthy(matcher.match('fmodify', 'fnamemodify', config.matching) >= 1)
    assert.is.truthy(matcher.match('candlesingle', 'candle#accept#single', config.matching) >= 1)

    local options = {
      keyword_pattern = [[ \w\+ ]],
    }
    assert.is.truthy(matcher.match('ab', 'a_b_c', options) > matcher.match('ac', 'a_b_c', options))
    assert.is.truthy(matcher.match('a_b', 'a_b_c', options) > matcher.match('ab', 'a_b_c', options))
    assert.is.truthy(matcher.match('a_b/c', 'a_b/c', options) > matcher.match('a/c', 'a_b/c', options))

    assert.is.truthy(matcher.match('bora', 'border-radius') >= 1)
    assert.is.truthy(matcher.match('woroff', 'word_offset') >= 1)
    assert.is.truthy(matcher.match('call', 'call') > matcher.match('call', 'condition_all'))
    assert.is.truthy(matcher.match('Buffer', 'Buffer') > matcher.match('Buffer', 'buffer'))
    assert.is.truthy(matcher.match('luacon', 'lua_context') > matcher.match('luacon', 'LuaContext'))
    assert.is.truthy(matcher.match('fmodify', 'fnamemodify') >= 1)
    assert.is.truthy(matcher.match('candlesingle', 'candle#accept#single') >= 1)

    assert.is.truthy(matcher.match('vi', 'void#', config.matching) >= 1)
    assert.is.truthy(matcher.match('vo', 'void#', config.matching) >= 1)
    assert.is.truthy(matcher.match('var_', 'var_dump', config.matching) >= 1)
    assert.is.truthy(matcher.match('conso', 'console', config.matching) > matcher.match('conso', 'ConstantSourceNode', config.matching))
    assert.is.truthy(matcher.match('usela', 'useLayoutEffect', config.matching) > matcher.match('usela', 'useDataLayer', config.matching))
    assert.is.truthy(matcher.match('my_', 'my_awesome_variable', config.matching) > matcher.match('my_', 'completion_matching_strategy_list', config.matching))
    assert.is.truthy(matcher.match('2', '[[2021', config.matching) >= 1)

    assert.is.truthy(matcher.match(',', 'pri,', config.matching) == 0)
    assert.is.truthy(matcher.match('/', '/**', config.matching) >= 1)

    assert.is.truthy(matcher.match('true', 'v:true', { synonyms = { 'true' } }, config.matching) == matcher.match('true', 'true', config.matching))
    assert.is.truthy(matcher.match('g', 'get', { synonyms = { 'get' } }, config.matching) > matcher.match('g', 'dein#get', { 'dein#get' }, config.matching))

    assert.is.truthy(matcher.match('Unit', 'net.UnixListener', { disallow_partial_fuzzy_matching = true }, config.matching) == 0)
    assert.is.truthy(matcher.match('Unit', 'net.UnixListener', { disallow_partial_fuzzy_matching = false }, config.matching) >= 1)

    assert.is.truthy(matcher.match('emg', 'error_msg', config.matching) >= 1)
    assert.is.truthy(matcher.match('sasr', 'saved_splitright', config.matching) >= 1)

    -- TODO: #1420 test-case
    -- assert.is.truthy(matcher.match('asset_', '????') >= 0)

    local score, matches
    score, matches = matcher.match('tail', 'HCDetails', {
      disallow_fuzzy_matching = false,
      disallow_partial_matching = false,
      disallow_prefix_unmatching = false,
      disallow_partial_fuzzy_matching = false,
      disallow_symbol_nonprefix_matching = true,
    })
    assert.is.truthy(score >= 1)
    assert.equals(matches[1].word_match_start, 5)

    score = matcher.match('tail', 'HCDetails', {
      disallow_fuzzy_matching = false,
      disallow_partial_matching = false,
      disallow_prefix_unmatching = false,
      disallow_partial_fuzzy_matching = true,
      disallow_symbol_nonprefix_matching = true,
    })
    assert.is.truthy(score == 0)
  end)

  it('disallow_fuzzy_matching', function()
    assert.is.truthy(matcher.match('fmodify', 'fnamemodify', { disallow_fuzzy_matching = true }) == 0)
    assert.is.truthy(matcher.match('fmodify', 'fnamemodify', { disallow_fuzzy_matching = false }) >= 1)
  end)

  it('disallow_fullfuzzy_matching', function()
    assert.is.truthy(matcher.match('svd', 'saved_splitright', { disallow_fullfuzzy_matching = true }) == 0)
    assert.is.truthy(matcher.match('svd', 'saved_splitright', { disallow_fullfuzzy_matching = false }) >= 1)
  end)

  it('disallow_partial_matching', function()
    assert.is.truthy(matcher.match('fb', 'foo_bar', { disallow_partial_matching = true }) == 0)
    assert.is.truthy(matcher.match('fb', 'foo_bar', { disallow_partial_matching = false }) >= 1)
    assert.is.truthy(matcher.match('fb', 'fboo_bar', { disallow_partial_matching = true }) >= 1)
    assert.is.truthy(matcher.match('fb', 'fboo_bar', { disallow_partial_matching = false }) >= 1)
  end)

  it('disallow_prefix_unmatching', function()
    assert.is.truthy(matcher.match('bar', 'foo_bar', { disallow_prefix_unmatching = true }) == 0)
    assert.is.truthy(matcher.match('bar', 'foo_bar', { disallow_prefix_unmatching = false }) >= 1)
  end)

  it('disallow_symbol_nonprefix_matching', function()
    assert.is.truthy(matcher.match('foo_', 'b foo_bar', { disallow_symbol_nonprefix_matching = true }) == 0)
    assert.is.truthy(matcher.match('foo_', 'b foo_bar', { disallow_symbol_nonprefix_matching = false }) >= 1)
  end)

  it('debug', function()
    matcher.debug = function(...)
      print(vim.inspect({ ... }))
    end
    -- print(vim.inspect({
    --   a = matcher.match('true', 'v:true', { 'true' }),
    --   b = matcher.match('true', 'true'),
    -- }))
  end)
end)
