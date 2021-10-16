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
    completion = {
      autocomplete = {
        types.cmp.TriggerEvent.TextChanged,
      },
      completeopt = 'menu,menuone,noselect',
      keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]],
      keyword_length = 1,
      get_trigger_characters = function(trigger_characters)
        return trigger_characters
      end,
    },

    snippet = {
      expand = function()
        error('snippet engine is not configured.')
      end,
    },

    preselect = types.cmp.PreselectMode.Item,

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

    sorting = {
      priority_weight = 2,
      comparators = {
        function(e1, e2)
          local diff
          diff = compare.offset(e1, e2)
          if diff ~= nil then
            return diff
          end
          diff = compare.exact(e1, e2)
          if diff ~= nil then
            return diff
          end
          diff = compare.score(e1, e2)
          if diff ~= nil then
            return diff
          end
          diff = compare.kind(e1, e2)
          if diff ~= nil then
            return diff
          end
          diff = compare.sort_text(e1, e2)
          if diff ~= nil then
            return diff
          end
          diff = compare.length(e1, e2)
          if diff ~= nil then
            return diff
          end
          return compare.order(e1, e2)
        end,
      },
    },

    event = {},

    mapping = {
      ['<Down>'] = mapping(mapping.select_next_item({ behavior = types.cmp.SelectBehavior.Select }), { 'i' }),
      ['<Up>'] = mapping(mapping.select_prev_item({ behavior = types.cmp.SelectBehavior.Select }), { 'i' }),
      ['<C-n>'] = mapping(mapping.select_next_item({ behavior = types.cmp.SelectBehavior.Insert }), { 'i' }),
      ['<C-p>'] = mapping(mapping.select_prev_item({ behavior = types.cmp.SelectBehavior.Insert }), { 'i' }),
    },

    formatting = {
      fields = { 'abbr', 'kind', 'menu' },
      format = function(_, vim_item)
        return vim_item
      end,
    },

    experimental = {
      native_menu = false,
      ghost_text = false,
    },

    sources = {},
  }
end
