local kit = require('cmp.kit')
local Async = require('cmp.kit.Async')
local AsyncTask = require('cmp.kit.Async.AsyncTask')

local Highlight = {}

Highlight.namespace = vim.api.nvim_create_namespace('cmp.kit.Vim.Highlight')

---Blink specified range.
---@param range cmp.kit.LSP.Range
---@param option? { delay: integer, count: integer }
---@return cmp.kit.Async.AsyncTask
function Highlight.blink(range, option)
  option = kit.merge(option or {}, {
    delay = 150,
    count = 2,
  })

  local function timeout(time)
    return AsyncTask.new(function(resolve)
      vim.defer_fn(vim.schedule_wrap(resolve), time)
    end)
  end

  return Async.run(function()
    timeout(option.delay * 1.2):await()
    for _ = 1, option.count do
      vim.highlight.range(0, Highlight.namespace, 'IncSearch', { range.start.line, range.start.character }, { range['end'].line, range['end'].character }, {})
      timeout(option.delay * 0.8):await()
      vim.api.nvim_buf_clear_namespace(0, Highlight.namespace, 0, -1)
      timeout(option.delay):await()
    end
  end)
end

return Highlight
