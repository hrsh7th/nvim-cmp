local spec = require('cmp.utils.spec')
local feedkeys = require('cmp.utils.feedkeys')
local types = require('cmp.types')
local core = require('cmp.core')
local source = require('cmp.source')
local keymap = require('cmp.utils.keymap')

describe('cmp.core', function()

  describe('confirm #confirm', function()
    before_each(spec.before)

    local confirm = function(request, filter, completion_item)
      local c = core.new()
      local s = source.new('spec', {
        complete = function(_, _, callback)
          callback({ completion_item })
        end
      })
      c:register_source(s)
      feedkeys.call(request, 'n', function()
        c:complete(c:get_context({ reason = types.cmp.ContextReason.Manual }))
        vim.wait(5000, function() return #c.sources[s.id].entries > 0 end)
      end)
      feedkeys.call(filter, 'n', function()
        c:confirm(c.sources[s.id].entries[1], {})
      end)
      local state = {}
      feedkeys.call('', 'x', function()
        feedkeys.call('', 'n', function()
          state.buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
          state.cursor = vim.api.nvim_win_get_cursor(0)
        end)
      end)
      return state
    end

    it('label only', function()
      local state = confirm('iA', 'IU', {
        label = 'AIUEO'
      })
      assert.are.same(state.buffer, { 'AIUEO' })
      assert.are.same(state.cursor, { 1, 5 })
    end)

    it('text edit', function()
      local state = confirm(keymap.t('i***AEO***<Left><Left><Left><Left><Left>'), 'IU', {
        label = 'AIUEO',
        textEdit = {
          range = {
            start = {
              line = 0,
              character = 3,
            },
            ['end'] = {
              line = 0,
              character = 6
            }
          },
          newText = 'foo\nbar\nbaz'
        },
      })
      assert.are.same(state.buffer, { '***foo', 'bar', 'baz***' })
      assert.are.same(state.cursor, { 3, 3 })
    end)

    it('snippet', function()
      local state = confirm('iA', 'IU', {
        label = 'AIUEO',
        insertText = 'AIUEO($0)',
        insertTextFormat = types.lsp.InsertTextFormat.Snippet,
      })
      assert.are.same(state.buffer, { 'AIUEO()' })
      assert.are.same(state.cursor, { 1, 6 })
    end)

  end)

end)
