local highlight = {}

highlight.keys = {
  'fg',
  'bg',
  'bold',
  'italic',
  'reverse',
  'standout',
  'underline',
  'undercurl',
  'strikethrough',
}

highlight.inherit = function(name, source, settings)
  for _, key in ipairs(highlight.keys) do
    if not settings[key] then
      local v = vim.fn.synIDattr(vim.fn.hlID(source), key)
      if key ~= 'fg' and key ~= 'bg' then
        v = v == 1
      end
      if v then
        settings[key] = v == '' or 'NONE' or '0'
      end
    end
  end
  vim.api.nvim_set_hl(0, name, settings)
end

return highlight
