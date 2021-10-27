local misc = require('cmp.utils.misc')
local str = require('cmp.utils.str')
local cache = require('cmp.utils.cache')
local api = require('cmp.utils.api')

local keymap = {}

---Shortcut for nvim_replace_termcodes
---@param keys string
---@return string
keymap.t = function(keys)
  return vim.api.nvim_replace_termcodes(keys, true, true, true)
end

---Escape keymap with <LT>
keymap.escape = function(keys)
  local i = 1
  while i <= #keys do
    if string.sub(keys, i, i) == '<' then
      if not vim.tbl_contains({ '<lt>', '<Lt>', '<lT>', '<LT>' }, string.sub(keys, i, i + 3)) then
        keys = string.sub(keys, 1, i - 1) .. '<LT>' .. string.sub(keys, i + 1)
        i = i + 3
      end
    end
    i = i + 1
  end
  return keys
end

---Normalize key sequence.
---@param keys string
---@return string
keymap.normalize = function(keys)
  vim.api.nvim_set_keymap('t', '<Plug>(cmp.utils.keymap.normalize)', keys, {})
  for _, map in ipairs(vim.api.nvim_get_keymap('t')) do
    if map.lhs == '<Plug>(cmp.utils.keymap.normalize)' then
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

---Return two key sequence are equal or not.
---@param a string
---@param b string
---@return boolean
keymap.equals = function(a, b)
  return keymap.t(a) == keymap.t(b)
end

---Feedkeys with callback
---@param keys string
---@param mode string
---@param callback function
keymap.feedkeys = setmetatable({
  callbacks = {},
}, {
  __call = function(self, keys, mode, callback)
    if vim.fn.reg_recording() ~= '' then
      return keymap.feedkeys_macro_safe(keys, mode, callback)
    end

    local is_insert = string.match(mode, 'i') ~= nil

    local queue = {}
    if #keys > 0 then
      table.insert(queue, { keymap.t('<Cmd>set backspace=start<CR>'), 'n' })
      table.insert(queue, { keymap.t('<Cmd>set eventignore=all<CR>'), 'n' })
      table.insert(queue, { keys, string.gsub(mode, '[it]', ''), true })
      table.insert(queue, { keymap.t('<Cmd>set backspace=%s<CR>'):format(vim.o.backspace or ''), 'n' })
      table.insert(queue, { keymap.t('<Cmd>set eventignore=%s<CR>'):format(vim.o.eventignore or ''), 'n' })
    end
    if #keys > 0 or callback then
      local id = misc.id('cmp.utils.keymap.feedkeys')
      self.callbacks[id] = function()
        if callback then
          callback()
        end
      end
      table.insert(queue, { keymap.t('<Cmd>call v:lua.cmp.utils.keymap.feedkeys.run(%s)<CR>'):format(id), 'n', true })
    end

    if is_insert then
      for i = #queue, 1, -1 do
        vim.api.nvim_feedkeys(queue[i][1], queue[i][2] .. 'i', queue[i][3])
      end
    else
      for i = 1, #queue do
        vim.api.nvim_feedkeys(queue[i][1], queue[i][2], queue[i][3])
      end
    end
  end,
})
misc.set(_G, { 'cmp', 'utils', 'keymap', 'feedkeys', 'run' }, function(id)
  if keymap.feedkeys.callbacks[id] then
    keymap.feedkeys.callbacks[id]()
    keymap.feedkeys.callbacks[id] = nil
  end
  return ''
end)

---Macro safe feedkeys.
---@param keys string
---@param mode string
---@param callback function
keymap.feedkeys_macro_safe = setmetatable({
  queue = {},
  current = nil,
  timer = vim.loop.new_timer(),
  running = false,
}, {
  __call = function(self, keys, mode, callback)
    local is_insert = string.match(mode, 'i') ~= nil
    table.insert(self.queue, is_insert and 1 or #self.queue + 1, {
      keys = keys,
      mode = mode,
      callback = callback,
    })

    if not self.running then
      self.running = true
      local consume
      consume = vim.schedule_wrap(function()
        if vim.fn.getchar(1) == 0 then
          if self.current then
            vim.cmd(('set backspace=%s'):format(self.current.backspace or ''))
            vim.cmd(('set eventignore=%s'):format(self.current.eventignore or ''))
            if self.current.callback then
              self.current.callback()
            end
            self.current = nil
          end

          local current = table.remove(self.queue, 1)
          if current then
            self.current = {
              keys = current.keys,
              callback = current.callback,
              backspace = vim.o.backspace,
              eventignore = vim.o.eventignore,
            }
            vim.api.nvim_feedkeys(keymap.t('<Cmd>set backspace=start<CR>'), 'n', true)
            vim.api.nvim_feedkeys(keymap.t('<Cmd>set eventignore=all<CR>'), 'n', true)
            vim.api.nvim_feedkeys(current.keys, string.gsub(current.mode, '[i]', ''), true) -- 'i' flag is manually resolved.
          end
        end

        if #self.queue ~= 0 or self.current then
          vim.defer_fn(consume, 1)
        else
          self.running = false
        end
      end)
      vim.defer_fn(consume, 1)
    end
  end,
})

---Register keypress handler.
keymap.listen = setmetatable({
  cache = cache.new(),
}, {
  __call = function(self, mode, keys_or_chars, callback)
    local keys = keymap.normalize(keymap.to_keymap(keys_or_chars))
    local bufnr = vim.api.nvim_get_current_buf()
    local existing = keymap.find_map_by_lhs(mode, keys)

    local done = true
    done = done and string.match(existing.rhs, vim.pesc('v:lua.cmp.utils.keymap.listen.run'))
    done = done and self.cache:get({ 'id', mode, bufnr, keys }) ~= nil
    if done then
      return
    end
    self.cache:set({ 'id', mode, bufnr, keys }, misc.id('cmp.utils.keymap.listen'))

    local fallback = keymap.evacuate(mode, keys)
    vim.api.nvim_buf_set_keymap(0, mode, keys, ('<Cmd>call v:lua.cmp.utils.keymap.listen.run(%s)<CR>'):format(self.cache:get({ 'id', mode, bufnr, keys })), {
      expr = false,
      noremap = true,
      silent = true,
      nowait = true,
    })

    self.cache:set({ 'definition', self.cache:get({ 'id', mode, bufnr, keys }) }, {
      keys = keys,
      mode = mode,
      bufnr = bufnr,
      callback = callback,
      fallback = fallback,
      existing = existing,
    })
  end,
})
misc.set(_G, { 'cmp', 'utils', 'keymap', 'listen', 'run' }, function(id)
  local definition = keymap.listen.cache:get({ 'definition', id })
  if definition.mode == 'c' and vim.fn.getcmdtype() == '=' then
    return vim.api.nvim_feedkeys(keymap.t(definition.fallback.keys), definition.fallback.mode, true)
  end
  definition.callback(
    definition.keys,
    misc.once(function()
      vim.api.nvim_feedkeys(keymap.t(definition.fallback.keys), definition.fallback.mode, true)
    end)
  )
  return keymap.t('<Ignore>')
end)

---Evacuate existing key mapping
---@param mode string
---@param lhs string
---@return { keys: string, mode: string }
keymap.evacuate = function(mode, lhs)
  local map = keymap.find_map_by_lhs(mode, lhs)

  -- Keep existing mapping as <Plug> mapping. We escape fisrt recursive key sequence. See `:help recursive_mapping`)
  local rhs = map.rhs
  if map.noremap == 0 and map.expr == 1 then
    -- remap & expr mapping should evacuate as <Plug> mapping with solving recursive mapping.
    rhs = string.format('v:lua.cmp.utils.keymap.evacuate.expr("%s", "%s", "%s")', mode, str.escape(keymap.escape(lhs), { '"' }), str.escape(keymap.escape(rhs), { '"' }))
  elseif map.noremap ~= 0 and map.expr == 1 then
    -- noremap & expr mapping should always evacuate as <Plug> mapping.
    rhs = rhs
  elseif map.script == 1 then
    -- script mapping should always evacuate as <Plug> mapping.
    rhs = rhs
  elseif map.noremap == 0 then
    -- remap & non-expr mapping should be checked if recursive or not.
    rhs = keymap.recursive(mode, lhs, rhs)
    if rhs == map.rhs or map.noremap ~= 0 then
      return { keys = rhs, mode = 'it' .. (map.noremap == 1 and 'n' or '') }
    end
  else
    -- noremap & non-expr mapping doesn't need to evacuate.
    return { keys = rhs, mode = 'it' .. (map.noremap == 1 and 'n' or '') }
  end

  local fallback = ('<Plug>(cmp-utils-keymap-evacuate-rhs:%s)'):format(map.lhs)
  vim.api.nvim_buf_set_keymap(0, mode, fallback, rhs, {
    expr = map.expr ~= 0,
    noremap = map.noremap ~= 0,
    script = map.script ~= 0,
    silent = true,
    nowait = true,
  })
  return { keys = fallback, mode = 'it' }
end
misc.set(_G, { 'cmp', 'utils', 'keymap', 'evacuate', 'expr' }, function(mode, lhs, rhs)
  return keymap.t(keymap.recursive(mode, lhs, vim.api.nvim_eval(rhs)))
end)

---Solve recursive mapping
---@param mode string
---@param lhs string
---@param rhs string
---@return string
keymap.recursive = function(mode, lhs, rhs)
  rhs = keymap.normalize(rhs)
  local fallback_lhs = ('<Plug>(cmp-utils-keymap-listen-lhs:%s)'):format(lhs)
  local new_rhs = string.gsub(rhs, '^' .. vim.pesc(keymap.normalize(lhs)), fallback_lhs)
  if not keymap.equals(new_rhs, rhs) then
    vim.api.nvim_buf_set_keymap(0, mode, fallback_lhs, lhs, {
      expr = false,
      noremap = true,
      silent = true,
      nowait = true,
    })
  end
  return new_rhs
end

---Get specific key mapping
---@param mode string
---@param lhs string
---@return table
keymap.find_map_by_lhs = function(mode, lhs)
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
    if keymap.equals(map.lhs, lhs) then
      return map
    end
  end
  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    if keymap.equals(map.lhs, lhs) then
      return map
    end
  end
  return {
    lhs = lhs,
    rhs = lhs,
    expr = 0,
    script = 0,
    noremap = 1,
    nowait = 0,
    silent = 1,
  }
end

keymap.spec = function()
  vim.fn.setreg('q', '')
  vim.cmd([[normal! qq]])
  vim.schedule(function()
    keymap.feedkeys('i', 'nt', function()
      keymap.feedkeys(keymap.t('foo2'), 'n')
      keymap.feedkeys(keymap.t('bar2'), 'nt')
      keymap.feedkeys(keymap.t('baz2'), 'n', function()
        vim.cmd([[normal! q]])
      end)
      keymap.feedkeys(keymap.t('baz1'), 'ni')
      keymap.feedkeys(keymap.t('bar1'), 'nti')
      keymap.feedkeys(keymap.t('foo1'), 'ni')
    end)
  end)
end

return keymap
