import sys

_character_map = ' 0123456789:-+<=>$.!?ABCDEFGHIJKLMNOPQRSTUVWXYZ' 

def code(c):
    idx = _character_map.index(c) + 1
    lo = idx % 2
    offset = ((idx - lo) << 2) + lo
    return offset

for word in sys.argv[1:]:
    word = word.upper()
    varname = word.replace(' ', '_')
    symbol = 'STRING_' + varname + ' = . - STRING_CONSTANTS'
    codes = [code(c) for c in word] + [0]
    print(symbol)
    print('    byte ' + ', '.join([str(c) for c in codes]))