import sys

_numbers = '0123456789' # [chr(c) for c in range(48, 58)]
_symbols = ':-+<=>$.!?'
_letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' # [chr(c) for c in range(65, 91)]
_character_map = _numbers + _symbols + _letters

def code(c):
    idx = _character_map.index(c)
    lo = idx % 2
    offset = ((idx - lo) << 2) + lo
    return offset

for word in sys.argv[1:]:
    word = word.upper()
    symbol = 'STRING_' + word + ' = . - STRING_CONSTANTS'
    codes = [code(c) for c in word] + [0]
    print(symbol)
    print('    byte ' + ', '.join([str(c) for c in codes]))