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
        keys = string.sub(keys, 1, i - 1) .. '<LT>' .. string.sub(keys, i + 1)
        i = i + 3
      end
    end
    i = i + 1
  end
  return keys
end

---Return upper case key sequence.
---@param keys string
---@return string
keymap.to_upper = function(keys)
  local result = {}
  local ctrl = false
  for i = 1, #keys do
    local c = string.sub(keys, i, i)
    if c == '<' then
      table.insert(result, c)
      ctrl = true
    elseif ctrl and c ~= '>' then
      table.insert(result, string.upper(c))
    elseif ctrl and c == '>' then
      table.insert(result, c)
      ctrl = false
    else
      table.insert(result, c)
    end
  end
  return table.concat(result, '')
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

---Return two key sequence are equal or not.
---@param a string
---@param b string
---@return boolean
keymap.equals = function(a, b)
  return keymap.t(a) == keymap.t(b)
end

---Feedkeys with callback
keymap.feedkeys = setmetatable({
  callbacks = {},
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
  end,
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
  __call = function(self, mode, keys, callback)
    keys = keymap.to_keymap(keys)

    local existing = keymap.find_map_by_lhs(mode, keys)
    if string.match(existing.rhs, '^.*' .. vim.pesc('v:lua.cmp.utils.keymap.listen.run') .. '.*$') then
      return
    end

    local fallback = keymap.evacuate(mode, keys)
    vim.api.nvim_buf_set_keymap(0, mode, keys, ('<Cmd>call v:lua.cmp.utils.keymap.listen.run("%s", "%s")<CR>'):format(mode, str.escape(keymap.escape(keys), { '"' })), {
      expr = false,
      noremap = true,
      silent = true,
      nowait = true,
    })

    local bufnr = vim.api.nvim_get_current_buf()
    self.cache:set({ mode, bufnr, keys }, {
      mode = mode,
      callback = callback,
      fallback = fallback,
      existing = existing,
    })
  end,
})
misc.set(_G, { 'cmp', 'utils', 'keymap', 'listen', 'run' }, function(mode, keys)
  local bufnr = vim.api.nvim_get_current_buf()
  local fallback = keymap.listen.cache:get({ mode, bufnr, keys }).fallback
  local callback = keymap.listen.cache:get({ mode, bufnr, keys }).callback
  callback(keys, function()
    keymap.feedkeys(keymap.t(fallback), 'i')
  end)
  return keymap.t('<Ignore>')
end)

---Evacuate existing key mapping
---@param mode string
---@param lhs string
---@return string
keymap.evacuate = function(mode, lhs)
  local map = keymap.find_map_by_lhs(mode, lhs)

  -- Keep existing mapping as <Plug> mapping. We escape fisrt recursive key sequence. See `:help recursive_mapping`)
  local rhs = map.rhs
  if map.noremap == 0 then
    if map.expr == 1 then
      rhs = string.format('v:lua.cmp.utils.keymap.evacuate.expr("%s", "%s", "%s")', mode, str.escape(keymap.escape(lhs), { '"' }), str.escape(keymap.escape(rhs), { '"' }))
    else
      rhs = keymap.recursive(mode, lhs, rhs)
    end
  end

  local fallback = ('<Plug>(cmp-utils-keymap-evacuate-rhs:%s)'):format(map.lhs)
  vim.api.nvim_buf_set_keymap(0, mode, fallback, rhs, {
    expr = map.expr ~= 0,
    noremap = map.noremap ~= 0,
    script = map.script ~= 0,
    silent = true,
    nowait = true,
  })
  return fallback
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
  rhs = keymap.to_upper(rhs)
  local fallback_lhs = ('<Plug>(cmp-utils-keymap-listen-lhs:%s)'):format(lhs)
  local new_rhs = string.gsub(rhs, '^' .. vim.pesc(keymap.to_upper(lhs)), fallback_lhs)
  if new_rhs ~= rhs then
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

return keymap
