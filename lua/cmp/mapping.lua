local types = require('cmp.types')

local mapping = {}

---Create complete mapping
mapping.complete = function()
  return {
    type = 'complete',
  }
end

---Create close mapping
mapping.close = function()
  return {
    type = 'close',
  }
end

---Create scroll mapping
mapping.scroll = {
  up = function(delta)
    return {
      type = 'scroll.up',
      delta = delta or 4,
    }
  end,
  down = function(delta)
    return {
      type = 'scroll.down',
      delta = delta or 4,
    }
  end,
}

---Create item mapping
mapping.item = {
  prev = function()
    return {
      type = 'item.prev',
    }
  end,
  next = function()
    return {
      type = 'item.next',
    }
  end,
}

---Create confirm mapping
mapping.confirm = function(option)
  option = option or {}
  return {
    type = 'confirm',
    select = option.select or false,
    behavior = option.behavior or types.cmp.ConfirmBehavior.Insert,
  }
end

return mapping
