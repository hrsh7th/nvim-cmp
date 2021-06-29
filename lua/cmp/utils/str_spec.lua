local str = require "cmp.utils.str"

describe('utils.str', function()

  it('get_word', function()
    assert.are.equal(str.get_word('print'), 'print')
    assert.are.equal(str.get_word('$variable'), '$variable')
    assert.are.equal(str.get_word('print()'), 'print')
  end)

end)


