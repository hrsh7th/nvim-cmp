local check = {}

check.ok = function()
  local ng = false
  local bt = vim.api.nvim_buf_get_option(0, 'buftype')
  ng = ng or bt == 'prompt'
  ng = ng or bt == 'nofile'
  ng = ng or string.sub(vim.api.nvim_get_mode().mode, 1, 1) ~= 'i'
  return not ng
end

check.wrap = function(callback)
  return function(...)
    if check.ok() then
      callback(...)
    end
  end
end

return check
