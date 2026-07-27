-- 숲 사냥개 — 64x64 x 8프레임 (질주). 옆모습, 오른쪽을 본다.
-- 세계관: 삼킨 문양이 어깨에 흉터처럼 박혀 있다 — 빛나는 게 아니라 「그을린 자국」이다.
local DIR = "C:/Users/djgnf/Desktop/godot_games/tockbon/tools/art_gen/enemy64/"
local OUT = "C:/Users/djgnf/Desktop/godot_games/tockbon/assets/sprites/enemies/"
local L = dofile(DIR .. "lib.lua")
local B = dofile(DIR .. "blob.lua")

local SIDE, N, GROUND = 64, 8, 57

local RAMP = {"e7d5b3","d7b594","c09473","ad7757","884b2b","7a4841","602c2c","4d2b32","341c27"}
local THR  = {1.06, 0.94, 0.82, 0.695, 0.565, 0.43, 0.28, 0.11}

local HEX = {"e7d5b3","d7b594","c09473","ad7757","884b2b","7a4841","602c2c","4d2b32","341c27",
             "2e1f18","a53030","cf573c","752438","da863e","de9e41","f2cb3f","fbefa8","c9962e",
             "241527","be772b"}
local C = {}
for _, h in ipairs(HEX) do C[h] = L.hex(h) end

local spr, img = L.newStrip(N, SIDE)
local function put(ox,x,y,c)
  if x>=0 and x<SIDE and y>=0 and y<SIDE then img:drawPixel(ox+x,y,C[c]) end
end
local function has(ox,x,y)
  if x<0 or x>=SIDE or y<0 or y>=SIDE then return false end
  return img:getPixel(ox+x,y) ~= L.CLEAR
end
local function putIn(ox,x,y,c) if has(ox,x,y) then put(ox,x,y,c) end end

-- ── 걸음: 앞다리 8자세 · 뒷다리 8자세 (손으로 잡은 값. 보간이 아니다) ──
-- 앞다리 {팔꿈치 dx,dy, 발 dx,dy} — 어깨 기준
local FRONT = {
  {  5,  8,  11, 13 },   -- 앞으로 뻗음
  {  6,  9,  13, 19 },   -- 착지 직전
  {  3, 10,   5, 22 },   -- 디딤
  {  0, 10,  -4, 21 },   -- 몸 아래
  { -3,  9,  -9, 17 },   -- 밀어냄
  { -5,  8,  -7, 11 },   -- 들어올림
  { -1,  9,   2,  9 },   -- 앞으로 접어 나옴
  {  3,  9,   8, 10 },   -- 뻗기 시작
}
-- 뒷다리 {무릎 dx,dy, 뒷발목 dx,dy, 발 dx,dy} — 엉덩이 기준
local REAR = {
  { -2,  9,   4, 15,  -1, 22 },
  { -4,  9,   0, 16,  -7, 21 },
  { -6,  8,  -5, 14, -13, 18 },
  { -6,  7,  -7, 11, -11, 12 },
  { -4,  8,  -3, 12,  -4, 10 },
  { -2,  9,   3, 14,   4, 15 },
  { -1,  9,   5, 16,   7, 22 },
  { -2,  9,   4, 16,   2, 23 },
}
-- 앞/뒤 위상, 몸 높이, 등 각도. 🔴 도약(2·6)은 1프레임에 튀고 착지(3·7)는 눌린다
local FR = {
  { fr=1, rr=5, bob= 0, tilt= 0, stretch= 0 },
  { fr=2, rr=6, bob= 1, tilt= 1, stretch=-1 },
  { fr=3, rr=7, bob= 2, tilt= 1, stretch=-2 },
  { fr=4, rr=8, bob= 0, tilt= 0, stretch= 1 },
  { fr=5, rr=1, bob=-2, tilt=-1, stretch= 2 },
  { fr=6, rr=2, bob=-2, tilt=-1, stretch= 2 },
  { fr=7, rr=3, bob=-1, tilt= 0, stretch= 1 },
  { fr=8, rr=4, bob= 1, tilt= 1, stretch=-1 },
}

-- 다리 한 짝 (먼 쪽은 어두운 세 톤으로 납작하게, 가까운 쪽은 램프로)
local function limb(ox, pts, radii, far, ambAdd)
  local parts = {}
  for i = 1, #pts-1 do
    parts[#parts+1] = { pts[i][1], pts[i][2], radii[i], pts[i+1][1], pts[i+1][2], radii[i+1] }
  end
  local mask = B.capsule(SIDE, SIDE, {
    parts = parts, ramp = RAMP, thr = THR,
    light = {-0.50, -0.62, 0.60}, amb = (far and -0.46 or 0.02) + (ambAdd or 0),
    lamWob = {0.00,0.06,-0.04,0.03,0.07,-0.05,0.02,0.05,-0.03,0.01,0.06,-0.02} })
  for y = 0, SIDE-1 do for x = 0, SIDE-1 do
    if mask[y][x] then
      local s = mask[y][x]
      if far then s = math.min(#RAMP, s + 3) end
      img:drawPixel(ox+x, y, C[RAMP[s]])
    end
  end end
end

for f = 1, N do
  local o  = FR[f]
  local ox = (f-1)*SIDE
  local by = o.bob
  local st = o.stretch
  local tl = o.tilt

  local hipX,  hipY  = 18,          34 + by
  local shdX, shdY   = 40 + st,     32 + by + tl

  -- ── 먼 쪽 두 다리 (몸 뒤) ────────────────────────────────────────
  local ff = FRONT[((o.fr + 3) % 8) + 1]
  local rf = REAR[((o.rr + 3) % 8) + 1]
  limb(ox, { {shdX-3, shdY}, {shdX-3+ff[1], shdY+ff[2]}, {shdX-3+ff[3], shdY+ff[4]} },
       {4.0, 2.6, 1.8}, true)
  limb(ox, { {hipX-3, hipY}, {hipX-3+rf[1], hipY+rf[2]}, {hipX-3+rf[3], hipY+rf[4]}, {hipX-3+rf[5], hipY+rf[6]} },
       {5.0, 3.2, 2.2, 1.8}, true)

  -- ── 꼬리 (몸 뒤에서 뻗는다 — 프레임마다 채찍처럼 휜다) ───────────
  local TL = { {-6,-6,-13,-13}, {-7,-5,-15,-10}, {-8,-3,-16,-5}, {-7,-2,-15,-1},
               {-6,-4,-14,-8}, {-5,-7,-12,-15}, {-6,-8,-13,-17}, {-7,-7,-14,-14} }
  local t = TL[f]
  limb(ox, { {13, 27+by}, {13+t[1], 27+by+t[2]}, {13+t[3], 27+by+t[4]} }, {3.6, 2.2, 1.1}, false, -0.16)

  -- ── 몸통 + 목 + 머리 (캡슐 뼈대) ─────────────────────────────────
  local body = {
    { 14,        30+by,      11.0, 24,        30+by+tl,    9.4 },   -- 엉덩이 → 허리
    { 24,        30+by+tl,    9.4, 34+st,     29+by+tl*2, 10.6 },   -- 허리 → 가슴
    { 34+st,     29+by+tl*2, 10.6, 41+st,     25+by+tl*2,  8.4 },   -- 가슴 → 어깨
    { 41+st,     25+by+tl*2,  8.4, 45+st,     16+by+tl,    7.2 },   -- 어깨 → 목 (굵게)
    { 45+st,     16+by+tl,    7.2, 50+st,     11+by,       6.9 },   -- 목 → 두개골 (크게)
    { 50+st,     11+by,       6.9, 54+st,     13+by,       4.8 },   -- 두개골 → 주둥이
    { 54+st,     13+by,       4.8, 58+st,     14+by,       3.4 },   -- 주둥이 → 코끝
  }
  local mask = B.capsule(SIDE, SIDE, {
    parts = body, ramp = RAMP, thr = THR, light = {-0.48, -0.66, 0.58}, amb = 0.06,
    lamWob = {0.00,0.09,-0.06,0.04,0.11,-0.05,0.03,0.10,-0.08,0.02,0.07,-0.03} })
  for y = 0, SIDE-1 do for x = 0, SIDE-1 do
    if mask[y][x] then img:drawPixel(ox+x, y, C[RAMP[mask[y][x]]]) end
  end end

  -- 외곽선: 아래·오른쪽만 어둡게 (균일 검정 금지 — 색 외곽선)
  for y = 0, SIDE-1 do for x = 0, SIDE-1 do
    if mask[y][x] then
      local edge = not (mask[y][x-1] and mask[y][x+1] and (mask[y-1] and mask[y-1][x]) and (mask[y+1] and mask[y+1][x]))
      if edge then
        local below = (mask[y+1] == nil) or (mask[y+1][x] == nil)
        img:drawPixel(ox+x, y, C[ below and "341c27" or "4d2b32" ])
      end
    end
  end end

  -- ── 귀 둘 (뒤로 눕는다 — 달리는 짐승) ────────────────────────────
  local EAR = L.legend({ k="341c27", d="4d2b32", m="7a4841", l="ad7757", h="c09473", p="602c2c" })
  local EAR_N = { {3,"kd"}, {2,"kdm"}, {1,"kdml"}, {1,"kdmlh"}, {0,"kdmmll"}, {0,"kddmml"}, {0,"kkddm"}, {1,"kkd"} }
  local EAR_F = { {2,"kd"}, {1,"kdp"}, {1,"kdpd"}, {0,"kdppd"}, {0,"kddpd"}, {0,"kkdd"}, {1,"kkd"} }
  L.blit(img, EAR_F, ox + 45 + st, 3 + by, EAR)
  L.blit(img, EAR_N, ox + 49 + st, 2 + by, EAR)

  -- ── 눈 · 코 · 입 (디테일은 얼굴에 몰아준다 — 진단 ⑤) ─────────────
  local ey, ex = 11 + by, 52 + st
  putIn(ox, ex,   ey,   "341c27"); putIn(ox, ex+1, ey,   "341c27")
  putIn(ox, ex,   ey+1, "a53030"); putIn(ox, ex+1, ey+1, "cf573c")
  putIn(ox, ex,   ey+2, "752438"); putIn(ox, ex+1, ey+2, "a53030")
  putIn(ox, ex+2, ey+1, "341c27")
  for i = 0, 4 do putIn(ox, 54+st+i, 16+by, "341c27") end     -- 입선
  putIn(ox, 60+st, 13+by, "2e1f18"); putIn(ox, 60+st, 14+by, "2e1f18")
  putIn(ox, 59+st, 13+by, "2e1f18"); putIn(ox, 61+st, 14+by, "2e1f18")

  -- 배 그늘 (몸통 아랫배 세 줄 — 다리와 몸이 한 덩어리로 붙어 보이던 것을 가른다)
  for x = 10, 46 do
    local hit = 0
    for y = SIDE-1, 0, -1 do
      if mask[y][x] then
        hit = hit + 1
        if hit <= 2 then putIn(ox, x, y, (hit == 1) and "4d2b32" or "602c2c") end
        if hit > 2 then break end
      end
    end
  end

  -- ── 어깨의 흉터 = 삼킨 문양 ─────────────────────────────────────
  -- 🔴 「빛나는 고리」가 아니라 「그을린 자국」이다 — 어두운 자국을 먼저 파고 그 안만 뜨겁다.
  local gx, gy = 37 + st, 27 + by
  local gsh = { 0, 12, 24, 36, 48, 60, 72, 84 }
  local pts = {}
  local rad = 6
  local ryo = rad*0.92
  for y = -math.ceil(ryo), math.ceil(ryo) do
    local tt = y/ryo
    if math.abs(tt) <= 1 then
      local xo = rad*math.sqrt(1-tt*tt)
      local ri, ryi = rad-2, (rad-2)*0.92
      local ti = (ryi>0) and (y/ryi) or 2
      local xi = (math.abs(ti)<1) and ri*math.sqrt(1-ti*ti) or 0
      for x = -math.floor(xo), math.floor(xo) do
        if math.abs(x) >= xi-0.5 then
          local a = (math.deg(math.atan(y/0.92, x)) + gsh[f]) % 360
          if not (a >= 22 and a <= 96) then pts[#pts+1] = {gx+x, gy+y, a} end
        end
      end
    end
  end
  for _, s in ipairs({ {186,4}, {252,3}, {132,5} }) do        -- 밖으로 번진 그을음
    for tq = 1, s[2] do
      for k = 0, 1 do
        local ar = math.rad(s[1] - gsh[f] + k*8)
        pts[#pts+1] = { gx + math.floor((rad+tq)*math.cos(ar)+0.5),
                        gy + math.floor((rad+tq)*math.sin(ar)*0.92+0.5), s[1] }
      end
    end
  end
  for _, p in ipairs(pts) do putIn(ox, p[1]+1, p[2]+1, "241527") end
  for _, p in ipairs(pts) do
    -- 🔴 대부분은 그을음(어두운 갈색)이고 빛을 정면으로 받는 짧은 구간만 뜨겁다
    local col = "c9962e"
    if p[3] > 40 and p[3] < 160 then col = "884b2b"
    elseif p[3] > 196 and p[3] < 286 then col = "de9e41"
    elseif p[3] > 286 or p[3] < 20 then col = "be772b" end
    putIn(ox, p[1], p[2], col)
  end

  -- ── 가까운 쪽 두 다리 (몸 앞) ───────────────────────────────────
  local fn = FRONT[o.fr]
  local rn = REAR[o.rr]
  limb(ox, { {shdX, shdY}, {shdX+fn[1], shdY+fn[2]}, {shdX+fn[3], shdY+fn[4]} },
       {4.4, 2.8, 2.0}, false)
  limb(ox, { {hipX, hipY}, {hipX+rn[1], hipY+rn[2]}, {hipX+rn[3], hipY+rn[4]}, {hipX+rn[5], hipY+rn[6]} },
       {5.4, 3.4, 2.4, 2.0}, false)

  print(string.format("f%d %s", f-1, L.bbox(img, ox, SIDE)))
end

print("colors=" .. L.colorCount(img))
L.finish(spr, img, OUT .. "hound.png")
print("saved")
