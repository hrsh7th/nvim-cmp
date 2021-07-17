local types = require('cmp.types')
local str = require('cmp.utils.str')
local misc = require('cmp.utils.misc')

local WIDE_HEIGHT = 40

---@return cmp.ConfigSchema
return function()
  return {
    autocomplete = true,
    keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]],


    snippet = {
      expand = function()
        error('snippet engine does not configured.')
      end,
    },

    preselect = {
      mode = types.cmp.PreselectMode.Item,
    },

    commit_characters = {
      resolve = function(e)
        return misc.concat(e:get_commit_characters(), { '\n' })
      end
    },

    documentation = {
      border = { '', '', '', ' ', '', '', '', ' ' },
      winhighlight = 'NormalFloat:CmpDocumentation,FloatBorder:CmpDocumentationBorder',
      maxwidth = math.floor((WIDE_HEIGHT * 2) * (vim.o.columns / (WIDE_HEIGHT * 2 * 16 / 9))),
      maxheight = math.floor(WIDE_HEIGHT * (WIDE_HEIGHT / vim.o.lines)),
    },

    confirm = {
      default_behavior = types.cmp.ConfirmBehavior.Replace,
    },

    menu = {
      sort = function(entries)
        table.sort(entries, function(entry1, entry2)
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

          -- kind
          local kind1 = entry1:get_kind()
          kind1 = kind1 == types.lsp.CompletionItemKind.Text and 100 or kind1
          local kind2 = entry2:get_kind()
          kind2 = kind2 == types.lsp.CompletionItemKind.Text and 100 or kind2
          if kind1 ~= kind2 then
            if kind1 == types.lsp.CompletionItemKind.Snippet then
              return true
            end
            if kind2 == types.lsp.CompletionItemKind.Snippet then
              return false
            end
            diff = kind1 - kind2
            if diff < 0 then
              return true
            elseif diff > 0 then
              return false
            end
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
        end)
        return entries
      end,

      format = function(e, suggest_offset)
        local item = e:get_completion_item()
        local word = e:get_word()
        local abbr = str.trim(item.label)

        -- ~ indicator
        if #(misc.safe(item.additionalTextEdits) or {}) > 0 then
          abbr = abbr .. '~'
        elseif item.insertTextFormat == types.lsp.InsertTextFormat.Snippet then
          local insert_text = e:get_insert_text()
          if word ~= insert_text then
            abbr = abbr .. '~'
          end
        end

        -- deprecated
        if item.deprecated or vim.tbl_contains(e.completion_item.tags or {}, types.lsp.CompletionItemTag.Deprecated) then
          abbr = str.strikethrough(abbr)
        end

        -- append delta text
        if suggest_offset < e:get_offset() then
          word = string.sub(e.context.cursor_before_line, suggest_offset, e:get_offset() - 1) .. word
        end

        -- labelDetails.
        local menu = nil
        if misc.safe(item.labelDetails) then
          menu = ''
          if misc.safe(item.labelDetails.parameters) then
            menu = menu .. item.labelDetails.parameters
          end
          if misc.safe(item.labelDetails.type) then
            menu = menu .. item.labelDetails.type
          end
          if misc.safe(item.labelDetails.qualifier) then
            menu = menu .. item.labelDetails.qualifier
          end
        end

        return {
          word = word,
          abbr = abbr,
          kind = types.lsp.CompletionItemKind[e:get_kind()] or types.lsp.CompletionItemKind[1],
          menu = menu,
        }
      end,
    },

    sources = {},
  }
end
