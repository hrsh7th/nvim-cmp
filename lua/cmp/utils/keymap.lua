local misc = require('cmp.utils.misc')
local api = require('cmp.utils.api')

local keymap = {}

---Shortcut for nvim_replace_termcodes
---@param keys string
---@return string
keymap.t = function(keys)
  return (string.gsub(keys, '(<[A-Za-z0-9\\%-%[%]%^@]->)', function(match)
    return vim.api.nvim_eval(string.format([["\%s"]], match))
  end))
end

---Normalize key sequence.
---@param keys string
---@return string
keymap.normalize = function(keys)
  vim.api.nvim_set_keymap('t', '<Plug>(cmp.utils.keymap.normalize)', keys, {})
  for _, map in ipairs(vim.api.nvim_get_keymap('t')) do
    if keymap.equals(map.lhs, '<Plug>(cmp.utils.keymap.normalize)') then
      return map.rhs
    end
  end
  return keys
end

---Return vim notation keymapping (simple conversion).
---@param s string
---@return string
keymap.to_keymap = setmetatable({
  ['<CR>'] = { '\n', '\r', '\r\n' },
  ['<Tab>'] = { '\t' },
  ['<BSlash>'] = { '\\' },
  ['<Bar>'] = { '|' },
  ['<Space>'] = { ' ' },
}, {
  __call = function(self, s)
    return string.gsub(s, '.', function(c)
      for key, chars in pairs(self) do
        if vim.tbl_contains(chars, c) then
          return key
        end
      end
      return c
    end)
  end,
})

---Mode safe break undo
keymap.undobreak = function()
  if not api.is_insert_mode() then
    return ''
  end
  return keymap.t('<C-g>u')
end

---Mode safe join undo
keymap.undojoin = function()
  if not api.is_insert_mode() then
    return ''
  end
  return keymap.t('<C-g>U')
end

---Create backspace keys.
---@param count number
---@return string
keymap.backspace = function(count)
  if count <= 0 then
    return ''
  end
  local keys = {}
  table.insert(keys, keymap.t(string.rep('<BS>', count)))
  return table.concat(keys, '')
end

---Update indentkeys.
---@param expr string
---@return string
keymap.indentkeys = function(expr)
  return string.format(keymap.t('<Cmd>set indentkeys=%s<CR>'), expr and vim.fn.escape(expr, '| \t\\') or '')
end

---Return two key sequence are equal or not.
---@param a string
---@param b string
---@return boolean
keymap.equals = function(a, b)
  return keymap.t(a) == keymap.t(b)
end

---Register keypress handler.
keymap.listen = function(mode, lhs, callback)
  lhs = keymap.normalize(keymap.to_keymap(lhs))

  local existing = keymap.get_map(mode, lhs)
  local id = string.match(existing.rhs, 'v:lua%.cmp%.utils%.keymap%.set_map%((%d+)%)')
  if id and keymap.set_map.callbacks[tonumber(id, 10)] then
    return
  end

  local bufnr = existing.buffer and vim.api.nvim_get_current_buf() or -1
  keymap.set_map(bufnr, mode, lhs, function()
    if mode == 'c' and vim.fn.getcmdtype() == '=' then
      return keymap.feed_map(existing)
    end

    callback(
      lhs,
      misc.once(function()
        keymap.feed_map(existing)
      end)
    )
  end, {
    expr = false,
    noremap = true,
    silent = true,
  })
end

---Get map
---@param mode string
---@param lhs string
---@return table
keymap.get_map = function(mode, lhs)
  lhs = keymap.normalize(lhs)

  for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
    if keymap.equals(map.lhs, lhs) then
      return {
        lhs = map.lhs,
        rhs = map.rhs or '',
        expr = map.expr == 1,
        callback = map.callback,
        noremap = map.noremap == 1,
        script = map.script == 1,
        silent = map.silent == 1,
        nowait = map.nowait == 1,
        buffer = true,
      }
    end
  end

  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    if keymap.equals(map.lhs, lhs) then
      return {
        lhs = map.lhs,
        rhs = map.rhs or '',
        expr = map.expr == 1,
        callback = map.callback,
        noremap = map.noremap == 1,
        script = map.script == 1,
        silent = map.silent == 1,
        nowait = map.nowait == 1,
        buffer = false,
      }
    end
  end

  return {
    lhs = lhs,
    rhs = lhs,
    expr = false,
    callback = nil,
    noremap = true,
    script = false,
    silent = false,
    nowait = false,
    buffer = false,
  }
end

---Feed mapping object.
---@param map table
keymap.feed_map = function(map)
  local lhs = keymap.t(map.lhs)
  local rhs
  if map.callback and not map.expr then
    return map.callback()
  elseif map.callback and map.expr then
    rhs = map.callback()
  elseif map.expr then
    rhs = vim.api.nvim_eval(keymap.t(map.rhs))
  else
    rhs = keymap.t(map.rhs)
  end

  if not map.noremap and string.find(rhs, lhs, 1, true) == 1 then
    rhs = string.gsub(rhs, '^' .. vim.pesc(lhs), '')
    vim.api.nvim_feedkeys(keymap.expression(rhs), 'itm', true)
    vim.api.nvim_feedkeys(lhs, 'itn', true)
  else
    vim.api.nvim_feedkeys(keymap.expression(rhs), 'it' .. (map.noremap and 'n' or 'm'), true)
  end
end

---Set keymapping
keymap.set_map = setmetatable({
  callbacks = {},
}, {
  __call = function(self, bufnr, mode, lhs, rhs, opts)
    if type(rhs) == 'function' then
      local id = misc.id('cmp.utils.keymap.set_map')
      self.callbacks[id] = rhs
      if opts.expr then
        rhs = ('v:lua.cmp.utils.keymap.set_map(%s)'):format(id)
      else
        rhs = ('<Cmd>call v:lua.cmp.utils.keymap.set_map(%s)<CR>'):format(id)
      end
    end

    if bufnr == -1 then
      vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
    else
      vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)
    end
  end,
})
misc.set(_G, { 'cmp', 'utils', 'keymap', 'set_map' }, function(id)
  return keymap.set_map.callbacks[id]() or ''
end)

---Resolve expression.
---@param expr string
---@return string
keymap.expression = function(expr)
  local spans = {}
  local f = 0
  for i = 1, #expr do
    local c = string.sub(expr, i, i)
    if f == 0 and c == keymap.t('<C-r>') then
      f = i
    end
    if f ~= 0 and c == keymap.t('<CR>') then
      table.insert(spans, { s = f, e = i })
      f = 0
    end
  end
  for i = #spans, 1, -1 do
    local s, e = spans[i].s, spans[i].e
    expr = string.sub(expr, 1, s - 1) .. keymap.expression(vim.api.nvim_eval(string.sub(expr, s + 2, e - 1))) .. string.sub(expr, e + 1)
  end
  return expr
end

return keymap
