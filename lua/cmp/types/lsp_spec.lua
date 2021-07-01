local spec = require'cmp.utils.spec'
local lsp = require'cmp.types.lsp'

describe('types.lsp', function ()
  before_each(spec.before)
  describe('Position', function ()
    vim.fn.setline('1', {
      'あいうえお',
      'かきくけこ',
      'さしすせそ',
    })
    local vim_position = lsp.Position.to_vim('%', {
      line = 1,
      character = 3,
    })
    assert.are.equal(vim_position.row, 2)
    assert.are.equal(vim_position.col, 10)

    local lsp_position = lsp.Position.from_vim('%', vim_position)
    assert.are.equal(lsp_position.line, 1)
    assert.are.equal(lsp_position.character, 3)
  end)
end)

