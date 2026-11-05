local misc = require('cmp.utils.misc')
local buffer = require('cmp.utils.buffer')
local api = require('cmp.utils.api')

local keymap = {}

---Shortcut for nvim_replace_termcodes
---@param keys string
---@return string
keymap.t = function(keys)
  return (string.gsub(keys, "(<[A-Za-z0-9\\%-%[%]%^@;,:_'`%./]->)", function(match)
    return vim.api.nvim_eval(string.format([["\%s"]], match))
  end))
end

---Normalize key sequence.
---@param keys string
---@return string
keymap.normalize = vim.fn.has('nvim-0.8') == 1 and function(keys)
    local t = string.gsub(keys, "<([A-Za-z0-9\\%-%[%]%^@;,:_'`%./]-)>", function(match)
      -- Use the \<* notation, which distinguishes <C-J> from <NL>, etc.
      return vim.api.nvim_eval(string.format([["\<*%s>"]], match))
    end)
    return vim.fn.keytrans(t)
  end or function(keys)
    local normalize_buf = buffer.ensure('cmp.util.keymap.normalize')
    vim.api.nvim_buf_set_keymap(normalize_buf, 't', keys, '<Plug>(cmp.utils.keymap.normalize)', {})
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(normalize_buf, 't')) do
      if keymap.t(map.rhs) == keymap.t('<Plug>(cmp.utils.keymap.normalize)') then
        vim.api.nvim_buf_del_keymap(normalize_buf, 't', keys)
        return map.lhs
      end
    end
    vim.api.nvim_buf_del_keymap(normalize_buf, 't', keys)
    vim.api.nvim_buf_delete(normalize_buf, {})
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
---@param count string|integer
---@return string
keymap.backspace = function(count)
  if type(count) == 'string' then
    count = vim.fn.strchars(count, true)
  end
  if count <= 0 then
    return ''
  end
  local keys = {}
  table.insert(keys, keymap.t(string.rep('<BS>', count)))
  return table.concat(keys, '')
end

---Create delete keys.
---@param count string|integer
---@return string
keymap.delete = function(count)
  if type(count) == 'string' then
    count = vim.fn.strchars(count, true)
  end
  if count <= 0 then
    return ''
  end
  local keys = {}
  table.insert(keys, keymap.t(string.rep('<Del>', count)))
  return table.concat(keys, '')
end

---Update indentkeys.
---@param expr? string
---@return string
keymap.indentkeys = function(expr)
  return string.format(keymap.t('<Cmd>set indentkeys=%s<CR>'), expr and vim.fn.escape(expr, '| \t\\') or '')
end

---Return two key sequence are equal or not.
---@param a string
---@param b string
---@return boolean
keymap.equals = function(a, b)
  return keymap.normalize(a) == keymap.normalize(b)
end

local is_abbreviation_mode = function(mode)
  local current = vim.api.nvim_get_mode().mode:sub(1, 1)
  if mode == 'i' then
    return current == 'i' or current == 'R'
  end
  return mode == 'c' and api.get_mode() == 'c'
end

---Return whether text before the cursor matches a defined abbreviation.
---@param mode string
---@param text? string
---@return boolean
keymap.has_abbreviation = function(mode, text)
  if not is_abbreviation_mode(mode) then
    return false
  end

  text = vim.fn.matchstr(text or api.get_cursor_before_line(), [[\S\+$]])
  if text == '' then
    return false
  end

  local is_keyword = function(char)
    return vim.fn.match(char, [[\k]]) == 0
  end

  local count = vim.fn.strchars(text)
  -- A keyword-ending abbreviation is either all keyword characters or non-keyword characters plus the final one.
  if count > 1 and is_keyword(vim.fn.strcharpart(text, count - 1, 1)) then
    if is_keyword(vim.fn.strcharpart(text, count - 2, 1)) then
      text = vim.fn.matchstr(text, [[\k\+$]])
    else
      text = vim.fn.matchstr(text, [[\%(\k\@!\S\)\+\k$]])
    end
  end

  return next(vim.fn.maparg(text, mode, true, true)) ~= nil
end

local first_key = function(lhs)
  local normalized = keymap.normalize(lhs)
  return string.match(normalized, '^<[^>]+>') or vim.fn.strcharpart(normalized, 0, 1)
end

local split_keys = function(lhs)
  local keys = {}
  local normalized = keymap.normalize(lhs)
  while normalized ~= '' do
    local key = string.match(normalized, '^<[^>]+>') or vim.fn.strcharpart(normalized, 0, 1)
    table.insert(keys, key)
    normalized = vim.fn.strcharpart(normalized, vim.fn.strchars(key))
  end
  return keys
end

local inserted_text_keys = {
  ['<CR>'] = '\n',
  ['<C-M>'] = '\n',
  ['<NL>'] = '\n',
  ['<C-J>'] = '\n',
  ['<Tab>'] = '\t',
  ['<C-I>'] = '\t',
  ['<S-Tab>'] = '\t',
  ['<S-Space>'] = ' ',
  ['<kEnter>'] = '\n',
  ['<kPlus>'] = '+',
  ['<kMinus>'] = '-',
  ['<kMultiply>'] = '*',
  ['<kDivide>'] = '/',
  ['<kPoint>'] = '.',
  ['<kComma>'] = ',',
  ['<kEqual>'] = '=',
  ['<k0>'] = '0',
  ['<k1>'] = '1',
  ['<k2>'] = '2',
  ['<k3>'] = '3',
  ['<k4>'] = '4',
  ['<k5>'] = '5',
  ['<k6>'] = '6',
  ['<k7>'] = '7',
  ['<k8>'] = '8',
  ['<k9>'] = '9',
}

local inserted_text = function(lhs)
  local name = keymap.normalize(lhs)
  if inserted_text_keys[name] then
    return inserted_text_keys[name]
  end

  local key = keymap.t(lhs)
  if vim.fn.strchars(key) == 1 and vim.fn.char2nr(key) >= 0x20 then
    return key
  end
end

---Return whether a key normally triggers abbreviation expansion.
---@param lhs string
---@return boolean
keymap.triggers_abbreviation = function(lhs)
  lhs = first_key(lhs)
  local name = keymap.normalize(lhs)

  if vim.tbl_contains({ '<Esc>', '<C-[>', '<C-]>', '<C-O>', '<S-Tab>' }, name) then
    return true
  end

  local text = inserted_text(lhs)
  return text ~= nil and vim.fn.match(text, [[\k]]) ~= 0
end

---Insert explicit abbreviation expansion at the positions where a default key
---sequence would trigger it. This is computed at keypress time so a delayed
---fallback cannot expand text inserted by a completion callback.
---@param mode string
---@param lhs string
---@return string
keymap.expand_abbreviations = function(mode, lhs)
  if not is_abbreviation_mode(mode) then
    return keymap.t(lhs)
  end

  local text = api.get_cursor_before_line()
  local predictable = true
  local force_expansion_checks = false
  local active = true
  local keys = {}

  for _, key in ipairs(split_keys(lhs)) do
    local trigger = active and keymap.triggers_abbreviation(key)
    local explicit_expansion = keymap.equals(key, '<C-]>')
    local abbreviation = trigger and (force_expansion_checks or (predictable and keymap.has_abbreviation(mode, text)))
    if abbreviation and not explicit_expansion then
      table.insert(keys, '<C-]>')
    end
    table.insert(keys, key)

    if active and explicit_expansion then
      if abbreviation then
        -- The explicit expansion inserts no delimiter, so its replacement can
        -- only be checked by preserving all later trigger points.
        predictable = false
        force_expansion_checks = true
      end
    elseif active and predictable then
      local inserted = inserted_text(key)
      if inserted == nil then
        predictable = false
      elseif abbreviation then
        -- The expansion text is unknown, but the inserted delimiter is enough
        -- to detect a later abbreviation built by the remaining literal keys.
        text = inserted
      else
        text = text .. inserted
      end
    end

    local name = keymap.normalize(key)
    if vim.tbl_contains({ '<Esc>', '<C-[>', '<C-C>', '<C-O>' }, name) or (mode == 'c' and vim.tbl_contains({ '<CR>', '<C-M>', '<NL>', '<C-J>', '<kEnter>' }, name)) then
      active = false
    end
  end

  return keymap.t(table.concat(keys, ''))
end

---Register keypress handler.
keymap.listen = function(mode, lhs, callback)
  lhs = keymap.normalize(keymap.to_keymap(lhs))

  local existing = keymap.get_map(mode, lhs)
  if existing.desc == 'cmp.utils.keymap.set_map' then
    return
  end

  local bufnr = existing.buffer and vim.api.nvim_get_current_buf() or -1
  keymap.set_map(bufnr, mode, lhs, function()
    local abbreviation_keys = existing.default and keymap.expand_abbreviations(mode, existing.lhs) or nil
    local fallback = keymap.fallback(bufnr, mode, existing, abbreviation_keys)
    local ignore = false
    ignore = ignore or (mode == 'c' and vim.fn.getcmdtype() == '=')
    if ignore then
      fallback()
    else
      callback(lhs, misc.once(fallback))
    end
  end, {
    expr = false,
    noremap = true,
    silent = true,
  })
end

---Fallback
---@param abbreviation_keys? string
keymap.fallback = function(bufnr, mode, map, abbreviation_keys)
  return function()
    if map.expr then
      local fallback_lhs = string.format('<Plug>(cmp.u.k.fallback_expr:%s)', map.lhs)
      keymap.set_map(bufnr, mode, fallback_lhs, function()
        return keymap.solve(bufnr, mode, map, abbreviation_keys).keys
      end, {
        expr = true,
        noremap = map.noremap,
        script = map.script,
        nowait = map.nowait,
        silent = map.silent and mode ~= 'c',
        replace_keycodes = map.replace_keycodes,
      })
      vim.api.nvim_feedkeys(keymap.t(fallback_lhs), 'im', true)
    elseif map.callback then
      map.callback()
    else
      local solved = keymap.solve(bufnr, mode, map, abbreviation_keys)
      vim.api.nvim_feedkeys(solved.keys, solved.mode, true)
    end
  end
end

---Solve
---@param abbreviation_keys? string
keymap.solve = function(bufnr, mode, map, abbreviation_keys)
  local lhs = keymap.t(map.lhs)
  local rhs = keymap.t(map.rhs)
  if map.expr then
    if map.callback then
      rhs = map.callback()
    else
      rhs = vim.api.nvim_eval(keymap.t(map.rhs))
    end
  end

  if map.default then
    -- `noremap` suppresses abbreviations, so preserve the sequence captured at
    -- keypress (or compute it now for direct fallback calls).
    rhs = abbreviation_keys or keymap.expand_abbreviations(mode, map.lhs)
  end

  if map.noremap then
    return { keys = rhs, mode = 'in' }
  end

  if string.find(rhs, lhs, 1, true) == 1 then
    local recursive = string.format('<SNR>0_(cmp.u.k.recursive:%s)', lhs)
    keymap.set_map(bufnr, mode, recursive, lhs, {
      noremap = true,
      script = true,
      nowait = map.nowait,
      silent = map.silent and mode ~= 'c',
      replace_keycodes = map.replace_keycodes,
    })
    return { keys = keymap.t(recursive) .. string.gsub(rhs, '^' .. vim.pesc(lhs), ''), mode = 'im' }
  end
  return { keys = rhs, mode = 'im' }
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
        desc = map.desc,
        noremap = map.noremap == 1,
        script = map.script == 1,
        silent = map.silent == 1,
        nowait = map.nowait == 1,
        buffer = true,
        replace_keycodes = map.replace_keycodes == 1,
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
        desc = map.desc,
        noremap = map.noremap == 1,
        script = map.script == 1,
        silent = map.silent == 1,
        nowait = map.nowait == 1,
        buffer = false,
        replace_keycodes = map.replace_keycodes == 1,
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
    replace_keycodes = true,
    default = true,
  }
end

---Set keymapping
keymap.set_map = function(bufnr, mode, lhs, rhs, opts)
  if type(rhs) == 'function' then
    opts.callback = rhs
    rhs = ''
  end
  opts.desc = 'cmp.utils.keymap.set_map'

  if vim.fn.has('nvim-0.8') == 0 then
    opts.replace_keycodes = nil
  end

  if bufnr == -1 then
    vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
  else
    vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)
  end
end

return keymap
