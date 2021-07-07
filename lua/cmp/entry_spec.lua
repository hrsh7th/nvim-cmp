local spec = require'cmp.utils.spec'

local entry = require "cmp.entry"

describe('entry', function()

  before_each(spec.before)

  describe('with TextEdit', function()
    it('basic', function()
      local state = spec.state("local entry = require'cmp", 1, 26)
      local e = entry.new(state.press('.'), {}, {
        label = 'cmp.module',
        textEdit = {
          range = {
            start = {
              line = 0,
              character = 22,
            },
            ['end'] = {
              line = 0,
              character = 26,
            }
          },
          newText = 'cmp.module',
        }
      })
      assert.are.equal(e:get_offset(), 23)
      assert.are.equal(e:get_vim_item(e:get_offset()).word, 'cmp.module')
    end)

    it('leading whitespace', function()
      local state = spec.state("    </>", 1, 7)
      local e = entry.new(state.press('.'), {}, {
        label = '/div',
        textEdit = {
          range = {
            start = {
              line = 0,
              character = 0,
            },
            ['end'] = {
              line = 0,
              character = 7,
            }
          },
          newText = '  </div'
        }
      })
      assert.are.equal(e:get_offset(), 5)
      assert.are.equal(e:get_vim_item(e:get_offset()).word, '</div')
    end)

    it('[clangd] 1', function()
      local state = spec.state("foo", 1, 4)
      local e = entry.new(state.press('.'), {}, {
        insertText = "->foo",
        label = " foo",
        textEdit = {
          newText = "->foo",
          range = {
            start = {
              character = 3,
              line = 1
            },
            ['end'] = {
              character = 4,
              line = 1
            },
          }
        }
      })
      assert.are.equal(e:get_vim_item(4).word, '->foo')
      assert.are.equal(e:get_filter_text(4), '.foo')
    end)

    it('[typescript-language-server] 1', function()
      local state = spec.state("Promise.resolve()", 1, 18)
      local e = entry.new(state.press('.'), {}, {
        label = "catch",
      })
      -- The offset will be 18 in this situation because the server returns `[Symbol]` as candidate.
      assert.are.equal(e:get_vim_item(18).word, '.catch')
      assert.are.equal(e:get_filter_text(18), '.catch')
    end)

    it('[typescript-language-server] 2', function()
      local state = spec.state("Promise.resolve()", 1, 18)
      local e = entry.new(state.press('.'), {}, {
        filterText = ".Symbol",
        label = "Symbol",
        textEdit = {
          newText = "[Symbol]",
          range = {
            ['end'] = {
              character = 18,
              line = 0
            },
            start = {
              character = 17,
              line = 0
            }
          }
        }
      })
      assert.are.equal(e:get_vim_item(18).word, '[Symbol]')
      assert.are.equal(e:get_filter_text(18), '.Symbol')
    end)
  end)

  describe('without TextEdit', function()
    it('fix symbol chars', function()
      local state = spec.state("@.", 1, 3)
      local e = entry.new(state.press('@'), {}, {
        label = '@',
      })
      assert.are.equal(e:get_offset(), 3)
      assert.are.equal(e:get_vim_item(e:get_offset()).word, '@')
    end)

    it('fix until word length', function()
      local state = spec.state("p.p", 1, 4)
      local e = entry.new(state.press('.'), {}, {
        label = 'p',
      })
      assert.are.equal(e:get_offset(), 5)
      assert.are.equal(e:get_vim_item(e:get_offset()).word, 'p')
    end)

    it('fix until word length (nofix)', function()
      local state = spec.state("p.p", 1, 4)
      local e = entry.new(state.press('.'), {}, {
        label = 'p',
      })
      assert.are.equal(e:get_offset(), 5)
      assert.are.equal(e:get_vim_item(e:get_offset()).word, 'p')
    end)

    it('fix until word length (fix)', function()
      local state = spec.state("p.p", 1, 4)
      local e = entry.new(state.press('.'), {}, {
        label = 'p.',
      })
      assert.are.equal(e:get_offset(), 3)
      assert.are.equal(e:get_vim_item(e:get_offset()).word, 'p.')
    end)
  end)

end)

