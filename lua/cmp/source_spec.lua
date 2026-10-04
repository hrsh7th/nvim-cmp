local config = require('cmp.config')
local spec = require('cmp.utils.spec')
local types = require('cmp.types')
local async = require('cmp.utils.async')

local source = require('cmp.source')

describe('source', function()
  before_each(spec.before)

  describe('keyword length', function()
    it('not enough', function()
      config.set_buffer({
        completion = {
          keyword_length = 3,
        },
      }, vim.api.nvim_get_current_buf())

      local state = spec.state('', 1, 1)
      local s = source.new('spec', {
        complete = function(_, _, callback)
          callback({ { label = 'spec' } })
        end,
      })
      assert.is.truthy(not s:complete(state.input('a'), function() end))
    end)

    it('enough', function()
      config.set_buffer({
        completion = {
          keyword_length = 3,
        },
      }, vim.api.nvim_get_current_buf())

      local state = spec.state('', 1, 1)
      local s = source.new('spec', {
        complete = function(_, _, callback)
          callback({ { label = 'spec' } })
        end,
      })
      assert.is.truthy(s:complete(state.input('aiu'), function() end))
    end)

    it('enough -> not enough', function()
      config.set_buffer({
        completion = {
          keyword_length = 3,
        },
      }, vim.api.nvim_get_current_buf())

      local state = spec.state('', 1, 1)
      local s = source.new('spec', {
        complete = function(_, _, callback)
          callback({ { label = 'spec' } })
        end,
      })
      assert.is.truthy(s:complete(state.input('aiu'), function() end))
      assert.is.truthy(not s:complete(state.backspace(), function() end))
    end)

    it('continue', function()
      config.set_buffer({
        completion = {
          keyword_length = 3,
        },
      }, vim.api.nvim_get_current_buf())

      local state = spec.state('', 1, 1)
      local s = source.new('spec', {
        complete = function(_, _, callback)
          callback({ { label = 'spec' } })
        end,
      })
      assert.is.truthy(s:complete(state.input('aiu'), function() end))
      assert.is.truthy(not s:complete(state.input('eo'), function() end))
    end)
  end)

  describe('isIncomplete', function()
    it('isIncomplete=true', function()
      local state = spec.state('', 1, 1)
      local s = source.new('spec', {
        complete = function(_, _, callback)
          callback({
            items = { { label = 'spec' } },
            isIncomplete = true,
          })
        end,
      })
      vim.wait(100, function()
        return s.status == source.SourceStatus.COMPLETED
      end, 100, false)
      assert.is.truthy(s:complete(state.input('s'), function() end))
      vim.wait(100, function()
        return s.status == source.SourceStatus.COMPLETED
      end, 100, false)
      assert.is.truthy(s:complete(state.input('p'), function() end))
      vim.wait(100, function()
        return s.status == source.SourceStatus.COMPLETED
      end, 100, false)
      assert.is.truthy(s:complete(state.input('e'), function() end))
      vim.wait(100, function()
        return s.status == source.SourceStatus.COMPLETED
      end, 100, false)
      assert.is.truthy(s:complete(state.input('c'), function() end))
      vim.wait(100, function()
        return s.status == source.SourceStatus.COMPLETED
      end, 100, false)
    end)
  end)

  describe('enabled', function()
    it('defaults to true', function()
      local s = source.new('spec', {})
      assert.is.truthy(s:enabled())
    end)

    it('honors a boolean', function()
      config.set_global({ sources = { { name = 'spec', enabled = false } } })
      local s = source.new('spec', {})
      assert.is.falsy(s:enabled())
    end)

    it('calls a function with the context', function()
      config.set_global({
        sources = {
          {
            name = 'spec',
            enabled = function(ctx)
              return ctx.cursor_before_line == 'yes'
            end,
          },
        },
      })
      local state = spec.state('', 1, 1)
      state.input('yes')
      assert.is.truthy(state.source():enabled())
      state.input('no')
      assert.is.falsy(state.source():enabled())
    end)
  end)

  describe('hide_snippets', function()
    -- get_entries yields to the scheduler, so it must run in an async context.
    local complete_with_kinds = function()
      local state = spec.state('', 1, 1)
      local s = source.new('spec', {
        complete = function(_, _, callback)
          callback({
            { label = 'a_text', kind = types.lsp.CompletionItemKind.Text },
            { label = 'a_snip', kind = types.lsp.CompletionItemKind.Snippet },
          })
        end,
      })
      local ctx = state.input('a')
      s:complete(ctx, function() end)
      vim.wait(5000, function()
        return #s.entries > 0
      end)
      local a = async.wrap(function()
        return s:get_entries(ctx)
      end)()
      a:sync()
      return a.result
    end

    it('shows snippet-kind entries by default', function()
      local entries = complete_with_kinds()
      assert.are.equal(2, #entries)
    end)

    it('hides snippet-kind entries when enabled', function()
      config.set_global({ snippet = { hide_snippets = true } })
      local entries = complete_with_kinds()
      assert.are.equal(1, #entries)
      assert.are.equal('a_text', entries[1].completion_item.label)
    end)
  end)
end)
