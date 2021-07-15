local spec = require('cmp.utils.spec')

local entry = require('cmp.entry')

describe('entry', function()
  before_each(spec.before)

  it('one char', function()
    local state = spec.state('@.', 1, 3)
    local e = entry.new(state.press('@'), {}, {
      label = '@',
    })
    assert.are.equal(e:get_offset(), 3)
    assert.are.equal(e:get_vim_item(e:get_offset()).word, '@')
  end)

  it('word length (no fix)', function()
    local state = spec.state('a.b', 1, 4)
    local e = entry.new(state.press('.'), {}, {
      label = 'b',
    })
    assert.are.equal(e:get_offset(), 5)
    assert.are.equal(e:get_vim_item(e:get_offset()).word, 'b')
  end)

  it('word length (fix)', function()
    local state = spec.state('a.b', 1, 4)
    local e = entry.new(state.press('.'), {}, {
      label = 'b.',
    })
    assert.are.equal(e:get_offset(), 3)
    assert.are.equal(e:get_vim_item(e:get_offset()).word, 'b.')
  end)

  it('semantic index (no fix)', function()
    local state = spec.state('a.bc', 1, 5)
    local e = entry.new(state.press('.'), {}, {
      label = 'c.',
    })
    assert.are.equal(e:get_offset(), 6)
    assert.are.equal(e:get_vim_item(e:get_offset()).word, 'c.')
  end)

  it('semantic index (fix)', function()
    local state = spec.state('a.bc', 1, 5)
    local e = entry.new(state.press('.'), {}, {
      label = 'bc.',
    })
    assert.are.equal(e:get_offset(), 3)
    assert.are.equal(e:get_vim_item(e:get_offset()).word, 'bc.')
  end)

  it('[vscode-html-language-server] 1', function()
    local state = spec.state('    </>', 1, 7)
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
            character = 6,
          },
        },
        newText = '  </div',
      },
    })
    assert.are.equal(e:get_offset(), 5)
    assert.are.equal(e:get_vim_item(e:get_offset()).word, '</div')
  end)

  it('[clangd] 1', function()
    --NOTE: clangd does not return `.foo` as filterText but we should care about it.
    --nvim-cmp does care it by special handling in entry.lua.
    local state = spec.state('foo', 1, 4)
    local e = entry.new(state.press('.'), {}, {
      insertText = '->foo',
      label = ' foo',
      textEdit = {
        newText = '->foo',
        range = {
          start = {
            character = 3,
            line = 1,
          },
          ['end'] = {
            character = 4,
            line = 1,
          },
        },
      },
    })
    assert.are.equal(e:get_vim_item(4).word, '->foo')
    assert.are.equal(e:get_filter_text(), '.foo')
  end)

  it('[typescript-language-server] 1', function()
    local state = spec.state('Promise.resolve()', 1, 18)
    local e = entry.new(state.press('.'), {}, {
      label = 'catch',
    })
    -- The offset will be 18 in this situation because the server returns `[Symbol]` as candidate.
    assert.are.equal(e:get_vim_item(18).word, '.catch')
    assert.are.equal(e:get_filter_text(), 'catch')
  end)

  it('[typescript-language-server] 2', function()
    local state = spec.state('Promise.resolve()', 1, 18)
    local e = entry.new(state.press('.'), {}, {
      filterText = '.Symbol',
      label = 'Symbol',
      textEdit = {
        newText = '[Symbol]',
        range = {
          ['end'] = {
            character = 18,
            line = 0,
          },
          start = {
            character = 17,
            line = 0,
          },
        },
      },
    })
    assert.are.equal(e:get_vim_item(18).word, '[Symbol]')
    assert.are.equal(e:get_filter_text(), '.Symbol')
  end)

  it('[lua-language-server] 1', function()
    local state = spec.state("local m = require'cmp.confi", 1, 28)
    local e

    -- press g
    e = entry.new(state.press('g'), {}, {
      insertTextFormat = 2,
      label = 'cmp.config',
      textEdit = {
        newText = 'cmp.config',
        range = {
          ['end'] = {
            character = 27,
            line = 1,
          },
          start = {
            character = 18,
            line = 1,
          },
        },
      },
    })
    assert.are.equal(e:get_vim_item(19).word, 'cmp.config')
    assert.are.equal(e:get_filter_text(), 'cmp.config')

    -- press '
    e = entry.new(state.press("'"), {}, {
      insertTextFormat = 2,
      label = 'cmp.config',
      textEdit = {
        newText = 'cmp.config',
        range = {
          ['end'] = {
            character = 27,
            line = 1,
          },
          start = {
            character = 18,
            line = 1,
          },
        },
      },
    })
    assert.are.equal(e:get_vim_item(19).word, 'cmp.config')
    assert.are.equal(e:get_filter_text(), 'cmp.config')
  end)

  it('[lua-language-server] 2', function()
    local state = spec.state("local m = require'cmp.confi", 1, 28)
    local e

    -- press g
    e = entry.new(state.press('g'), {}, {
      insertTextFormat = 2,
      label = 'lua.cmp.config',
      textEdit = {
        newText = 'lua.cmp.config',
        range = {
          ['end'] = {
            character = 27,
            line = 1,
          },
          start = {
            character = 18,
            line = 1,
          },
        },
      },
    })
    assert.are.equal(e:get_vim_item(19).word, 'lua.cmp.config')
    assert.are.equal(e:get_filter_text(), 'lua.cmp.config')

    -- press '
    e = entry.new(state.press("'"), {}, {
      insertTextFormat = 2,
      label = 'lua.cmp.config',
      textEdit = {
        newText = 'lua.cmp.config',
        range = {
          ['end'] = {
            character = 27,
            line = 1,
          },
          start = {
            character = 18,
            line = 1,
          },
        },
      },
    })
    assert.are.equal(e:get_vim_item(19).word, 'lua.cmp.config')
    assert.are.equal(e:get_filter_text(), 'lua.cmp.config')
  end)

  it('[intelephense] 1', function()
    local state = spec.state('\t\t', 1, 4)
    local e

    -- press g
    e = entry.new(state.press('$'), {}, {
      detail = '\\Nico_URLConf',
      kind = 6,
      label = '$this',
      sortText = '$this',
      textEdit = {
        newText = '$this',
        range = {
          ['end'] = {
            character = 3,
            line = 1,
          },
          start = {
            character = 2,
            line = 1,
          },
        },
      },
    })
    assert.are.equal(e:get_vim_item(e:get_offset()).word, '$this')
    assert.are.equal(e:get_filter_text(), '$this')
  end)
end)
