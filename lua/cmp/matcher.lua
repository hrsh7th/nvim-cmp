local char = require'cmp.utils.char'

local matcher = {}

matcher.WORD_BOUNDALY_ORDER_FACTOR = 5

matcher.PREFIX_FACTOR = 8
matcher.NOT_FUZZY_FACTOR = 6
matcher.EXACT_FACTOR = 12

--- score
--
-- ### The score
--
--   The `score` is `matched char count` generally.
--
--   But cmp will fix the score with some of the below points so the actual score is not `matched char count`.
--
--   1. Word boundary order
--
--     cmp prefers the match that near by word-beggining.
--
--   2. Strict case
--
--     cmp prefers strict match than ignorecase match.
--
--
-- ### Matching specs.
--
--   1. Prefix matching per word boundary
--
--     `bora`         -> `border-radius` # imaginary score: 4
--      ^^~~              ^^     ~~
--
--   2. Try sequential match first
--
--     `woroff`       -> `word_offset`   # imaginary score: 6
--      ^^^~~~            ^^^  ~~~
--
--     * The `woroff`'s second `o` should not match `word_offset`'s first `o`
--
--   3. Prefer early word boundary
--
--     `call`         -> `call`          # imaginary score: 4.1
--      ^^^^              ^^^^
--     `call`         -> `condition_all` # imaginary score: 4
--      ^~~~              ^         ~~~
--
--   4. Prefer strict match
--
--     `Buffer`       -> `Buffer`        # imaginary score: 6.1
--      ^^^^^^            ^^^^^^
--     `buffer`       -> `Buffer`        # imaginary score: 6
--      ^^^^^^            ^^^^^^
--
--   5. Use remaining characters for substring match
--
--     `fmodify`        -> `fnamemodify`   # imaginary score: 1
--      ^~~~~~~             ^    ~~~~~~
--
--   6. Avoid unexpected match detection
--
--     `candlesingle` -> candle#accept#single
--      ^^^^^^~~~~~~     ^^^^^^        ~~~~~~
--
--      * The `accept`'s `a` should not match to `candle`'s `a`
--
---Match entry
---@param input string
---@param word string
---@return number
matcher.match = function(input, word)
  -- Exact
  if input == word then
    return matcher.PREFIX_FACTOR + matcher.NOT_FUZZY_FACTOR + matcher.EXACT_FACTOR
  end

  -- Empty input
  if #input == 0 then
    return matcher.PREFIX_FACTOR + matcher.NOT_FUZZY_FACTOR
  end

  -- Ignore if input is long than word
  if #input > #word then
    return 0
  end

  --- Gather matched regions
  local matches = {}
  local input_start_index = 0
  local input_end_index = 1
  local word_index = 1
  local word_bound_index = 1
  while input_end_index <= #input and word_index <= #word do
    local m = matcher.find_match_region(input, input_start_index, input_end_index, word, word_index)
    if m and input_end_index <= m.input_match_end then
      m.index = word_bound_index
      input_start_index = m.input_match_start
      input_end_index = m.input_match_end + 1
      word_index = char.get_next_semantic_index(word, m.word_match_end)
      table.insert(matches, m)
    else
      word_index = char.get_next_semantic_index(word, word_index)
    end
    word_bound_index = word_bound_index + 1
  end

  if #matches == 0 then
    return 0
  end

  -- Compute prefix match score
  local score = 0
  local input_char_map = {}
  for _, m in ipairs(matches) do
    local s = 0
    for i = m.input_match_start, m.input_match_end do
      if not input_char_map[i] then
        s = s + 1
        input_char_map[i] = true
      end
    end
    if s > 0 then
      score = score + (s * (1 + math.max(0, matcher.WORD_BOUNDALY_ORDER_FACTOR - m.index) / matcher.WORD_BOUNDALY_ORDER_FACTOR))
      score = score + (m.strict_match and 0.1 or 0)
    end
  end

  -- Add prefix bonus
  score = score + ((matches[1].input_match_start == 1 and matches[1].word_match_start == 1) and matcher.PREFIX_FACTOR or 0)

  -- Check the word contains the remaining input. if not, it does not match.
  local last_match = matches[#matches]
  if last_match.input_match_end < #input then

    -- If input is remaining but all word consumed, it does not match.
    if last_match.word_match_end >= #word then
      return 0
    end

    for word_index = last_match.word_match_end + 1, #word do
      local word_offset = 0
      local input_index = last_match.input_match_end + 1
      local matched = false
      while word_offset + word_index <= #word and input_index <= #input do
        if char.match(string.byte(word, word_index + word_offset), string.byte(input, input_index)) then
          matched = true
          input_index = input_index + 1
        elseif matched then
          break
        end
        word_offset = word_offset + 1
      end
      if input_index - 1 == #input then
        return score
      end
    end
    return 0
  end

  return score
end

--- find_match_region
matcher.find_match_region = function(input, input_start_index, input_end_index, word, word_index)
  -- determine input position ( woroff -> word_offset )
  while input_start_index < input_end_index do
    if char.match(string.byte(input, input_end_index), string.byte(word, word_index)) then
      break
    end
    input_end_index = input_end_index - 1
  end

  -- Can't determine input position
  if input_start_index == input_end_index then
    return nil
  end

  local strict_match_count = 0
  local input_match_start = -1
  local input_index = input_end_index
  local word_offset = 0
  while input_index <= #input and word_index + word_offset <= #word do
    if char.match(string.byte(input, input_index), string.byte(word, word_index + word_offset)) then
      -- Match start.
      if input_match_start == -1 then
        input_match_start = input_index
      end

      -- Increase strict_match_count
      if string.byte(input, input_index) == string.byte(word, word_index + word_offset) then
        strict_match_count = strict_match_count + 1
      end

      word_offset = word_offset + 1
    elseif input_match_start ~= -1 then
      -- Match end (partial region)
      return {
        input_match_start = input_match_start;
        input_match_end = input_index - 1;
        word_match_start = word_index;
        word_match_end = word_index + word_offset - 1;
        strict_match = strict_match_count == input_index - input_match_start;
      }
    end
    input_index = input_index + 1
  end

  -- Match end (whole region)
  if input_match_start ~= -1 then
    return {
      input_match_start = input_match_start;
      input_match_end = input_index - 1;
      word_match_start = word_index;
      word_match_end = word_index + word_offset - 1;
      strict_match = strict_match_count == input_index - input_match_start;
    }
  end

  return nil
end

return matcher

