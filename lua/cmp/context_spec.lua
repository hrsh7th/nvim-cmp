local spec = require'cmp.utils.spec'

local context = require "cmp.context"

describe('context', function()

  before_each(spec.before)

  it('create', function()
    vim.fn.setline('1', 'function! s:name() abort')
    vim.bo.filetype = 'vim'
    vim.fn.execute('normal! 1G15|')
    local ctx = context.new()
    assert.are.equal(ctx.filetype, 'vim')
    assert.are.equal(ctx.cursor.row, 1)
    assert.are.equal(ctx.cursor.col, 15)
    assert.are.equal(ctx.cursor_line, 'function! s:name() abort')
    assert.are.equal(ctx.offset, 13)
    assert.are.equal(ctx.offset_before_line, 'function! s:')
    assert.are.equal(ctx.input, 'na')
    assert.are.equal(ctx.insert_range.start.col, 13)
    assert.are.equal(ctx.insert_range['end'].col, 15)
    assert.are.equal(ctx.replace_range.start.col, 13)
    assert.are.equal(ctx.replace_range['end'].col, 17)
  end)

end)

