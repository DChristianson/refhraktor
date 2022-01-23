import math


combinations = [(dx, dy, iy) for dx in range(-4, 5) for dy in range(-80, 1) for iy in [-4 * i for i in range(1, 21)]]

def eval(dx, dy, iy):
    x = 0
    y = 0
    while y < 80:
        y = y + 1
        dy = dy + 1
        if dy >= 0:
            x = x + dx
            dy = iy
    return x

solutions = [(dx, dy, iy, eval(dx, dy, iy), (abs(dx), abs(dy), abs(iy))) for (dx, dy, iy) in combinations]

filtered = {}
for candidate in solutions:
    (dx, dy, iy, key, score) = candidate
    current = filtered.get(key)
    if current is None or current[4] > score:
        filtered[key] = candidate

solutions = filtered.values()

for i in range(-80, 81, 8):
    (dx, dy, iy, key, score) = filtered[i]
    print(str(i) + ':', dx, dy, iy)

