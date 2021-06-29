local global = require'cmp.utils.global'

local keymap = {}

---The mapping of vim notation and chars.
keymap.table = {
  ['<CR>'] = { "\n", "\r", "\r\n" },
  ['<Tab>'] = { "\t" },
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
  for key, chars in pairs(keymap.table) do
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
  if keymap.table[v] then
    return keymap.table[v][1]
  end
  return v
end

---Register keypress handler.
keymap.listen = setmetatable({
  cache = {}
}, {
  __call = function(_, char, callback)
    local key = keymap.to_key(char)
    if not key then
      return
    end

    if keymap.listen.cache[key] then
      return
    end

    local existing = nil
    for _, map in ipairs(vim.api.nvim_get_keymap('i')) do
      if map.lhs == key then
        existing = map
        break
      end
    end
    keymap.listen.cache[key] = {
      existing = existing,
      callback = callback,
    }

    vim.api.nvim_set_keymap('i', key, ('v:lua.cmp.utils.keymap.expr("%s")'):format(key), {
      expr = true,
      nowait = true,
      noremap = true,
    })
  end
})

global.set('cmp.utils.keymap.expr', function(char_or_key)
  local key = keymap.to_key(char_or_key)

  local callback = keymap.listen.cache[key].callback
  if not callback or not callback() then
    return keymap.t('<Ignore>')
  end

  local existing = keymap.listen.cache[key].existing
  if existing then
    vim.api.nvim_set_keymap('i', '<Plug>(cmp-utils-keymap:_)', existing.rhs, {
      expr = existing.expr == 1,
      noremap = existing.noremap == 1,
    })
    vim.fn.feedkeys(keymap.t('<Plug>(cmp-utils-keymap:_)'))
  else
    vim.fn.feedkeys(keymap.t(key), 'n')
  end

  return keymap.t('<Ignore>')
end)

return keymap

