local cmp = require('cmp')
local config = require('cmp.config')
local source = require('cmp.source')
local feedkeys = require('cmp.utils.feedkeys')
local types = require('cmp.types')
local spec = require('cmp.utils.spec')

describe('cmp', function()
  before_each(spec.before)

  it('registers keymaps even when cmp is disabled at InsertEnter', function()
    config.set_global({
      mapping = {
        ['<C-d>'] = cmp.mapping.scroll_docs(4),
      },
    })

    -- The mode is normal here, so config.enabled() is false on the scheduled
    -- callback; this is the disabled-at-first-insert case.
    assert.is.truthy(vim.fn.maparg('<C-d>', 'i', false, true).desc ~= 'cmp.utils.keymap.set_map')

    vim.api.nvim_exec_autocmds('InsertEnter', {})
    vim.wait(1000, function()
      return vim.fn.maparg('<C-d>', 'i', false, true).desc == 'cmp.utils.keymap.set_map'
    end)

    assert.are.equal('cmp.utils.keymap.set_map', vim.fn.maparg('<C-d>', 'i', false, true).desc)
  end)

  local confirm_select_if_unique = function(items)
    local s = source.new('spec', {
      get_position_encoding_kind = function()
        return types.lsp.PositionEncodingKind.UTF16
      end,
      complete = function(_, _, callback)
        callback(items)
      end,
    })
    cmp.core:register_source(s)

    local state = {}
    feedkeys.call('iA', 'n', function()
      cmp.core:complete(cmp.core:get_context({ reason = types.cmp.ContextReason.Manual }))
      vim.wait(5000, function()
        return cmp.core.view:visible()
      end)
      state.confirmed = cmp.confirm({ selectIfUnique = true }, function() end)
    end)
    feedkeys.call('', 'x', function()
      feedkeys.call('', 'n', function()
        state.buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      end)
    end)
    return state
  end

  it('confirm selectIfUnique confirms a single entry', function()
    local state = confirm_select_if_unique({
      { label = 'AIUEO' },
    })
    assert.is.truthy(state.confirmed)
    assert.are.same({ 'AIUEO' }, state.buffer)
  end)

  it('confirm selectIfUnique does not select among several entries', function()
    local state = confirm_select_if_unique({
      { label = 'AIUEO' },
      { label = 'AIUEO2' },
    })
    assert.is.falsy(state.confirmed)
    assert.are.same({ 'A' }, state.buffer)
  end)

  it('toggle_docs opens and closes the documentation window', function()
    -- Keep the docs closed on entry change so only the toggle drives them.
    config.set_global({ view = { docs = { auto_open = false } } })
    local s = source.new('spec', {
      get_position_encoding_kind = function()
        return types.lsp.PositionEncodingKind.UTF16
      end,
      complete = function(_, _, callback)
        callback({
          {
            label = 'AIUEO',
            documentation = { value = 'docs text' },
          },
        })
      end,
    })
    cmp.core:register_source(s)

    local toggled = false
    feedkeys.call('iA', 'n', function()
      cmp.core:complete(cmp.core:get_context({ reason = types.cmp.ContextReason.Manual }))
      vim.wait(5000, function()
        return cmp.core.view:visible()
      end)
      cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
      assert.is.truthy(cmp.core.view:get_selected_entry())

      assert.is.truthy(cmp.toggle_docs())
      vim.wait(5000, function()
        return cmp.core.view.docs_view:visible()
      end)
      assert.is.truthy(cmp.visible_docs())

      assert.is.truthy(cmp.toggle_docs())
      vim.wait(5000, function()
        return not cmp.core.view.docs_view:visible()
      end)
      assert.is.falsy(cmp.visible_docs())
      toggled = true
    end)
    -- Mode 'n' only queues the keys; the 'x' call runs them inside this test
    -- instead of leaking the callback into the next test that flushes keys.
    feedkeys.call('', 'x', function()
      assert.is.truthy(toggled)
    end)
  end)
end)
