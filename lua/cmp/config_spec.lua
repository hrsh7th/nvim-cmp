local config = require('cmp.config')
local misc = require('cmp.utils.misc')

describe('config', function()
  local saved_global

  before_each(function()
    saved_global = config.global
    config.global = require('cmp.config.default')()
    config.buffers = {}
    config.filetypes = {}
    config.cmdline = {}
    config.onetime = {}
    config.cache:clear()
  end)

  after_each(function()
    config.global = saved_global
    config.buffers = {}
    config.filetypes = {}
    config.cmdline = {}
    config.onetime = {}
    config.cache:clear()
  end)

  it('set_buffer merges repeated calls', function()
    config.set_buffer({
      sources = {
        { name = 'buffer' },
      },
      completion = {
        keyword_length = 2,
      },
    }, 1)
    config.set_buffer({
      completion = {
        keyword_length = 3,
      },
    }, 1)

    assert.are.equal(1, #config.buffers[1].sources)
    assert.are.equal('buffer', config.buffers[1].sources[1].name)
    assert.are.equal(3, config.buffers[1].completion.keyword_length)
  end)

  it('set_buffer deletes a key with misc.none', function()
    config.set_buffer({
      completion = {
        keyword_length = 2,
      },
    }, 1)
    config.set_buffer({
      completion = misc.none,
    }, 1)

    assert.is.truthy(config.buffers[1].completion == nil)
  end)

  it('set_buffer replaces lists wholesale', function()
    config.set_buffer({
      sources = {
        { name = 'a' },
        { name = 'b' },
      },
    }, 1)
    config.set_buffer({
      sources = {
        { name = 'c' },
      },
    }, 1)

    assert.are.equal(1, #config.buffers[1].sources)
    assert.are.equal('c', config.buffers[1].sources[1].name)
  end)

  it('set_buffer bumps the revision per buffer', function()
    config.set_buffer({}, 1)
    assert.are.equal(2, config.buffers[1].revision)
    config.set_buffer({}, 1)
    assert.are.equal(3, config.buffers[1].revision)

    config.set_buffer({}, 2)
    assert.are.equal(2, config.buffers[2].revision)
  end)

  it('set_filetype merges per filetype', function()
    config.set_filetype({
      completion = {
        keyword_length = 1,
      },
    }, { 'lua', 'vim' })
    config.set_filetype({
      completion = {
        keyword_length = 2,
      },
    }, 'lua')

    assert.are.equal(2, config.filetypes['lua'].completion.keyword_length)
    assert.are.equal(1, config.filetypes['vim'].completion.keyword_length)
  end)

  it('set_cmdline merges per cmdtype', function()
    config.set_cmdline({
      completion = {
        keyword_length = 1,
      },
    }, ':')
    config.set_cmdline({
      completion = {
        keyword_length = 2,
      },
    }, ':')
    config.set_cmdline({
      completion = {
        keyword_length = 3,
      },
    }, { '/', '?' })

    assert.are.equal(2, config.cmdline[':'].completion.keyword_length)
    assert.are.equal(3, config.cmdline['/'].completion.keyword_length)
    assert.are.equal(3, config.cmdline['?'].completion.keyword_length)
  end)

  it('get prefers buffer over filetype over global', function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_option_value('filetype', 'lua', { buf = bufnr })

    config.set_global({
      completion = {
        keyword_length = 1,
      },
    })
    config.set_filetype({
      completion = {
        keyword_length = 2,
      },
    }, 'lua')

    assert.are.equal(2, config.get().completion.keyword_length)

    config.set_buffer({
      completion = {
        keyword_length = 3,
      },
    }, bufnr)

    assert.are.equal(3, config.get().completion.keyword_length)
  end)
end)
