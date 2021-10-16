local api = {}

api.is_insert_mode = function()
  return vim.tbl_contains({
    'i',
    'ic',
    'ix',
  }, vim.api.nvim_get_mode().mode)
end

api.is_cmdline_mode = function()
  return vim.tbl_contains({
    'c',
    'cv',
  }, vim.api.nvim_get_mode().mode)
end

api.is_terminal_mode = function()
  return vim.tbl_contains({
    't',
  }, vim.api.nvim_get_mode().mode)
end

api.is_suitable_mode = function()
  return api.is_insert_mode() or api.is_cmdline_mode() or api.is_terminal_mode()
end

api.get_current_line = function()
  if api.is_insert_mode() or api.is_terminal_mode() then
    return vim.api.nvim_get_current_line()
  elseif api.is_cmdline_mode() then
    return vim.fn.getcmdline()
  end
  return ''
end

api.get_cursor = function()
  if api.is_insert_mode() then
    return vim.api.nvim_win_get_cursor(0)
  elseif api.is_terminal_mode() then
    local cursor = vim.api.nvim_win_get_cursor(0)
    return { cursor[1], cursor[2] + 1 }
  elseif api.is_cmdline_mode() then
    return { vim.o.lines - (vim.api.nvim_get_option('cmdheight') or 1) + 1, vim.fn.getcmdpos() - 1 }
  end
  return { 1, 0 }
end

api.get_screen_cursor = function()
  local cursor = api.get_cursor()
  if api.is_insert_mode() or api.is_terminal_mode() then
    local pos = vim.fn.screenpos(0, cursor[1], cursor[2] + 1)
    return { pos.row, pos.col - 1 }
  elseif api.is_cmdline_mode() then
    return cursor
  end
  return { 1, 0 }
end

api.get_cursor_before_line = function()
  return string.sub(api.get_current_line(), 1, api.get_cursor()[2] + 1)
end

return api
