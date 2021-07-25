local misc = require('cmp.utils.misc')
local cache = require('cmp.utils.cache')

local keymap = {}

---Default keypress handler
---@param _ string
---@param fallback function
keymap._callback = function(_, fallback)
  fallback()
end

---The mapping of vim notation and chars.
keymap._table = {
  ['<CR>'] = { '\n', '\r', '\r\n' },
  ['<Tab>'] = { '\t' },
}

---Shortcut for nvim_replace_termcodes
---@param keys string
---@return string
keymap.t = function(keys)
  return vim.api.nvim_replace_termcodes(keys, true, true, true)
end

---Return vim notation keymapping.
---@param v string
---@return string
keymap.to_key = function(v)
  for key, chars in pairs(keymap._table) do
    if vim.tbl_contains(chars, v) then
      return key
    end
  end
  return v
end

---Return vim notation keymapping.
---@param v string
---@return string
keymap.to_char = function(v)
  if keymap._table[v] then
    return keymap._table[v][1]
  end
  return v
end

---Listen key pressed
---@param callback function
keymap.listen = function(callback)
  keymap._callback = callback
end

---Register keypress handler.
keymap.register = setmetatable({
  cache = cache.new(),
}, {
  __call = function(_, char_or_key)
    local bufnr = vim.api.nvim_get_current_buf()
    local key = keymap.to_key(char_or_key)
    if keymap.register.cache:get({ bufnr, key }) then
      return
    end

    local existing = nil
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, 'i')) do
      if existing then
        break
      end
      if map.lhs == key then
        existing = map
      end
    end
    for _, map in ipairs(vim.api.nvim_get_keymap('i')) do
      if existing then
        break
      end
      if map.lhs == key then
        existing = map
        break
      end
    end
    existing = existing or {
      lhs = key,
      rhs = key,
      expr = 0,
      nowait = 0,
      noremap = 1,
    }

    keymap.register.cache:set({ bufnr, key }, {
      existing = existing,
    })
    vim.api.nvim_buf_set_keymap(0, 'i', key, ('v:lua.cmp.keymap.expr("%s")'):format(key), {
      expr = true,
      nowait = true,
      noremap = true,
    })
  end,
})

misc.set(_G, { 'cmp', 'keymap', 'expr' }, function(char_or_key)
  local bufnr = vim.api.nvim_get_current_buf()
  local key = keymap.to_key(char_or_key)

  local existing = keymap.register.cache:get({ bufnr, key }).existing
  local fallback = function()
    vim.api.nvim_buf_set_keymap(0, 'i', '<Plug>(cmp-utils-keymap:_)', existing.rhs, {
      expr = existing.expr == 1,
      noremap = existing.noremap == 1,
    })
    vim.fn.feedkeys(keymap.t('<Plug>(cmp-utils-keymap:_)'), 'i')
  end
  keymap._callback(keymap.to_char(key), fallback)
  return keymap.t('<Ignore>')
end)

return keymap
