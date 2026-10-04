local compare = require('cmp.config.compare')

describe('compare', function()
  describe('sort_text', function()
    local entry = function(sortText, label)
      return { completion_item = { sortText = sortText, label = label } }
    end

    it('compares sortText when both entries have it', function()
      assert.is.truthy(compare.sort_text(entry('a', 'z'), entry('b', 'a')))
      assert.is.falsy(compare.sort_text(entry('b', 'a'), entry('a', 'z')))
    end)

    it('returns nil when sortText is equal', function()
      assert.is.truthy(compare.sort_text(entry('a', 'x'), entry('a', 'y')) == nil)
    end)

    it('falls back to the label when sortText is missing', function()
      assert.is.truthy(compare.sort_text(entry(nil, 'a'), entry(nil, 'b')))
      assert.is.falsy(compare.sort_text(entry(nil, 'b'), entry(nil, 'a')))
      assert.is.truthy(compare.sort_text(entry(nil, 'a'), entry(nil, 'a')) == nil)
    end)

    it('falls back to the label when only one entry has sortText', function()
      assert.is.truthy(compare.sort_text(entry('z', 'a'), entry(nil, 'b')))
      assert.is.falsy(compare.sort_text(entry('z', 'b'), entry(nil, 'a')))
    end)
  end)
end)
