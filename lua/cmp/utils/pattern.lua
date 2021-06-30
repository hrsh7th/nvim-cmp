local pattern = {}

pattern._regexes = {}

pattern.regex = function(p)
  if not pattern._regexes[p] then
    pattern._regexes[p] = vim.regex(p)
  end
  return pattern._regexes[p]
end

pattern.offset = function(p, text)
  local s, e = pattern.regex(p):match_str(text)
  if s then
    return s + 1, e + 1
  end
  return nil, nil
end

return pattern

