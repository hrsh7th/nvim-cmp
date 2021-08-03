local misc = require('cmp.utils.misc')
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

---Feedkeys with callback
keymap.feedkeys = setmetatable({
  callbacks = {},
}, {
__call = function(self, keys, mode, callback)
    vim.fn.feedkeys(keymap.t(keys), mode)

    if callback then
      local current_mode = string.sub(vim.api.nvim_get_mode().mode, 1, 1)
      local id = misc.id('cmp.utils.keymap.feedkeys')
      local cb = ('<Plug>(cmp-utils-keymap-feedkeys:%s)'):format(id)
      self.callbacks[id] = function()
        callback()
        vim.api.nvim_buf_del_keymap(0, current_mode, cb)
        return keymap.t('<Ignore>')
      end
      vim.api.nvim_buf_set_keymap(0, current_mode, cb, ('v:lua.cmp.utils.keymap.feedkeys.expr(%s)'):format(id), {
        expr = true,
        nowait = true,
        silent = true,
      })
      vim.fn.feedkeys(keymap.t(cb), '')
    end
  end
})
misc.set(_G, { 'cmp', 'utils', 'keymap', 'feedkeys', 'expr' }, function(id)
  if keymap.feedkeys.callbacks[id] then
    keymap.feedkeys.callbacks[id]()
  end
  return keymap.t('<Ignore>')
end)

---Register keypress handler.
keymap.listen = setmetatable({
  cache = cache.new(),
}, {
  __call = function(_, keys, callback)
    keys = keymap.to_keymap(keys)

    local bufnr = vim.api.nvim_get_current_buf()
    if keymap.listen.cache:get({ bufnr, keys }) then
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

    keymap.listen.cache:set({ bufnr, keys }, {
      existing = existing,
      callback = callback,
    })
    vim.api.nvim_buf_set_keymap(0, 'i', keys, ('v:lua.cmp.utils.keymap.expr("%s")'):format(keys), {
      expr = true,
      nowait = true,
      noremap = true,
    })
  end,
})
misc.set(_G, { 'cmp', 'utils', 'keymap', 'expr' }, function(keys)
  keys = keymap.to_keymap(keys)
  local bufnr = vim.api.nvim_get_current_buf()

  local existing = keymap.listen.cache:get({ bufnr, keys }).existing
  local callback = keymap.listen.cache:get({ bufnr, keys }).callback
  callback(keys, function()
    vim.api.nvim_buf_set_keymap(0, 'i', '<Plug>(cmp-utils-keymap:_)', existing.rhs, {
      expr = existing.expr == 1,
      noremap = existing.noremap == 1,
    })
    vim.fn.feedkeys(keymap.t('<Plug>(cmp-utils-keymap:_)'), 'i')
  end)
  return keymap.t('<Ignore>')
end)

return keymap

