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

---Listen key pressed
---@param callback function
keymap.listen = function(callback)
  keymap._callback = callback
end

---Register keypress handler.
keymap.register = setmetatable({
  cache = cache.new(),
}, {
  __call = function(_, keys)
    keys = keymap.to_keymap(keys)

    local bufnr = vim.api.nvim_get_current_buf()
    if keymap.register.cache:get({ bufnr, keys }) then
      return
    end

    local existing = nil
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, 'i')) do
      if existing then
        break
      end
      if map.lhs == keys then
        existing = map
      end
    end
    for _, map in ipairs(vim.api.nvim_get_keymap('i')) do
      if existing then
        break
      end
      if map.lhs == keys then
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

    keymap.register.cache:set({ bufnr, keys }, {
      existing = existing,
    })
    vim.api.nvim_buf_set_keymap(0, 'i', keys, ('v:lua.cmp.keymap.expr("%s")'):format(keys), {
      expr = true,
      nowait = true,
      noremap = true,
    })
  end,
})

misc.set(_G, { 'cmp', 'keymap', 'expr' }, function(keys)
  keys = keymap.to_keymap(keys)
  local bufnr = vim.api.nvim_get_current_buf()

  local existing = keymap.register.cache:get({ bufnr, keys }).existing
  local fallback = function()
    vim.api.nvim_buf_set_keymap(0, 'i', '<Plug>(cmp-utils-keymap:_)', existing.rhs, {
      expr = existing.expr == 1,
      noremap = existing.noremap == 1,
    })
    vim.fn.feedkeys(keymap.t('<Plug>(cmp-utils-keymap:_)'), 'i')
  end
  keymap._callback(keys, fallback)
  return keymap.t('<Ignore>')
end)

return keymap
