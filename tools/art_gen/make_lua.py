# -*- coding: utf-8 -*-
"""검증이 끝난 PNG를 그대로 읽어 Aseprite Lua 데이터로 덤프한다.
   (PNG에서 되읽기 때문에 .aseprite 원본과 시트가 어긋날 수 없다)"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SHEET = os.path.join(HERE, 'player_mage_sheet.png')
OUT = os.path.join(HERE, 'player_mage_data.lua')

GPL = r"C:\Users\djgnf\Desktop\godot_games\tockbon\assets\aseprite\takbon.gpl"
APOLLO = []
for _line in open(GPL, encoding="utf-8"):
    _p = _line.split()
    if len(_p) >= 3 and _p[0].isdigit():
        APOLLO.append("%02x%02x%02x" % (int(_p[0]), int(_p[1]), int(_p[2])))
assert len(APOLLO) == 60, len(APOLLO)

LAYOUT = [(0, 0), (1, 0)] + [(i, 1) for i in range(8)] + [(0, 2)]
NAMES = ['idle0', 'idle1'] + ['run%d' % i for i in range(8)] + ['hurt']
CHARS = ('abcdefghijklmnopqrstuvwxyz'
         'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-*/=<>?!@#$%^&~')

im = Image.open(SHEET).convert('RGBA')
used = []
for (cx, cy) in LAYOUT:
    for y in range(64):
        for x in range(64):
            r, g, b, a = im.getpixel((cx * 64 + x, cy * 64 + y))
            if a:
                h = '%02x%02x%02x' % (r, g, b)
                if h not in used:
                    used.append(h)
assert len(used) <= len(CHARS), len(used)
legend = {h: CHARS[i] for i, h in enumerate(used)}

lines = ['-- 자동 생성 (scratchpad/gen_player.py -> make_lua.py). 손으로 고치지 마라.',
         'local D = {}', 'D.apollo = {']
lines.append('  ' + ', '.join('"%s"' % h for h in APOLLO))
lines.append('}')
lines.append('D.pal = {')
for h, c in legend.items():
    lines.append('  ["%s"] = "%s",' % (c, h))
lines.append('}')
lines.append('D.names = {%s}' % ', '.join('"%s"' % n for n in NAMES))
lines.append('D.frames = {')
for (cx, cy) in LAYOUT:
    lines.append('  {')
    for y in range(64):
        row = []
        for x in range(64):
            r, g, b, a = im.getpixel((cx * 64 + x, cy * 64 + y))
            row.append(legend['%02x%02x%02x' % (r, g, b)] if a else '.')
        lines.append('    "%s",' % ''.join(row))
    lines.append('  },')
lines.append('}')
lines.append('return D')
open(OUT, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print('wrote %s  colors=%d  frames=%d' % (OUT, len(used), len(LAYOUT)))
