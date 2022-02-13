local compare = require('cmp.config.compare')
local mapping = require('cmp.config.mapping')
local types = require('cmp.types')

local WIDE_HEIGHT = 40

---@return cmp.ConfigSchema
return function()
  return {
    enabled = function()
      return vim.api.nvim_buf_get_option(0, 'buftype') ~= 'prompt'
    end,

    preselect = types.cmp.PreselectMode.Item,

    mapping = {
      ['<Down>'] = mapping({
        i = mapping.select_next_item({ behavior = types.cmp.SelectBehavior.Select }),
        c = function(fallback)
          local cmp = require('cmp')
          cmp.close()
          vim.schedule(cmp.suspend())
          fallback()
        end,
      }),
      ['<Up>'] = mapping({
        i = mapping.select_prev_item({ behavior = types.cmp.SelectBehavior.Select }),
        c = function(fallback)
          local cmp = require('cmp')
          cmp.close()
          vim.schedule(cmp.suspend())
          fallback()
        end,
      }),
      ['<Tab>'] = mapping({
        c = function(fallback)
          local cmp = require('cmp')
          if #cmp.core:get_sources() > 0 and not require('cmp.config').is_native_menu() then
            if cmp.visible() then
              cmp.select_next_item()
            else
              cmp.complete()
            end
          else
            fallback()
          end
        end,
      }),
      ['<S-Tab>'] = mapping({
        c = function(fallback)
          local cmp = require('cmp')
          if #cmp.core:get_sources() > 0 and not require('cmp.config').is_native_menu() then
            if cmp.visible() then
              cmp.select_prev_item()
            else
              cmp.complete()
            end
          else
            fallback()
          end
        end,
      }),
      ['<C-n>'] = mapping(mapping.select_next_item({ behavior = types.cmp.SelectBehavior.Insert }), { 'i', 'c' }),
      ['<C-p>'] = mapping(mapping.select_prev_item({ behavior = types.cmp.SelectBehavior.Insert }), { 'i', 'c' }),
      ['<C-y>'] = mapping.confirm({ select = false }),
      ['<C-e>'] = mapping.abort(),
    },

    snippet = {
      expand = function()
        error('snippet engine is not configured.')
      end,
    },

    completion = {
      keyword_length = 1,
      keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]],
      autocomplete = {
        types.cmp.TriggerEvent.TextChanged,
      },
      completeopt = 'menu,menuone,noselect',
    },

    formatting = {
      fields = { 'abbr', 'kind', 'menu' },
      format = function(_, vim_item)
        return vim_item
      end,
    },

    matching = {
      disallow_fuzzy_matching = false,
      disallow_partial_matching = false,
      disallow_prefix_unmatching = false,
    },

    sorting = {
      priority_weight = 2,
      comparators = {
        compare.offset,
        compare.exact,
        compare.score,
        compare.recently_used,
        compare.kind,
        compare.sort_text,
        compare.length,
        compare.order,
      },
    },

    sources = {},

    documentation = {
      border = { '', '', '', ' ', '', '', '', ' ' },
      winhighlight = 'NormalFloat:NormalFloat,FloatBorder:NormalFloat',
      maxwidth = math.floor((WIDE_HEIGHT * 2) * (vim.o.columns / (WIDE_HEIGHT * 2 * 16 / 9))),
      maxheight = math.floor(WIDE_HEIGHT * (WIDE_HEIGHT / vim.o.lines)),
    },

    confirmation = {
      default_behavior = types.cmp.ConfirmBehavior.Insert,
      get_commit_characters = function(commit_characters)
        return commit_characters
      end,
    },

    event = {},

    experimental = {
      ghost_text = false,
    },

    view = {
      entries = 'custom',
    },
  }
end
