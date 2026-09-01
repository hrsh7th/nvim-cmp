local spec = require('cmp.utils.spec')
local api = require('cmp.utils.api')
local feedkeys = require('cmp.utils.feedkeys')

local keymap = require('cmp.utils.keymap')

describe('keymap', function()
  before_each(spec.before)

  it('t', function()
    for _, key in ipairs({
      '<F1>',
      '<C-a>',
      '<C-]>',
      '<C-[>',
      '<C-^>',
      '<C-@>',
      '<C-\\>',
      '<C-;>',
      '<C-,>',
      '<C-:>',
      '<C-.>',
      '<C-/>',
      '<C-_>',
      "<C-'>",
      '<M-`>',
      '<Tab>',
      '<S-Tab>',
      '<Plug>(example)',
      '<C-r>="abc"<CR>',
      '<Cmd>normal! ==<CR>',
    }) do
      assert.are.equal(keymap.t(key), vim.api.nvim_replace_termcodes(key, true, true, true))
      assert.are.equal(keymap.t(key .. key), vim.api.nvim_replace_termcodes(key .. key, true, true, true))
      assert.are.equal(keymap.t(key .. key .. key), vim.api.nvim_replace_termcodes(key .. key .. key, true, true, true))
    end
  end)

  it('to_keymap', function()
    assert.are.equal(keymap.to_keymap('\n'), '<CR>')
    assert.are.equal(keymap.to_keymap('<CR>'), '<CR>')
    assert.are.equal(keymap.to_keymap('|'), '<Bar>')
  end)

  describe('fallback', function()
    before_each(spec.before)

    local run_fallback = function(keys, fallback)
      local state = {}
      feedkeys.call(keys, '', function()
        fallback()
      end)
      feedkeys.call('', '', function()
        if api.is_cmdline_mode() then
          state.buffer = { api.get_current_line() }
        else
          state.buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        end
        state.cursor = api.get_cursor()
      end)
      feedkeys.call('', 'x')
      return state
    end

    describe('basic', function()
      it('<Plug>', function()
        vim.api.nvim_buf_set_keymap(0, 'i', '<Plug>(pairs)', '()<Left>', { noremap = true })
        vim.api.nvim_buf_set_keymap(0, 'i', '(', '<Plug>(pairs)', { noremap = false })
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '('))
        local state = run_fallback('i', fallback)
        assert.are.same({ '()' }, state.buffer)
        assert.are.same({ 1, 1 }, state.cursor)
      end)

      it('<C-r>=', function()
        vim.api.nvim_buf_set_keymap(0, 'i', '(', '<C-r>="()"<CR><Left>', {})
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '('))
        local state = run_fallback('i', fallback)
        assert.are.same({ '()' }, state.buffer)
        assert.are.same({ 1, 1 }, state.cursor)
      end)

      it('#103 <CR>', function()
        vim.cmd('iabbrev <buffer> TODO TODO(jawa)')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<CR>'))
        local state = run_fallback('iTODO', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'TODO(jawa)', '' }, state.buffer)
        assert.are.same({ 2, 0 }, state.cursor)
      end)

      it('#103 <Space>', function()
        vim.cmd('iabbrev <buffer> TODO TODO(jawa)')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<Space>'))
        local state = run_fallback('iTODO', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'TODO(jawa) ' }, state.buffer)
        assert.are.same({ 1, 11 }, state.cursor)
      end)

      it('#103 multi-key fallback expands from its first key', function()
        vim.cmd('iabbrev <buffer> TODO TODO(jawa)')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<Space>x'))
        local state = run_fallback('iTODO', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'TODO(jawa) x' }, state.buffer)
        assert.are.same({ 1, 12 }, state.cursor)
      end)

      it('#103 multi-key fallback expands after a keyword prefix', function()
        vim.cmd('iabbrev <buffer> foo replacement')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', 'o<Space>'))
        local state = run_fallback('ifo', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'replacement ' }, state.buffer)
        assert.are.same({ 1, 12 }, state.cursor)
      end)

      it('#103 multi-key fallback preserves later abbreviation triggers', function()
        vim.cmd('iabbrev <buffer> foo first')
        vim.cmd('iabbrev <buffer> bar second')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', 'o<Space>bar<Space>'))
        local state = run_fallback('ifo', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'first second ' }, state.buffer)
        assert.are.same({ 1, 13 }, state.cursor)
      end)

      it('#103 stops adding expansion keys after leaving Insert mode', function()
        vim.cmd('iabbrev <buffer> TODO TODO(jawa)')
        local expanded
        feedkeys.call('iTODO', '', function()
          expanded = keymap.expand_abbreviations('i', '<Esc><Space>')
        end)
        feedkeys.call('', 'x')
        vim.cmd('iabclear <buffer>')
        assert.are.equal(keymap.t('<C-]><Esc><Space>'), expanded)
      end)

      it('#103 <C-O> expands an abbreviation before its Normal command', function()
        vim.cmd('iabbrev <buffer> foo replacement')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<C-O><Right>'))
        local state = run_fallback('ifoo', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'replacement' }, state.buffer)
      end)

      it('#103 stops adding expansion keys after <C-O>', function()
        vim.cmd('iabbrev <buffer> foo replacement')
        local expanded
        feedkeys.call('ifoo', '', function()
          expanded = keymap.expand_abbreviations('i', '<Space><C-O><Space>')
        end)
        feedkeys.call('', 'x')
        vim.cmd('iabclear <buffer>')
        assert.are.equal(keymap.t('<C-]><Space><C-O><Space>'), expanded)
      end)

      it('#103 control-key aliases trigger abbreviations', function()
        for _, lhs in ipairs({ '<C-I>', '<C-J>', '<C-M>', '<C-[>' }) do
          assert.are.equal(true, keymap.triggers_abbreviation(lhs), lhs)
        end
      end)

      it('#103 printable keypad keys trigger abbreviations', function()
        for _, lhs in ipairs({ '<kPlus>', '<kMinus>', '<kMultiply>', '<kDivide>', '<kPoint>', '<kComma>', '<kEqual>' }) do
          assert.are.equal(true, keymap.triggers_abbreviation(lhs), lhs)
        end
        for _, lhs in ipairs({ '<k0>', '<k1>', '<k2>', '<k3>', '<k4>', '<k5>', '<k6>', '<k7>', '<k8>', '<k9>' }) do
          assert.are.equal(false, keymap.triggers_abbreviation(lhs), lhs)
        end
      end)

      it('#103 printable keypad fallback expands an abbreviation', function()
        vim.cmd('iabbrev <buffer> TODO TODO(jawa)')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<kPlus>'))
        local state = run_fallback('iTODO', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'TODO(jawa)+' }, state.buffer)
        assert.are.same({ 1, 11 }, state.cursor)
      end)

      it('#103 <C-]> expands abbreviation once', function()
        vim.cmd('iabbrev <buffer> a b')
        vim.cmd('iabbrev <buffer> b c')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<C-]>'))
        local state = run_fallback('ia', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'b' }, state.buffer)
        assert.are.same({ 1, 1 }, state.cursor)
      end)

      it('#103 multi-key <C-]> fallback expands abbreviation once', function()
        vim.cmd('iabbrev <buffer> a b')
        vim.cmd('iabbrev <buffer> b c')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<C-]>x'))
        local state = run_fallback('ia', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'bx' }, state.buffer)
        assert.are.same({ 1, 2 }, state.cursor)
      end)

      it('#103 no-op <C-]> preserves a later abbreviation', function()
        vim.cmd('iabbrev <buffer> foo replacement')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<C-]>o<Space>'))
        local state = run_fallback('ifo', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'replacement ' }, state.buffer)
        assert.are.same({ 1, 12 }, state.cursor)
      end)

      it('#103 explicit <C-]> preserves a later abbreviation trigger', function()
        vim.cmd('iabbrev <buffer> a foo')
        vim.cmd('iabbrev <buffer> foo replacement')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<C-]><Space>'))
        local state = run_fallback('ia', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'replacement ' }, state.buffer)
        assert.are.same({ 1, 12 }, state.cursor)
      end)

      it('#103 end-id abbreviation', function()
        vim.cmd('iabbrev <buffer> #i #include')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<CR>'))
        local state = run_fallback('i#i', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ '#include', '' }, state.buffer)
        assert.are.same({ 2, 0 }, state.cursor)
      end)

      it('#103 one-character full-id abbreviation after punctuation is not expanded', function()
        vim.cmd('iabbrev <buffer> x replacement')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<Space>'))
        local state = run_fallback('i(x', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ '(x ' }, state.buffer)
        assert.are.same({ 1, 3 }, state.cursor)
      end)

      it('#103 non-id abbreviation', function()
        vim.cmd('iabbrev <buffer> ;; END')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<CR>'))
        local state = run_fallback('i;;', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'END', '' }, state.buffer)
        assert.are.same({ 2, 0 }, state.cursor)
      end)

      it('#103 non-id abbreviation after keyword is not expanded', function()
        vim.cmd('iabbrev <buffer> ;; END')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<Space>'))
        local state = run_fallback('ifoo;;', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'foo;; ' }, state.buffer)
        assert.are.same({ 1, 6 }, state.cursor)
      end)

      it('#103 unrelated abbreviation', function()
        vim.cmd('iabbrev <buffer> OTHER other')
        local solved
        feedkeys.call('iTODO', '', function()
          solved = keymap.solve(0, 'i', keymap.get_map('i', '<CR>'))
        end)
        feedkeys.call('', 'x')
        vim.cmd('iabclear <buffer>')
        assert.are.same({ keys = keymap.t('<CR>'), mode = 'in' }, solved)
      end)

      it('#103 <C-e> does not trigger abbreviation', function()
        vim.cmd('iabbrev <buffer> TODO TODO(jawa)')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<C-e>'))
        local state = run_fallback('iTODO', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'TODO' }, state.buffer)
        assert.are.same({ 1, 4 }, state.cursor)
      end)

      it('#103 <BS> does not trigger abbreviation', function()
        vim.cmd('iabbrev <buffer> TODO TODO(jawa)')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<BS>'))
        local state = run_fallback('iTODO', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'TOD' }, state.buffer)
        assert.are.same({ 1, 3 }, state.cursor)
      end)

      it('#103 captures abbreviation state before a delayed fallback', function()
        vim.cmd('iabbrev <buffer> NEW expanded')
        keymap.listen('i', '<Space>', function(_, fallback)
          vim.api.nvim_set_current_line('NEW')
          vim.api.nvim_win_set_cursor(0, { 1, 3 })
          fallback()
        end)
        vim.api.nvim_feedkeys(keymap.t('iword<Space>'), 'tx', true)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'NEW ' }, vim.api.nvim_buf_get_lines(0, 0, -1, true))
      end)

      it('#103 expands abbreviations in Replace mode', function()
        vim.cmd('iabbrev <buffer> TODO TODO(jawa)')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<Space>'))
        local state = run_fallback('RTODO', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'TODO(jawa) ' }, state.buffer)
        assert.are.same({ 1, 11 }, state.cursor)
      end)

      it('#103 expands abbreviations in Virtual Replace mode', function()
        vim.cmd('iabbrev <buffer> TODO TODO(jawa)')
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '<Space>'))
        local state = run_fallback('gRTODO', fallback)
        vim.cmd('iabclear <buffer>')
        assert.are.same({ 'TODO(jawa) ' }, state.buffer)
        assert.are.same({ 1, 11 }, state.cursor)
      end)

      it('callback', function()
        vim.api.nvim_buf_set_keymap(0, 'i', '(', '', {
          callback = function()
            vim.api.nvim_feedkeys('()' .. keymap.t('<Left>'), 'int', true)
          end,
        })
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '('))
        local state = run_fallback('i', fallback)
        assert.are.same({ '()' }, state.buffer)
        assert.are.same({ 1, 1 }, state.cursor)
      end)

      it('expr-callback', function()
        vim.api.nvim_buf_set_keymap(0, 'i', '(', '', {
          expr = true,
          noremap = false,
          silent = true,
          callback = function()
            return '()' .. keymap.t('<Left>')
          end,
        })
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '('))
        local state = run_fallback('i', fallback)
        assert.are.same({ '()' }, state.buffer)
        assert.are.same({ 1, 1 }, state.cursor)
      end)

      -- it('cmdline default <Tab>', function()
      --   local fallback = keymap.fallback(0, 'c', keymap.get_map('c', '<Tab>'))
      --   local state = run_fallback(':', fallback)
      --   assert.are.same({ '' }, state.buffer)
      --   assert.are.same({ 1, 0 }, state.cursor)
      -- end)
    end)

    describe('recursive', function()
      it('non-expr', function()
        vim.api.nvim_buf_set_keymap(0, 'i', '(', '()<Left>', {
          expr = false,
          noremap = false,
          silent = true,
        })
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '('))
        local state = run_fallback('i', fallback)
        assert.are.same({ '()' }, state.buffer)
        assert.are.same({ 1, 1 }, state.cursor)
      end)

      it('expr', function()
        vim.api.nvim_buf_set_keymap(0, 'i', '(', '"()<Left>"', {
          expr = true,
          noremap = false,
          silent = true,
        })
        local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '('))
        local state = run_fallback('i', fallback)
        assert.are.same({ '()' }, state.buffer)
        assert.are.same({ 1, 1 }, state.cursor)
      end)

      it('expr-callback', function()
        pcall(function()
          vim.api.nvim_buf_set_keymap(0, 'i', '(', '', {
            expr = true,
            noremap = false,
            silent = true,
            callback = function()
              return keymap.t('()<Left>')
            end,
          })
          local fallback = keymap.fallback(0, 'i', keymap.get_map('i', '('))
          local state = run_fallback('i', fallback)
          assert.are.same({ '()' }, state.buffer)
          assert.are.same({ 1, 1 }, state.cursor)
        end)
      end)
    end)
  end)

  describe('realworld', function()
    before_each(spec.before)

    it('#226', function()
      keymap.listen('i', '<c-n>', function(_, fallback)
        fallback()
      end)
      vim.api.nvim_feedkeys(keymap.t('iaiueo<CR>a<C-n><C-n>'), 'tx', true)
      assert.are.same({ 'aiueo', 'aiueo' }, vim.api.nvim_buf_get_lines(0, 0, -1, true))
    end)

    it('#414', function()
      keymap.listen('i', '<M-j>', function()
        vim.api.nvim_feedkeys(keymap.t('<C-n>'), 'int', true)
      end)
      vim.api.nvim_feedkeys(keymap.t('iaiueo<CR>a<M-j><M-j>'), 'tx', true)
      assert.are.same({ 'aiueo', 'aiueo' }, vim.api.nvim_buf_get_lines(0, 0, -1, true))
    end)

    it('#744', function()
      vim.api.nvim_buf_set_keymap(0, 'i', '<C-r>', 'recursive', {
        noremap = true,
      })
      vim.api.nvim_buf_set_keymap(0, 'i', '<CR>', '<CR>recursive', {
        noremap = false,
      })
      keymap.listen('i', '<CR>', function(_, fallback)
        fallback()
      end)
      feedkeys.call(keymap.t('i<CR>'), 'tx')
      assert.are.same({ '', 'recursive' }, vim.api.nvim_buf_get_lines(0, 0, -1, true))
    end)
  end)
end)
