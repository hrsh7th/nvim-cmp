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

  local function setup(override)
    local c = core.new()
    local s = source.new('spec', {
      complete = function(_, _, callback)
        callback({})
      end,
    })
    c:register_source(s)
    config.set_buffer({
      sources = {
        {
          name = 'spec',
          override = override,
        },
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
