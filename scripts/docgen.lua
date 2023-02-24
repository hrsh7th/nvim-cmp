local docgen = require('docgen')

local docs = {}

docs.test = function()
  -- TODO: Fix the other files so that we can add them here.
  local input_files = {
    './lua/cmp/init.lua',

    -- TODO: This doesn't really make sense either at the moment
    -- './lua/cmp/config.lua',

    -- TODO: TJ needs to figure out why you can't compilet this :'(
    -- './lua/cmp/source.lua',
  }

  local output_file = './doc/nvim-cmp.txt'
  local output_file_handle = io.open(output_file, 'w')

  for _, input_file in ipairs(input_files) do
    docgen.write(input_file, output_file_handle)
  end

  output_file_handle:write(' vim:tw=78:ts=8:ft=help:norl:\n')
  output_file_handle:close()
  vim.cmd([[checktime]])
end

docs.test()

return docs
