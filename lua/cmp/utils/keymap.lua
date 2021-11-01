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

---Register keypress handler.
keymap.listen = setmetatable({
  cache = cache.new(),
}, {
  __call = function(self, mode, keys_or_chars, callback)
    local keys = keymap.normalize(keymap.to_keymap(keys_or_chars))
    local existing = keymap.get_mapping(mode, keys)
    if not existing then
      return
    end
    local bufnr = existing.buffer and vim.api.nvim_get_current_buf() or '*'
    self.cache:set({ 'id', mode, bufnr, keys }, misc.id('cmp.utils.keymap.listen'))

    local fallback = keymap.evacuate(mode, keys)
    if existing.buffer then
      vim.api.nvim_buf_set_keymap(0, mode, keys, ('<Cmd>call v:lua.cmp.utils.keymap.listen.run(%s)<CR>'):format(self.cache:get({ 'id', mode, bufnr, keys })), {
        expr = false,
        noremap = true,
        silent = true,
      })
    else
      vim.api.nvim_set_keymap(mode, keys, ('<Cmd>call v:lua.cmp.utils.keymap.listen.run(%s)<CR>'):format(self.cache:get({ 'id', mode, bufnr, keys })), {
        expr = false,
        noremap = true,
        silent = true,
      })
    end

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

---Get mapping
---@param mode string
---@param lhs string
---@return table
keymap.get_mapping = function(mode, lhs)
  lhs = keymap.normalize(lhs)

  for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
    if keymap.equals(map.lhs, lhs) then
      if string.match(map.rhs, vim.pesc('v:lua.cmp.utils.keymap.listen.run')) then
        return nil
      end
      return {
        lhs = map.lhs,
        rhs = map.rhs,
        expr = map.expr == 1,
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
      if string.match(map.rhs, vim.pesc('v:lua.cmp.utils.keymap.listen.run')) then
        return nil
      end
      return {
        lhs = map.lhs,
        rhs = map.rhs,
        expr = map.expr == 1,
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
    noremap = true,
    script = false,
    silent = false,
    nowait = false,
    buffer = false,
  }
end

---Evacuate existing key mapping
---@param mode string
---@param lhs string
---@return { keys: string, mode: string }
keymap.evacuate = function(mode, lhs)
  local map = keymap.get_mapping(mode, lhs)
  if not map then
    return { keys = lhs, mode = 'itn' }
  end

  -- Keep existing mapping as <Plug> mapping. We escape fisrt recursive key sequence. See `:help recursive_mapping`)
  local rhs = map.rhs
  if not map.noremap and map.expr then
    -- remap & expr mapping should evacuate as <Plug> mapping with solving recursive mapping.
    rhs = string.format('v:lua.cmp.utils.keymap.evacuate.expr("%s", "%s", "%s")', mode, str.escape(keymap.escape(lhs), { '"' }), str.escape(keymap.escape(rhs), { '"' }))
  elseif map.noremap and map.expr then
    -- noremap & expr mapping should always evacuate as <Plug> mapping.
    rhs = rhs
  elseif map.script then
    -- script mapping should always evacuate as <Plug> mapping.
    rhs = rhs
  elseif not map.noremap then
    -- remap & non-expr mapping should be checked if recursive or not.
    rhs = keymap.recursive(mode, lhs, rhs)
    if rhs == map.rhs or map.noremap then
      return { keys = rhs, mode = 'it' .. (map.noremap and 'n' or '') }
    end
  else
    -- noremap & non-expr mapping doesn't need to evacuate.
    return { keys = rhs, mode = 'it' .. (map.noremap and 'n' or '') }
  end

  local fallback = ('<Plug>(cmp-utils-keymap-evacuate-rhs:%s)'):format(map.lhs)
  vim.api.nvim_buf_set_keymap(0, mode, fallback, rhs, {
    expr = map.expr,
    noremap = map.noremap,
    script = map.script,
    silent = mode ~= 'c', -- I can't understand but it solves the #427 (wilder.nvim's mapping does not work if silent=true in cmdline mode...)
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
    })
  end
  return new_rhs
end

return keymap
