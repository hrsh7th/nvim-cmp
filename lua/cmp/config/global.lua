local lsp = require('cmp.types.lsp')
local cmp = require('cmp.types.cmp')
local str = require('cmp.utils.str')
local misc = require('cmp.utils.misc')

local WIDE_HEIGHT = 40

---@type cmp.ConfigSchema
return {
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
    local diff

    -- preselect
    if entry1.completion_item.preselect ~= entry2.completion_item.preselect then
      if entry1.completion_item.preselect then
        return false
      else
        return true
      end
    end

    -- score
    diff = entry2.score - entry1.score
    if diff < 0 then
      return true
    elseif diff > 0 then
      return false
    end

    -- sortText
    if misc.safe(entry1.completion_item.sortText) and misc.safe(entry2.completion_item.sortText) then
      diff = vim.stricmp(entry1.completion_item.sortText, entry2.completion_item.sortText)
      if diff < 0 then
        return true
      elseif diff > 0 then
        return false
      end
    end

    -- label
    diff = #entry1.completion_item.label - #entry2.completion_item.label
    if diff < 0 then
      return true
    elseif diff > 0 then
      return false
    end

    -- order
    diff = entry1.id - entry2.id
    if diff < 0 then
      return true
    elseif diff > 0 then
      return false
    end
  end,

  ---@param e cmp.Entry
  ---@param word string
  ---@param abbr string
  ---@param menu string
  ---@return vim.CompletedItem
  format = function(e, word, abbr, menu)
    -- deprecated
    local completion_item = e:get_completion_item()
    if completion_item.deprecated or vim.tbl_contains(e.completion_item.tags or {}, lsp.CompletionItemTag.Deprecated) then
      abbr = str.strikethrough(abbr)
    end

    -- ~ indicator
    if #(misc.safe(completion_item.additionalTextEdits) or {}) > 0 then
      abbr = abbr .. '~'
    elseif completion_item.insertTextFormat == lsp.InsertTextFormat.Snippet then
      local insert_text = e:get_insert_text()
      if word ~= insert_text then
        abbr = abbr .. '~'
      end
    end

    return {
      word = word,
      abbr = abbr,
      kind = lsp.CompletionItemKind[misc.safe(completion_item.kind) or 1] or lsp.CompletionItemKind[1],
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
