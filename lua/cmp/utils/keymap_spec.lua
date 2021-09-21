local spec = require('cmp.utils.spec')

local keymap = require('cmp.utils.keymap')

describe('keymap', function()
  before_each(spec.before)

  it('to_keymap', function()
    assert.are.equal(keymap.to_keymap('\n'), '<CR>')
    assert.are.equal(keymap.to_keymap('<CR>'), '<CR>')
    assert.are.equal(keymap.to_keymap('|'), '<Bar>')
  end)

  it('escape', function()
    assert.are.equal(keymap.escape('<C-d>'), '<LT>C-d>')
    assert.are.equal(keymap.escape('<C-d><C-f>'), '<LT>C-d><LT>C-f>')
    assert.are.equal(keymap.escape('<LT>C-d>'), '<LT>C-d>')
  end)

  describe('evacuate', function()
    before_each(spec.before)

    it('expr & register', function()
      vim.api.nvim_buf_set_keymap(0, 'i', '(', [['<C-r>="("<CR>']], {
        expr = true,
        noremap = false,
      })
      local fallback = keymap.evacuate('i', '(')
      vim.api.nvim_feedkeys('i' .. keymap.t(fallback), 'x', true)
      assert.are.same({ '(' }, vim.api.nvim_buf_get_lines(0, 0, -1, true))
    end)

    it('recursive & <Plug> (tpope/vim-endwise)', function()
      vim.api.nvim_buf_set_keymap(0, 'i', '<Plug>(paren-close)', [[)<Left>]], {
        expr = false,
        noremap = true,
      })
      vim.api.nvim_buf_set_keymap(0, 'i', '(', [[(<Plug>(paren-close)]], {
        expr = false,
        noremap = false,
      })
      local fallback = keymap.evacuate('i', '(')
      vim.api.nvim_feedkeys('i' .. keymap.t(fallback), 'x', true)
      assert.are.same({ '()' }, vim.api.nvim_buf_get_lines(0, 0, -1, true))
    end)

    describe('expr & recursive', function()
      before_each(spec.before)

      it('true', function()
        vim.api.nvim_buf_set_keymap(0, 'i', '<Tab>', [[v:true ? '<C-r>="foobar"<CR>' : '<Tab>aiueo']], {
          expr = true,
          noremap = false,
        })
        local fallback = keymap.evacuate('i', '<Tab>')
        vim.api.nvim_feedkeys('i' .. keymap.t(fallback), 'x', true)
        assert.are.same({ 'foobar' }, vim.api.nvim_buf_get_lines(0, 0, -1, true))
      end)
      it('false', function()
        vim.api.nvim_buf_set_keymap(0, 'i', '<Tab>', [[v:false ? '<C-r>="foobar"<CR>' : '<Tab>aiueo']], {
          expr = true,
          noremap = false,
        })
        local fallback = keymap.evacuate('i', '<Tab>')
        vim.api.nvim_feedkeys('i' .. keymap.t(fallback), 'x', true)
        assert.are.same({ '\taiueo' }, vim.api.nvim_buf_get_lines(0, 0, -1, true))
      end)
    end)
  end)
end)
