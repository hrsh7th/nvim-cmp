local str = require('cmp.utils.str')

describe('utils.str', function()
  it('get_word', function()
    assert.are.equal(str.get_word('print'), 'print')
    assert.are.equal(str.get_word('$variable'), '$variable')
    assert.are.equal(str.get_word('print()'), 'print')
    assert.are.equal(str.get_word('["cmp#confirm"]'), '["cmp#confirm"]')
    assert.are.equal(str.get_word('"devDependencies":', string.byte('"')), '"devDependencies')
    assert.are.equal(str.get_word('"devDependencies": ${1},', string.byte('"')), '"devDependencies')
    assert.are.equal(str.get_word('#[cfg(test)]'), '#[cfg(test)]')
    assert.are.equal(str.get_word('import { GetStaticProps$1 } from "next";', nil, 9), 'import { GetStaticProps')
  end)

  it('remove_suffix', function()
    assert.are.equal(str.remove_suffix('log()', '$0'), 'log()')
    assert.are.equal(str.remove_suffix('log()$0', '$0'), 'log()')
    assert.are.equal(str.remove_suffix('log()${0}', '${0}'), 'log()')
    assert.are.equal(str.remove_suffix('log()${0:placeholder}', '${0}'), 'log()${0:placeholder}')
  end)

  it('escape', function()
    assert.are.equal(str.escape('plain', {}), 'plain')
    assert.are.equal(str.escape('plain\\', {}), 'plain\\\\')
    assert.are.equal(str.escape('plain\\"', {}), 'plain\\\\"')
    assert.are.equal(str.escape('pla"in', { '"' }), 'pla\\"in')
    assert.are.equal(str.escape('call("")', { '"' }), 'call(\\"\\")')
  end)

  it('get_common_string', function()
    -- ASCII tests
    assert.are.equal(str.get_common_string('hello', 'help'), 'hel')
    assert.are.equal(str.get_common_string('abc', 'xyz'), '')
    assert.are.equal(str.get_common_string('test', 'Testing'), 'test')

    -- Unicode tests
    assert.are.equal(str.get_common_string('получаем', 'получив'), 'получ')
    assert.are.equal(str.get_common_string('тест', 'тестинг'), 'тест')
    assert.are.equal(str.get_common_string('тест', 'Тестинг'), 'тест')
    assert.are.equal(str.get_common_string('Тест', 'тестинг'), 'Тест')
    assert.are.equal(str.get_common_string('тЕст', 'тестинг'), 'тЕст')
    assert.are.equal(str.get_common_string('тест', 'тЕстинг'), 'тест')
    assert.are.equal(str.get_common_string('тесТ', 'тЕстинг'), 'тесТ')
    assert.are.equal(str.get_common_string('тест', 'тесТинг'), 'тест')
    assert.are.equal(str.get_common_string('а', 'я'), '') -- 0xD0 0xB0 - 0xD1 0x8F
    assert.are.equal(str.get_common_string('а', 'б'), '') -- 0xD0 0xB0 - 0xD0 0xB1
    assert.are.equal(str.get_common_string('Я', 'я'), 'Я') -- 0xD0 0xAF - 0xD1 0x8F
    assert.are.equal(str.get_common_string('А', 'а'), 'А') -- 0xD0 0x90 - 0xD0 0xB0
    -- Normalization is not supported yet
    assert.are.equal(str.get_common_string('й', 'и'), '') -- 0xD0 0xB9 - 0xD0 0xB8
    assert.are.equal(str.get_common_string('й', 'и'), 'и') -- 0xD0 0xB8 0xD1 0x8E - 0xD0 0xB8
  end)
end)
