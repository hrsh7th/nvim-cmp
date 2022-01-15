local cache = require('cmp.utils.cache')
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
  local fallback = keymap.evacuate(bufnr, mode, existing)
  keymap.set_map(bufnr, mode, lhs, function()
    if mode == 'c' and vim.fn.getcmdtype() == '=' then
      return vim.api.nvim_feedkeys(keymap.t(fallback), 'it', true)
    end

    callback(
      lhs,
      misc.once(function()
        return vim.api.nvim_feedkeys(keymap.t(fallback), 'it', true)
      end)
    )
  end, {
    expr = false,
    noremap = true,
    silent = true,
  })
end

---Evacuate existing keymapping.
---@param bufnr number
---@param mode string
---@param existing table
---@return string
keymap.evacuate = setmetatable({
  cache = cache.new(),
}, {
  __call = function(self, bufnr, mode, existing)
    local fallback = self.cache:ensure({ bufnr, mode, existing.lhs }, function()
      return string.format('<Plug>(cmp.u.k.evacuate:%s)', misc.id('cmp.utils.keymap.evacuate'))
    end)

    local callback = not existing.expr and existing.callback
    keymap.set_map(bufnr, mode, fallback, function()
      -- Make resolved key sequence.
      local lhs = keymap.t(existing.lhs)
      local rhs
      if existing.callback then
        rhs = existing.callback()
      elseif existing.expr then
        rhs = vim.api.nvim_eval(keymap.t(existing.rhs))
      else
        rhs = keymap.t(existing.rhs)
      end

      -- Resolve recursive mapping. See `:help recursive_mapping`.
      if not existing.noremap then
        if string.find(rhs, lhs, 1, true) == 1 then
          rhs = string.gsub(rhs, '^' .. vim.pesc(lhs), string.format(keymap.t([[<C-r>=v:lua.vim.json.decode(%s)<CR>]]), vim.fn.string(vim.json.encode(lhs))))
        end
      end

      return rhs
    end, callback and {
      expr = false,
      callback = callback,
      noremap = existing.noremap,
      script = existing.script,
      silent = true,
      nowait = existing.nowait,
    } or {
      expr = true,
      noremap = existing.noremap,
      script = existing.script,
      silent = true,
      nowait = existing.nowait,
    })

    return fallback
  end,
})

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
    silent = true,
    nowait = false,
    buffer = false,
  }
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

return keymap
