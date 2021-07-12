local misc = require('cmp.utils.misc')
local cache = require('cmp.utils.cache')
local lsp = require('cmp.types.lsp')
local cmp = require('cmp.types.cmp')
local str = require('cmp.utils.str')

local WIDE_HEIGHT = 40

---@type cmp.ConfigSchema
local default = {
  revision = 1,

  default_confirm_behavior = cmp.ConfirmBehavior.Replace,

  documentation = {
    border = { '', '', '', ' ', '', '', '', ' ' },
    winhighlight = 'FloatBorder:PmenuSbar,NormalFloat:PmenuSbar',
    maxwidth = math.floor((WIDE_HEIGHT * 2) * (vim.o.columns / (WIDE_HEIGHT * 2 * 16 / 9))),
    maxheight = math.floor(WIDE_HEIGHT * (WIDE_HEIGHT / vim.o.lines)),
  },

  ---@param _ cmp.Entry
  ---@return string[]
  commit_characters = function(_)
    return { '\n' }
  end,

  ---@see https://github.com/microsoft/vscode/blob/main/src/vs/editor/contrib/suggest/suggest.ts#L302
  ---@param entry1 cmp.Entry
  ---@param entry2 cmp.Entry
  ---@return number
  compare = function(entry1, entry2)
    -- preselect
    if entry1.completion_item.preselect ~= entry2.completion_item.preselect then
      if entry1.completion_item.preselect then
        return -1
      else
        return 1
      end
    end

    -- score
    if entry1.score ~= entry2.score then
      return entry2.score - entry1.score
    end

    -- kind (NOTE: cmp's specific implementation to lower the `Text` kind)
    local kind1 = entry1.completion_item.kind or 1
    if kind1 == lsp.CompletionItemKind.Text then
      kind1 = 100
    end
    local kind2 = entry2.completion_item.kind or 1
    if kind2 == lsp.CompletionItemKind.Text then
      kind2 = 100
    end
    if kind1 ~= kind2 then
      if kind1 == lsp.CompletionItemKind.Snippet then
        return -1
      elseif kind2 == lsp.CompletionItemKind.Snippet then
        return 1
      end
      return kind1 - kind2
    end

    -- sortText
    if misc.safe(entry1.completion_item.sortText) and misc.safe(entry2.completion_item.sortText) then
      local diff = vim.stricmp(entry1.completion_item.sortText, entry2.completion_item.sortText)
      if diff ~= 0 then
        return diff
      end
    end
    return #entry1:get_word() - #entry2:get_word()
  end,

  ---@param e cmp.Entry
  ---@param word string
  ---@param abbr string
  ---@param menu string
  ---@return vim.CompletedItem
  format = function(e, word, abbr, menu)
    if e.completion_item.deprecated or vim.tbl_contains(e.completion_item.tags or {}, lsp.CompletionItemTag.Deprecated) then
      abbr = str.strikethrough(abbr)
    end
    return {
      word = word,
      abbr = abbr,
      kind = lsp.CompletionItemKind[misc.safe(e.completion_item.kind) or 1] or lsp.CompletionItemKind[1],
      menu = menu,
      equal = 1,
      empty = 1,
      dup = 1,
      user_data = {
        cmp = e.id,
      },
    }
  end,

  snippet = {
    expand = function()
      error('snippet engine does not configured.')
    end,
  },
}

---@class cmp.Config
---@field public g cmp.ConfigSchema
local config = {}

---@type cmp.Cache
config.cache = cache.new()

---@type table<number, cmp.ConfigSchema>
config.bufs = {}

---Set configuration for global or specified buffer
---@param c cmp.ConfigSchema
---@param bufnr number|nil
config.set = function(c, bufnr)
  if bufnr == nil then
    for k, v in pairs(c) do
      default[k] = v
    end
    default.reivision = default.revision + 1
  else
    bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
    config.bufs[bufnr] = c
    config.bufs[bufnr].revision = config.bufs[bufnr].revision or 1
    config.bufs[bufnr].revision = config.bufs[bufnr].revision + 1
  end
end

---@return cmp.ConfigSchema
config.get = function()
  local def = default
  local buf = config.bufs[vim.api.nvim_get_current_buf()] or { revision = 1 }
  return config.cache:ensure({ def.revision, buf.revision }, function()
    local c = {}
    for k, v in pairs(buf) do
      c[k] = v
    end
    for k, v in pairs(default) do
      if c[k] == nil then
        c[k] = v
      end
    end
    return c
  end)
end

return config
