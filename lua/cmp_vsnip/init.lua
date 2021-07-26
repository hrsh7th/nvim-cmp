local cmp = require('cmp')

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.complete = function(_, request, callback)
  local completion_items = {}
  for _, item in ipairs(vim.fn['vsnip#get_complete_items'](vim.api.nvim_get_current_buf())) do
    local completion_item = {}
    local user_data = vim.fn.json_decode(item.user_data)
    completion_item.word = item.word
    completion_item.label = item.abbr
    completion_item.insertTextFormat = 2
    completion_item.insertText = table.concat(user_data.vsnip.snippet, '\n')
    completion_item.data = {
      filetype = request.context.filetype,
      snippet = user_data.vsnip.snippet,
    }
    table.insert(completion_items, completion_item)
  end

  callback(completion_items)
end

source.resolve = function(_, completion_item, callback)
  local documentation = {}
  table.insert(documentation, string.format('```%s', completion_item.data.filetype))
  for _, line in ipairs(vim.split(vim.fn['vsnip#to_string'](completion_item.data.snippet), '\n')) do
    table.insert(documentation, line)
  end
  table.insert(documentation, '```')

  completion_item.documentation = {
    kind = cmp.lsp.MarkupKind.Markdown,
    value = table.concat(documentation, '\n'),
  }
  callback(completion_item)
end

return source
