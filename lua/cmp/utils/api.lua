local api = {}

api.in_insert_enter_autocmd = nil

api.get_mode = function()
  if api.is_insert_mode() then
    return 'i'
  elseif api.is_visual_mode() then
    return 'x'
  elseif api.is_select_mode() then
    return 's'
  elseif api.is_cmdline_mode() then
    return 'c'
  end
end

api.is_insert_mode = function()
  return vim.tbl_contains({
    'i',
    'ic',
    'ix',
  }, vim.api.nvim_get_mode().mode)
end

api.is_cmdline_mode = function()
  local is_cmdline_mode = vim.tbl_contains({
    'c',
    'cv',
  }, vim.api.nvim_get_mode().mode)
  return is_cmdline_mode and vim.fn.getcmdtype() ~= '='
end

api.is_select_mode = function()
  return vim.tbl_contains({
    's',
    'S',
  }, vim.api.nvim_get_mode().mode)
end

api.is_visual_mode = function()
  return vim.tbl_contains({
    'v',
    'V',
  }, vim.api.nvim_get_mode().mode)
end

api.is_suitable_mode = function()
  return api.is_insert_mode() or api.is_cmdline_mode()
end

api.get_current_line = function()
  if api.is_cmdline_mode() then
    return vim.fn.getcmdline()
  end
  return vim.api.nvim_get_current_line()
end

api.get_cursor = function()
  if api.is_cmdline_mode() then
    return { vim.o.lines - (vim.api.nvim_get_option('cmdheight') or 1) + 1, vim.fn.getcmdpos() - 1 }
  end
  return vim.api.nvim_win_get_cursor(0)
end

api.get_screen_cursor = function()
  if api.is_cmdline_mode() then
    return api.get_cursor()
  end
  local cursor = api.get_cursor()
  local pos = vim.fn.screenpos(0, cursor[1], cursor[2] + 1)
  return { pos.row, pos.col - 1 }
end

api.get_cursor_before_line = function()
  local cursor = api.get_cursor()
  return string.sub(api.get_current_line(), 1, cursor[2] + 1)
end

return api
