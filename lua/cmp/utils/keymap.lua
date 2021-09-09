local misc = require('cmp.utils.misc')
local str = require('cmp.utils.str')
local cache = require('cmp.utils.cache')

local keymap = {}

---The mapping of vim notation and chars.
keymap._table = {
  ['<CR>'] = { '\n', '\r', '\r\n' },
  ['<Tab>'] = { '\t' },
  ['<BSlash>'] = { '\\' },
  ['<Bar>'] = { '|' },
  ['<Space>'] = { ' ' },
}

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
        keys = string.sub(keys, 1, i -1) .. '<LT>' ..  string.sub(keys, i + 1)
        i = i + 3
      end
    end
    i = i + 1
  end
  return keys
end

---Return vim notation keymapping (simple conversion).
---@param s string
---@return string
keymap.to_keymap = function(s)
  return string.gsub(s, '.', function(c)
    for key, chars in pairs(keymap._table) do
      if vim.tbl_contains(chars, c) then
        return key
      end
    end
    return c
  end)
end

--- Replace key in keys except in the <C-r> or <Cmd> sequence.
keymap.replace = function(keys, key, rep)
  local expr = false
  local new_keys = {}
  local i = 1
  while i <= #keys do
    if '<C-R>=' == string.sub(keys, i, i + #'<C-R>=' - 1) then
      table.insert(new_keys, '<C-R>=')
      expr = true
      i = i + #'<C-R>='
    elseif '<Cmd>' == string.sub(keys, i, i + #'<Cmd>' - 1) then
      table.insert(new_keys, '<Cmd>')
      expr = true
      i = i + #'<Cmd>'
    elseif expr and '<CR>' == string.sub(keys, i, i + #'<CR>' - 1) then
      table.insert(new_keys, '<CR>')
      i = i + #'<CR>'
      expr = false
    elseif not expr and key == string.sub(keys, i, i + #key - 1) then
      table.insert(new_keys, rep)
      i = i + #key
    else
      table.insert(new_keys, string.sub(keys, i, i))
      i = i + 1
    end
  end
  return table.concat(new_keys, '')
end

---Feedkeys with callback
keymap.feedkeys = setmetatable({
  callbacks = {}
}, {
  __call = function(self, keys, mode, callback)
    if #keys ~= 0 then
      vim.api.nvim_feedkeys(keys, mode, true)
    end

    if callback then
      if vim.fn.reg_recording() == '' then
        local id = misc.id('cmp.utils.keymap.feedkeys')
        self.callbacks[id] = callback
        vim.api.nvim_feedkeys(keymap.t('<Cmd>call v:lua.cmp.utils.keymap.feedkeys.run(%s)<CR>'):format(id), 'n', true)
      else
        -- Does not feed extra keys if macro recording.
        local wait
        wait = vim.schedule_wrap(function()
          if vim.fn.getchar(1) == 0 then
            return callback()
          end
          vim.defer_fn(wait, 1)
        end)
        wait()
      end
    end
  end
})
misc.set(_G, { 'cmp', 'utils', 'keymap', 'feedkeys', 'run' }, function(id)
  if keymap.feedkeys.callbacks[id] then
    keymap.feedkeys.callbacks[id]()
    keymap.feedkeys.callbacks[id] = nil
  end
  return ''
end)

---Register keypress handler.
keymap.listen = setmetatable({
  cache = cache.new(),
}, {
  __call = function(_, mode, keys, callback)
    keys = keymap.to_keymap(keys)

    local bufnr = vim.api.nvim_get_current_buf()
    if keymap.listen.cache:get({ mode, bufnr, keys }) then
      return
    end

    local existing = nil
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
      if existing then
        break
      end
      if keymap.t(map.lhs) == keymap.t(keys) then
        existing = map
      end
    end
    for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
      if existing then
        break
      end
      if keymap.t(map.lhs) == keymap.t(keys) then
        existing = map
        break
      end
    end
    existing = existing or {
      lhs = keys,
      rhs = keys,
      expr = 0,
      nowait = 0,
      noremap = 1,
    }

    keymap.listen.cache:set({ mode, bufnr, keys }, {
      mode = mode,
      existing = existing,
      callback = callback,
    })
    vim.api.nvim_buf_set_keymap(0, mode, keys, ('<Cmd>call v:lua.cmp.utils.keymap.listen.run("%s", "%s")<CR>'):format(mode, str.escape(keymap.escape(keys), { '"' })), {
      expr = false,
      nowait = true,
      noremap = true,
      silent = true,
    })
  end,
})
misc.set(_G, { 'cmp', 'utils', 'keymap', 'listen', 'run' }, function(mode, keys)
  local bufnr = vim.api.nvim_get_current_buf()

  local existing = keymap.listen.cache:get({ mode, bufnr, keys }).existing
  local callback = keymap.listen.cache:get({ mode, bufnr, keys }).callback
  callback(keys, function()
    local rhs = existing.rhs
    if existing.noremap == 0 then
      vim.api.nvim_buf_set_keymap(0, mode, '<Plug>(cmp-utils-keymap-listen-run:lhs)', existing.lhs, {
        expr = false,
        noremap = true,
        silent = true,
      })
      rhs = keymap.replace(rhs, existing.lhs, '<Plug>(cmp-utils-keymap-listen-run:lhs)')
    end
    vim.api.nvim_buf_set_keymap(0, mode, '<Plug>(cmp-utils-keymap-listen-run:_)', rhs, {
      expr = existing.expr ~= 0,
      noremap = existing.noremap ~= 0,
      script = existing.script ~= 0,
      silent = true,
    })
    keymap.feedkeys(keymap.t('<Plug>(cmp-utils-keymap-listen-run:_)'), '')
  end)
  return keymap.t('<Ignore>')
end)

return keymap

