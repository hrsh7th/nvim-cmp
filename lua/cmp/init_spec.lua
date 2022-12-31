local async = require('cmp.utils.async')
local core = require('cmp.core')
local spec = require('cmp.utils.spec')
local types = require('cmp.types')
local config = require('cmp.config')
local source = require('cmp.source')
local Async = require('cmp.kit.Async')
local Keymap = require('cmp.kit.Vim.Keymap')

describe('cmp', function()
  before_each(spec.before)

  local function setup(override, option)
    local c = core.new()
    local s = source.new('spec', {
      complete = function(_, _, callback)
        callback({})
      end,
    })
    c:register_source(s)
    config.set_buffer({
      sources = {
        vim.tbl_deep_extend('keep', {
          name = 'spec',
          override = override,
        }, option or {}),
      },
    }, vim.api.nvim_get_current_buf())
    c:prepare()
    return c
  end

  it('should work source[n].override.is_available', function()
    local c = setup({
      complete = function(_, callback)
        callback({
          { label = 'ok!' },
        })
      end,
      is_available = function(_)
        return vim.api.nvim_get_current_line() == 'ok'
      end,
    })
    Keymap.spec(Async.async(function()
      -- o
      Keymap.send('io', 'ni'):await()
      c:complete(c:get_context({ reason = types.cmp.ContextReason.Manual }))
      vim.wait(200)
      assert.equals(0, #c.view:get_entries())

      -- ok
      Keymap.send('k', 'ni'):await()
      c:complete(c:get_context({ reason = types.cmp.ContextReason.Manual }))
      vim.wait(200)
      assert.equals(1, #c.view:get_entries())
    end))
  end)

  it('should work source[n].override.get_keyword_pattern from deprecated keyword_pattern option', function()
    local c = setup({
      complete = function(_, callback)
        callback({
          { label = '123' },
        })
      end,
    }, {
      keyword_pattern = [[\d\+]],
    })
    Keymap.spec(Async.async(function()
      -- o
      Keymap.send('io', 'ni'):await()
      c:complete(c:get_context({ reason = types.cmp.ContextReason.Auto }))
      vim.wait(200)
      assert.equals(0, #c.view:get_entries())

      -- ok
      Keymap.send(Keymap.termcodes('<BS>1'), 'ni'):await()
      c:complete(c:get_context({ reason = types.cmp.ContextReason.Auto }))
      vim.wait(200)
      assert.equals(1, #c.view:get_entries())
    end))
  end)

  it('should work source[n].override.get_trigger_characters from deprecated trigger_characters option', function()
    local c = setup({
      complete = function(_, callback)
        callback({
          { label = 'override' },
        })
      end,
    }, {
      trigger_characters = { 'v' },
    })
    ---@diagnostic disable-next-line: undefined-field
    assert.are.same(vim.tbl_values(c.sources)[1]:get_trigger_characters(), { 'v' })
  end)

  it('should work source[n].override.complete', function()
    local c = setup({
      complete = function(_, callback)
        callback({
          { label = 'override' },
        })
      end,
    })
    Keymap.spec(Async.async(function()
      Keymap.send('io', 'ni'):await()
      c:complete(c:get_context({ reason = types.cmp.ContextReason.Manual }))
      vim.wait(200)
      assert.equals('override', c.view:get_entries()[1]:get_completion_item().label)
    end))
  end)

  it('should work source[n].override.resolve', function()
    local c = setup({
      complete = function(_, callback)
        callback({
          { label = 'override' },
        })
      end,
      resolve = function(_, callback)
        callback({ label = 'override:resolved' })
      end,
    })
    Keymap.spec(Async.async(function()
      Keymap.send('io', 'ni'):await()
      c:complete(c:get_context({ reason = types.cmp.ContextReason.Manual }))
      vim.wait(200)
      async.sync(function(done)
        c.view:get_entries()[1]:resolve(done)
      end, 1000)
      assert.equals('override:resolved', c.view:get_entries()[1]:get_completion_item().label)
    end))
  end)

  it('should work source[n].override.resolve', function()
    local c = setup({
      complete = function(_, callback)
        callback({
          { label = 'override' },
        })
      end,
      execute = function(_, callback)
        vim.api.nvim_set_current_line('ok')
        callback()
      end,
    })
    Keymap.spec(Async.async(function()
      Keymap.send('io', 'ni'):await()
      c:complete(c:get_context({ reason = types.cmp.ContextReason.Manual }))
      vim.wait(200)
      async.sync(function(done)
        c.view:get_entries()[1]:execute(done)
      end, 1000)
      assert.equals('ok', vim.api.nvim_get_current_line())
    end))
  end)
end)
