local spec = require('cmp.utils.spec')
local keymap = require('cmp.utils.keymap')

local feedkeys = require('cmp.utils.feedkeys')

describe('feedkeys', function()
  before_each(spec.before)

  it('dot-repeat', function()
    local reg
    feedkeys.call(keymap.t('iaiueo<Esc>'), 'nx', function()
      reg = vim.fn.getreg('.')
    end)
    assert.are.equal(reg, keymap.t('aiueo'))
  end)

  it('textwidth', function()
    vim.cmd([[setlocal textwidth=6]])
    feedkeys.call(keymap.t('iaiueo '), 'nx')
    feedkeys.call(keymap.t('aaiueoaiueo'), 'nx')
    assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
      'aiueo aiueoaiueo',
    })
  end)

  it('backspace', function()
    vim.cmd([[setlocal backspace=""]])
    feedkeys.call(keymap.t('iaiueo'), 'nx')
    feedkeys.call(keymap.t('a<BS><BS>'), 'nx')
    assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
      'aiu',
    })
  end)

  it('callback error', function()
    feedkeys.call('i', 'n', function()
      error(setmetatable({}, {
        __type = 'failure',
        __tostring = function()
          return 'callback failed'
        end,
      }))
    end)
    -- The notification raises through the flush; it must carry the error's
    -- string form instead of dying inside nvim_echo on a non-string chunk.
    local ok, err = pcall(vim.fn.feedkeys, '', 'x')
    assert.is.falsy(ok)
    local message = tostring(err)
    assert.is.truthy(string.find(message, 'callback failed', 1, true))
    assert.is.falsy(string.find(message, 'Invalid chunk', 1, true))
  end)

  it('testability', function()
    feedkeys.call('i', 'n', function()
      feedkeys.call('', 'n', function()
        feedkeys.call('aiueo', 'in')
      end)
      feedkeys.call('', 'n', function()
        feedkeys.call(keymap.t('<BS><BS><BS><BS><BS>'), 'in')
      end)
      feedkeys.call('', 'n', function()
        feedkeys.call(keymap.t('abcde'), 'in')
      end)
      feedkeys.call('', 'n', function()
        feedkeys.call(keymap.t('<BS><BS><BS><BS><BS>'), 'in')
      end)
      feedkeys.call('', 'n', function()
        feedkeys.call(keymap.t('12345'), 'in')
      end)
    end)
    feedkeys.call('', 'x')
    assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), { '12345' })
  end)
end)
