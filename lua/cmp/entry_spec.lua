local spec = require'cmp.utils.spec'

local entry = require "cmp.entry"

describe('entry', function()

  before_each(spec.before)

  it('with TextEdit (fix)', function()
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

  it('with TextEdit (fix with whitespace)', function()
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
    assert.are.equal(e:get_offset(), 6)
    assert.are.equal(e:get_vim_item(e:get_offset()).word, '/div')
  end)

  it('without TextEdit (fix)', function()
    local state = spec.state("@.", 1, 3)
    local e = entry.new(state.press('@'), {}, {
      label = '@',
    })
    assert.are.equal(e:get_offset(), 3)
    assert.are.equal(e:get_vim_item(e:get_offset()).word, '@')
  end)

  it('without TextEdit (no fix)', function()
    local state = spec.state("p.p", 1, 4)
    local e = entry.new(state.press('.'), {}, {
      label = 'p',
    })
    assert.are.equal(e:get_offset(), 5)
    assert.are.equal(e:get_vim_item(e:get_offset()).word, 'p')
  end)

end)

