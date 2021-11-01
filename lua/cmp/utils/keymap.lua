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

---Create autoindent keys
---@return string
keymap.autoindent = function()
  local keys = {}
  table.insert(keys, keymap.t('<Cmd>setlocal indentkeys+=!^F<CR>'))
  table.insert(keys, keymap.t('<C-f>'))
  table.insert(keys, keymap.t('<Cmd>setlocal indentkeys=%s<CR>'):format(vim.bo.indentkeys))
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
keymap.listen = function(mode, keys_or_chars, callback)
  local keys = keymap.normalize(keymap.to_keymap(keys_or_chars))
  local existing = keymap.get_mapping(mode, keys)
  if string.find(existing.rhs, 'v:lua.cmp.utils.keymap', 1, true) then
    return
  end
  local bufnr = existing.buffer and vim.api.nvim_get_current_buf() or -1
  local fallback = keymap.evacuate(bufnr, mode, keys)
  keymap.set_map(bufnr, mode, keys, function()
    if mode == 'c' and vim.fn.getcmdtype() == '=' then
      return vim.api.nvim_feedkeys(keymap.t(fallback.keys), fallback.mode, true)
    end

    callback(keys, misc.once(function()
      vim.api.nvim_feedkeys(keymap.t(fallback.keys), fallback.mode, true)
    end))
  end, {
    expr = false,
    noremap = true,
    silent = true,
  })
end

---Get mapping
---@param mode string
---@param lhs string
---@return table
keymap.get_mapping = function(mode, lhs)
  lhs = keymap.normalize(lhs)

  for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
    if keymap.equals(map.lhs, lhs) then
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
---@param bufnr number
---@param mode string
---@param keys string
---@return { keys: string, mode: string }
keymap.evacuate = function(bufnr, mode, keys)
  local map = keymap.get_mapping(mode, keys)
  if not map then
    return { keys = keys, mode = 'itn' }
  end

  -- Keep existing mapping as <Plug> mapping. We escape fisrt recursive key sequence. See `:help recursive_mapping`)
  local rhs = map.rhs
  if not map.noremap and map.expr then
    -- remap & expr mapping should evacuate as <Plug> mapping with solving recursive mapping.
    rhs = function()
      return keymap.t(keymap.recursive(bufnr, mode, keys, vim.api.nvim_eval(rhs)))
    end
  elseif map.noremap and map.expr then
    -- noremap & expr mapping should always evacuate as <Plug> mapping.
    rhs = rhs
  elseif map.script then
    -- script mapping should always evacuate as <Plug> mapping.
    rhs = rhs
  elseif not map.noremap then
    -- remap & non-expr mapping should be checked if recursive or not.
    rhs = keymap.recursive(bufnr, mode, keys, rhs)
    if rhs == map.rhs or map.noremap then
      return { keys = rhs, mode = 'it' .. (map.noremap and 'n' or '') }
    end
  else
    -- noremap & non-expr mapping doesn't need to evacuate.
    return { keys = rhs, mode = 'it' .. (map.noremap and 'n' or '') }
  end

  local fallback = ('<Plug>(cmp-utils-keymap-evacuate-rhs:%s)'):format(map.lhs)
  keymap.set_map(bufnr, mode, fallback, rhs, {
    expr = map.expr,
    noremap = map.noremap,
    script = map.script,
    silent = mode ~= 'c', -- I can't understand but it solves the #427 (wilder.nvim's mapping does not work if silent=true in cmdline mode...)
  })
  return { keys = fallback, mode = 'it' }
end

---Solve recursive mapping
---@param bufnr number
---@param mode string
---@param keys string
---@param rhs string
---@return string
keymap.recursive = function(bufnr, mode, keys, rhs)
  rhs = keymap.normalize(rhs)

  local fallback_lhs = ('<Plug>(cmp.utils.keymap.recursive:%s)'):format(keys)
  local new_rhs = string.gsub(rhs, '^' .. vim.pesc(keymap.normalize(keys)), fallback_lhs)
  if not keymap.equals(new_rhs, rhs) then
    keymap.set_map(bufnr, mode, fallback_lhs, keys, {
      expr = false,
      noremap = true,
      silent = true,
    })
  end
  return new_rhs
end

---Set keymapping
keymap.set_map = function(bufnr, mode, keys, target, opts)
  local resolved = keymap.resolve(target, opts)
  if bufnr == -1 then
    vim.api.nvim_set_keymap(mode, keys, resolved, opts)
  else
    vim.api.nvim_buf_set_keymap(bufnr, mode, keys, resolved, opts)
  end
end

---Resolve rhs string
---@param callback function
---@param opts any
---@return string
keymap.resolve = setmetatable({
  callbacks = {},
}, {
  __call = function(self, target, opts)
    if type(target) == 'string' then
      return target
    end

    local id = misc.id('cmp.utils.keymap.resolve')
    self.callbacks[id] = target
    if opts.expr then
      return ('v:lua.cmp.utils.keymap.resolve(%s)'):format(id)
    end
    return ('<Cmd>call v:lua.cmp.utils.keymap.resolve(%s)<CR>'):format(id)
  end,
})
misc.set(_G, { 'cmp', 'utils', 'keymap', 'resolve' }, function(id)
  return keymap.resolve.callbacks[id]()
end)

return keymap
