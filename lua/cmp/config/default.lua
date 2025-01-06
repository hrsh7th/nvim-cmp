local compare = require('cmp.config.compare')
local types = require('cmp.types')

local WIDE_HEIGHT = 40

---@return cmp.ConfigSchema
return function()
  ---@type cmp.ConfigSchema
  local config = {
    enabled = function()
      local disabled = false
      disabled = disabled or (vim.api.nvim_get_option_value('buftype', { buf = 0 }) == 'prompt')
      disabled = disabled or (vim.fn.reg_recording() ~= '')
      disabled = disabled or (vim.fn.reg_executing() ~= '')
      return not disabled
    end,

    performance = {
      debounce = 60,
      throttle = 30,
      fetching_timeout = 500,
      filtering_context_budget = 3,
      confirm_resolve_timeout = 80,
      async_budget = 1,
      max_view_entries = 200,
    },

    preselect = types.cmp.PreselectMode.Item,

    mapping = {},

    snippet = {
      expand = vim.fn.has('nvim-0.10') == 1 and function(args)
        vim.snippet.expand(args.body)
      end or function(_)
        error('snippet engine is not configured.')
      end,
    },

    completion = {
      autocomplete = {
        types.cmp.TriggerEvent.TextChanged,
      },
      completeopt = 'menu,menuone,noselect',
      keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]],
      keyword_length = 1,
    },

    formatting = {
      expandable_indicator = true,
      fields = { 'abbr', 'kind', 'menu' },
      format = function(_, vim_item)
        return vim_item
      end,
    },

    matching = {
      disallow_fuzzy_matching = false,
      disallow_fullfuzzy_matching = false,
      disallow_partial_fuzzy_matching = true,
      disallow_partial_matching = false,
      disallow_prefix_unmatching = false,
      disallow_symbol_nonprefix_matching = true,
    },

    sorting = {
      priority_weight = 2,
      comparators = {
        compare.offset,
        compare.exact,
        -- compare.scopes,
        compare.score,
        compare.recently_used,
        compare.locality,
        compare.kind,
        compare.sort_text,
        compare.length,
        compare.order,
      },
    },

    sources = {},

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
      entries = {
        name = 'custom',
        selection_order = 'top_down',
        follow_cursor = false,
      },
      docs = {
        auto_open = true,
      },
    },

    window = {
      completion = {
        border = { '', '', '', '', '', '', '', '' },
        winhighlight = 'Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None',
        winblend = vim.o.pumblend,
        scrolloff = 0,
        col_offset = 0,
        side_padding = 1,
        scrollbar = true,
      },
      documentation = {
        max_height = math.floor(WIDE_HEIGHT * (WIDE_HEIGHT / vim.o.lines)),
        max_width = math.floor((WIDE_HEIGHT * 2) * (vim.o.columns / (WIDE_HEIGHT * 2 * 16 / 9))),
        border = { '', '', '', ' ', '', '', '', ' ' },
        winhighlight = 'FloatBorder:NormalFloat',
        winblend = vim.o.pumblend,
      },
    },
  }
  return config
end
