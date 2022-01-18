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
  local fallback = keymap.fallback(bufnr, mode, existing)
  keymap.set_map(bufnr, mode, lhs, function()
    if mode == 'c' and vim.fn.getcmdtype() == '=' then
      vim.api.nvim_feedkeys(fallback.keys, 'it' .. (fallback.noremap and 'n' or 'm'), true)
    else
      callback(
        lhs,
        misc.once(function()
          vim.api.nvim_feedkeys(fallback.keys, 'it' .. (fallback.noremap and 'n' or 'm'), true)
        end)
      )
    end
  end, {
    expr = false,
    noremap = true,
    silent = true,
  })
end

---Fallback existing mapping.
--- NOTE:
---   In insert-mode, we should all mapping fallback to the `<Plug>` because `<C-r>=` will display gabage message.
---   In cmdline-mode, we shouldn't re-map as `<Plug>` because `cmap <Tab> <Plug>(map-to-tab)` will broke native behavior.
---   We should resolve recursive mapping because existing mapping will feed by `feedkeys` that doesn't solve recursive mapping.
---     We use `<C-r>=` to solve recursive mapping.
---@param map table
keymap.fallback = setmetatable({
  cache = cache.new(),
}, {
  __call = function(self, bufnr, mode, map)
    local fallback = self.cache:ensure({ bufnr, mode, map.lhs }, function()
      return string.format('<Plug>(cmp.u.k.fallback:%s)', misc.id('cmp.utils.keymap.fallback'))
    end)

    if map.expr then
      keymap.set_map(bufnr, mode, fallback, function()
        local lhs = keymap.t(map.lhs)
        local rhs = (function()
          if map.callback then
            return map.callback()
          end
          return vim.api.nvim_eval(keymap.t(map.rhs))
        end)()
        if not map.noremap then
          rhs = keymap.recursive(lhs, rhs)
        end
        return rhs
      end, {
        expr = true,
        noremap = map.noremap,
        script = map.script,
        silent = mode ~= 'c',
        nowait = map.nowait,
      })
    elseif mode ~= 'c' or map.callback then
      local rhs = map.rhs
      if not map.noremap then
        rhs = keymap.recursive(map.lhs, rhs)
      end
      keymap.set_map(bufnr, mode, fallback, rhs, {
        expr = false,
        callback = map.callback,
        noremap = map.noremap,
        script = map.script,
        silent = mode ~= 'c' and map.silent,
        nowait = map.nowait,
      })
    else
      local lhs = keymap.t(map.lhs)
      local rhs = keymap.t(map.rhs)
      if not map.noremap then
        rhs = keymap.recursive(lhs, rhs)
      end
      return { keys = rhs, noremap = map.noremap }
    end
    return { keys = keymap.t(fallback), noremap = false }
  end,
})

---Solve recursive mapping.
---@param lhs string
---@param rhs string
---@return string
keymap.recursive = function(lhs, rhs)
  if string.find(rhs, lhs, 1, true) == 1 then
    local expr = string.format(keymap.t('<C-r>=v:lua.vim.json.decode(%s)<CR>'), vim.fn.string(vim.json.encode(keymap.t(lhs))))
    return string.gsub(rhs, '^' .. vim.pesc(lhs), expr)
  end
  return rhs
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
