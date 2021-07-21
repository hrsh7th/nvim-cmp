---@class cmp_buffer.Buffer
---@field public bufnr number
---@field public regexes any[]
---@field public pattern1 string
---@field public pattern2 string
---@field public timer any|nil
---@field public words table<number, string[]>
---@field public processing boolean
local buffer = {}

---Create new buffer object
---@param bufnr number
---@param pattern1 string
---@param pattern2 string
---@return cmp_buffer.Buffer
function buffer.new(bufnr, pattern1, pattern2)
  local self = setmetatable({}, { __index = buffer })
  self.bufnr = bufnr
  self.regexes = {}
  self.pattern1 = pattern1
  self.pattern2 = pattern2
  self.timer = nil
  self.words = {}
  self.processing = false
  return self
end

---Close buffer
function buffer.close(self)
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end
  self.words = {}
end

---Indexing buffer
function buffer.index(self)
  self.processing = true
  local index = 1
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
  self.timer = vim.loop.new_timer()
  self.timer:start(
    0,
    200,
    vim.schedule_wrap(function()
      local chunk = math.min(index + 1000, #lines)
      for i = index, chunk do
        self:index_line(i, lines[i] or '')
      end
      index = chunk + 1

      if chunk >= #lines then
        if self.timer then
          self.timer:stop()
          self.timer:close()
          self.timer = nil
        end
        self.processing = false
      end
    end)
  )
end

--- watch
function buffer.watch(self)
  vim.api.nvim_buf_attach(self.bufnr, false, {
    on_lines = vim.schedule_wrap(function(_, _, _, firstline, old_lastline, new_lastline, _, _, _)
      if not vim.api.nvim_buf_is_valid(self.bufnr) then
        self:close()
        return true
      end

      -- append
      for i = old_lastline, new_lastline - 1 do
        table.insert(self.words, i + 1, {})
      end

      -- remove
      for _ = new_lastline, old_lastline - 1 do
        table.remove(self.words, new_lastline + 1)
      end

      -- replace lines
      local lines = vim.api.nvim_buf_get_lines(self.bufnr, firstline, new_lastline, false)
      for i, line in ipairs(lines) do
        if line then
          self:index_line(firstline + i, line or '')
        end
      end
    end),
  })
end

--- add_words
function buffer.index_line(self, i, line)
  local words = {}

  local buf = line
  while true do
    local s, e = self:matchstrpos(buf)
    if s then
      local word = string.sub(buf, s + 1, e)
      if #word > 3 and string.sub(word, #word) ~= '-' then
        table.insert(words, word)
      end
    end
    local new_buffer = string.sub(buf, e and e + 1 or 2)
    if buf == new_buffer then
      break
    end
    buf = new_buffer
  end

  self.words[i] = words
end

--- get_words
function buffer.get_words(self)
  local words = {}
  for _, line in ipairs(self.words) do
    for _, w in ipairs(line) do
      table.insert(words, w)
    end
  end
  return words
end

--- matchstrpos
function buffer.matchstrpos(self, text)
  local s1, e1, s2, e2

  s1, e1 = self:regex(self.pattern1):match_str(text)
  if self.pattern1 ~= self.pattern2 then
    s2, e2 = self:regex(self.pattern2):match_str(text)
  else
    s2, e2 = s1, e1
  end

  if s1 == nil and s2 == nil then
    return nil, nil
  end

  if not s1 then
    s1 = s2
    e1 = e2
  end

  if not s2 then
    s2 = s1
    e2 = e1
  end

  local s = s1
  local e = e1
  if s1 < s2 then
    s = s1
    e = e2
  elseif s2 < s1 then
    s = s2
    e = e2
  elseif s1 == s2 then
    if e1 > e2 then
      s = s1
      e = e1
    elseif e2 > e1 then
      s = s2
      e = e2
    end
  end
  return s, e
end

--- regex
function buffer.regex(self, pattern)
  self.regexes[pattern] = self.regexes[pattern] or vim.regex(pattern)
  return self.regexes[pattern]
end

return buffer
