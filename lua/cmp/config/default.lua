local compare = require('cmp.config.compare')
local types = require('cmp.types')

local WIDE_HEIGHT = 40

---@return cmp.ConfigSchema
return function()
  return {
    completion = {
      autocomplete = {
        types.cmp.TriggerEvent.InsertEnter,
        types.cmp.TriggerEvent.TextChanged,
      },
      completeopt = 'menu,menuone,noselect',
      keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]],
      keyword_length = 1,
    },

    snippet = {
      expand = function()
        error('snippet engine does not configured.')
      end,
    },

    documentation = {
      border = { '', '', '', ' ', '', '', '', ' ' },
      winhighlight = 'NormalFloat:CmpDocumentation,FloatBorder:CmpDocumentationBorder',
      maxwidth = math.floor((WIDE_HEIGHT * 2) * (vim.o.columns / (WIDE_HEIGHT * 2 * 16 / 9))),
      maxheight = math.floor(WIDE_HEIGHT * (WIDE_HEIGHT / vim.o.lines)),
    },

    confirmation = {
      default_behavior = types.cmp.ConfirmBehavior.Replace,
    },

    sorting = {
      priority_weight = 2,
      comparators = {
        compare.offset,
        compare.exact,
        compare.score,
        compare.kind,
        compare.sort_text,
        compare.length,
        compare.order,
      }
    },

    event = {},

    mapping = {},

    formatting = {
      format = function(_, vim_item)
        return vim_item
      end
    },

    sources = {},
  }
end
