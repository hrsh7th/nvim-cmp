local buffer = require('cmp_buffer.buffer')

local source = {}

source.new = function()
  local self = setmetatable({}, { __index = source })
  self.buffers = {}
  return self
end

source.complete = function(self, request, callback)
  request.option = vim.tbl_deep_extend('keep', request.option, {
    target = function()
      local bufs = {}
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        bufs[vim.api.nvim_win_get_buf(win)] = true
      end
      return bufs
    end,
  })
  vim.validate({
    target = { request.option.target, 'function', 'opts.target must be `function`' },
  })

  local processing = false
  for _, buf in ipairs(self:_get_buffers(request)) do
    processing = processing or buf.processing
  end

  if processing then
    local timer = vim.loop.new_timer()
    timer:start(
      100,
      0,
      vim.schedule_wrap(function()
        timer:stop()
        timer:close()
        timer = nil
        self:_do_complete(request, callback)
      end)
    )
  else
    self:_do_complete(request, callback)
  end
end

--- _do_complete
source._do_complete = function(self, request, callback)
  local processing = false
  local words = {}
  local words_uniq = {}
  for _, b in ipairs(self:_get_buffers(request)) do
    processing = processing or b.processing
    for _, word in ipairs(b:get_words()) do
      if not words_uniq[word] then
        words_uniq[word] = true
        table.insert(words, { label = word })
      end
    end
  end

  callback({
    items = words,
    isIncomplete = processing,
  })
end

--- _get_bufs
source._get_buffers = function(self, request)
  local buffers = {}
  for _, bufnr in ipairs(request.option.target()) do
    if not self.buffers[bufnr] then
      local new_buf = buffer.new(bufnr, [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]], [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]])
      new_buf:index()
      new_buf:watch()
      self.buffers[bufnr] = new_buf
    end
    table.insert(buffers, self.buffers[bufnr])
  end

  return buffers
end

return source
