local spec = require('cmp.utils.spec')
local config = require('cmp.config')
local entry = require('cmp.entry')
local custom_entries_view = require('cmp.view.custom_entries_view')

describe('custom_entries_view', function()
  local columns

  before_each(function()
    spec.before()
    columns = vim.o.columns
  end)

  after_each(function()
    vim.o.columns = columns
  end)

  local open = function(label, indent)
    indent = indent or 0
    local state = spec.state(string.rep(' ', indent), 1, indent + 1)
    state.input('a')
    local view = custom_entries_view.new()
    view:open(indent + 1, {
      entry.new(state.manual(), state.source(), {
        label = label,
      }),
    })
    return view
  end

  it('clamps a menu wider than the editor', function()
    vim.o.columns = 40
    local view = open(string.rep('a', 60))
    local info = view:info()
    assert.is_true(info.col + info.width <= vim.o.columns)
    view:close()
  end)

  it('keeps a menu that overflows from the left half inside the editor', function()
    vim.o.columns = 80
    local view = open(string.rep('a', 65), 20)
    local info = view:info()
    assert.is_true(info.col + info.width <= vim.o.columns)
    view:close()
  end)

  it('checks the fit at the column shifted by col_offset', function()
    vim.o.columns = 80
    config.set_global({ window = { completion = { col_offset = -10 } } })
    local view = open(string.rep('a', 65), 20)
    local info = view:info()
    -- Only moved as far left as needed to fit, not col_offset further.
    assert.are.equal(vim.o.columns - 1, info.col + info.width)
    view:close()
  end)

  it('does not move the menu when it fits', function()
    vim.o.columns = 80
    local view = open('abc')
    assert.are.equal(0, view:info().col)
    view:close()
  end)
end)
