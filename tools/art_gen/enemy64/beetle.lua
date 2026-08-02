-- 갑주 갑충 — 64x64 x 4프레임. 위에서 내려다본 딱딱한 것.
-- 세계관: 삼킨 문양이 등껍질을 갈라 놓았다 — 발광이 아니라 「금」이다.
local DIR = "C:/Users/djgnf/Desktop/godot_games/tockbon/tools/art_gen/enemy64/"
local OUT = "C:/Users/djgnf/Desktop/godot_games/tockbon/assets/sprites/enemies/"
local L = dofile(DIR .. "lib.lua")
local B = dofile(DIR .. "blob.lua")

local SIDE, N = 64, 4

-- 갑각 램프: 중간은 청회색, 어두운 쪽은 보라 (곤충 갑각의 무지갯빛)
local RAMP = {"c7cfcc","a8b5b2","819796","577277","4e5259","402751","1e1d39","10141f","090a14"}
local THR  = {1.18, 1.03, 0.885, 0.735, 0.575, 0.40, 0.215, 0.04}
local OLC  = { up = "402751", side = "1e1d39", down = "10141f" }

local HEX = {"f7f7f2","c7cfcc","a8b5b2","819796","577277","4e5259","402751","1e1d39","10141f",
             "090a14","7a367b","8b5fbf","e0a3e8","fbefa8","f2cb3f","c9962e","241527","2a2c32",
             "394a50","202e37","884b2b","752438","a53030","411d31","de9e41","cf573c"}
local C = {}
for _, h in ipairs(HEX) do C[h] = L.hex(h) end
for _, h in pairs(OLC) do C[h] = L.hex(h) end

local spr, img = L.newStrip(N, SIDE)
local function put(ox,x,y,c)
  if x>=0 and x<SIDE and y>=0 and y<SIDE then img:drawPixel(ox+x,y,C[c]) end
end
local function has(ox,x,y)
  if x<0 or x>=SIDE or y<0 or y>=SIDE then return false end
  return img:getPixel(ox+x,y) ~= L.CLEAR
end
local function putIn(ox,x,y,c) if has(ox,x,y) then put(ox,x,y,c) end end

local function thick(ox, x0, y0, x1, y1, w, col, edge)
  local dx, dy = x1-x0, y1-y0
  local n = math.max(math.abs(dx), math.abs(dy))
  for i = 0, n do
    local t = (n == 0) and 0 or i/n
    local x = math.floor(x0 + dx*t + 0.5)
    local y = math.floor(y0 + dy*t + 0.5)
    for k = 0, w-1 do
      local px, py = x, y
      if math.abs(dx) > math.abs(dy) then py = y + k else px = x + k end
      put(ox, px, py, (k == 0 and edge) and edge or col)
    end
  end
end

-- ── 다리: 세 쌍. 삼각보행(대각선 셋이 같이 움직인다) ──────────────────
-- {중심에서 붙는 자리 dx, y, 무릎 dx,dy, 발끝 dx,dy}
local LEG_A = {
  { 13, 26,  11, -3,   4, 11 },
  { 17, 35,  11,  3,   2, 11 },
  { 14, 45,  11,  5,   3,  5 },
}
local LEG_B = {
  { 13, 26,  12,  1,   2, 12 },
  { 17, 35,  10,  6,   4,  7 },
  { 14, 45,  12,  2,   1,  9 },
}
-- 프레임별 좌/우 위상 (A/B). 묵직한 것이라 두 자세만 오간다 — 보간 없음.
local PHASE = { {"A","B"}, {"B","A"}, {"A","B"}, {"B","A"} }
local BOB   = { 0, 1, 0, 1 }
local ANT   = { {-3,-2}, {-2,-4}, {-4,-1}, {-2,-3} }

for f = 1, N do
  local ox = (f-1)*SIDE
  local cx = 32
  local bob = BOB[f]

  -- ── 다리 (몸 뒤) ────────────────────────────────────────────────
  for side = -1, 1, 2 do
    local set = (PHASE[f][(side < 0) and 1 or 2] == "A") and LEG_A or LEG_B
    for li, g in ipairs(set) do
      local ax = cx + side*g[1]
      local ay = g[2] + bob
      local kx, ky = ax + side*g[3], ay + g[4]
      local ex, ey = kx + side*g[5], ky + g[6]
      thick(ox, ax, ay, kx, ky, 3, "1e1d39", "402751")     -- 넓적다리
      thick(ox, kx, ky, ex, ey, 2, "10141f", "1e1d39")     -- 종아리
      put(ox, ex, ey+1, "10141f")                           -- 발끝
      if li == 2 then put(ox, kx, ky, "402751") end         -- 가운데 다리 관절만 밝게
    end
  end

  -- ── 더듬이 ──────────────────────────────────────────────────────
  local an = ANT[f]
  thick(ox, cx-7, 13+bob, cx-16+an[1], 6+an[2], 2, "1e1d39", "402751")
  thick(ox, cx+7, 13+bob, cx+16-an[1], 7+an[2], 2, "1e1d39", "402751")
  put(ox, cx-16+an[1], 5+an[2], "8b5fbf"); put(ox, cx-17+an[1], 5+an[2], "7a367b")
  put(ox, cx+16-an[1], 6+an[2], "8b5fbf"); put(ox, cx+17-an[1], 6+an[2], "7a367b")

  -- ── 머리 + 큰턱 ─────────────────────────────────────────────────
  local HEAD = L.legend({ d="1e1d39", m="402751", l="577277", h="819796", k="10141f",
                          e="090a14", R="752438", r="a53030", g="cf573c", p="7a367b" })
  local HEAD_MAP = {
    { 0, "kk........kk"},
    { 0, "kdk......kdk"},
    { 1, "kdk....kdk"},
    { 1, ".kdk..kdk."},
    { 1, "kddmmmmddk"},
    { 0, "kdRrmmmmrRdk"},
    { 0, "kdRgmlllmgRdk"},
    { 0, "kdRrmlhhlmrRdk"},
    { 0, "kdmmmllllmmmdk"},
    { 1, "kdmmmmmmmmmdk"},
    { 2, "kkdmmmmmmdkk"},
    { 3, "kkddddddkk"},
  }
  L.blit(img, HEAD_MAP, ox + cx - 7, 2 + bob, HEAD)

  -- ── 앞가슴 방패 (pronotum) ─────────────────────────────────────
  local pOpt = { cx=cx, cy=20+bob, rx=15, ryTop=7, ryBot=9,
                 wob={1.00,1.02,1.03,0.99,1.02,1.00,0.98,0.96,0.99,0.94,0.97,0.99},
                 lamWob={0.00,0.08,-0.05,0.04,0.10,-0.06,0.03,0.09,-0.07,0.02,0.06,-0.03},
                 ramp=RAMP, thr=THR, light={-0.52,-0.66,0.54}, rim=0.18, core={0.32,0.10} }
  local pm = B.field(SIDE, SIDE, pOpt)
  local po = B.outline(pm, SIDE, SIDE, pOpt)
  for y = 0, SIDE-1 do for x = 0, SIDE-1 do
    if pm[y][x] then img:drawPixel(ox+x, y, C[ po[y][x] and OLC[po[y][x]] or RAMP[pm[y][x]] ]) end
  end end

  -- 앞가슴판과 딱지날개 사이 분리선 (없으면 「쌓인 돌 둘」로 읽힌다)
  for x = cx-17, cx+17 do putIn(ox, x, 27+bob, "090a14") end

  -- ── 딱지날개 (elytra) ───────────────────────────────────────────
  local eOpt = { cx=cx, cy=38+bob, rx=21, ryTop=15, ryBot=17,
                 wob={1.00,1.015,1.02,1.00,1.025,1.01,0.995,0.98,0.99,0.965,0.985,1.005},
                 lamWob={0.02,-0.04,0.09,0.11,-0.06,0.03,0.10,-0.05,0.01,0.07,-0.03,0.05},
                 ramp=RAMP, thr=THR, light={-0.52,-0.66,0.54}, rim=0.26, core={0.34,0.12} }
  local em = B.field(SIDE, SIDE, eOpt)
  local eo = B.outline(em, SIDE, SIDE, eOpt)
  for y = 0, SIDE-1 do for x = 0, SIDE-1 do
    if em[y][x] then img:drawPixel(ox+x, y, C[ eo[y][x] and OLC[eo[y][x]] or RAMP[em[y][x]] ]) end
  end end

  -- 가운데 이음선 (딱지날개 둘로 갈린다) — 왼쪽에 밝은 테를 붙여 홈으로 읽힌다
  for y = 24+bob, 54+bob do
    putIn(ox, cx,   y, "10141f")
    putIn(ox, cx-1, y, "1e1d39")
    if y % 7 ~= 0 and y < 44+bob then putIn(ox, cx-2, y, "4e5259") end
  end
  -- 세로 융선: 돔을 따라 바깥으로 휘고, 아래로 갈수록 사라진다 (곧은 막대는 「칠한 줄무늬」가 된다)
  for _, r in ipairs({ {-10, 30, 50, -1}, {10, 31, 47, 1}, {-16, 34, 45, -1}, {15, 35, 43, 1} }) do
    local y0, y1 = r[2]+bob, r[3]+bob
    for y = y0, y1 do
      local t = (y - y0) / math.max(1, y1 - y0)
      local bend = math.floor(t*t * 4 + 0.5) * r[4]
      local px = cx + r[1] + bend
      if t < 0.72 then                       -- 아래 끝은 그냥 사라진다
        putIn(ox, px, y, "1e1d39")
        if t < 0.5 then putIn(ox, px - 1, y, "4e5259") end
      end
    end
  end

  -- ── 등껍질의 금 = 삼킨 문양 ────────────────────────────────────
  -- 🔴 발광 오라가 아니라 「갈라진 자리」다. 어두운 균열을 먼저 파고 그 안쪽만 빛낸다.
  local gx, gy = cx + 7, 37 + bob
  local gsh = { 0, 18, -14, 32 }
  local pts = {}
  local function ring(rad, th, g0, g1)
    local ryo = rad*0.90
    for y = -math.ceil(ryo), math.ceil(ryo) do
      local t = y/ryo
      if math.abs(t) <= 1 then
        local xo = rad*math.sqrt(1-t*t)
        local ri, ryi = rad-th, (rad-th)*0.90
        local ti = (ryi>0) and (y/ryi) or 2
        local xi = (math.abs(ti)<1) and ri*math.sqrt(1-ti*ti) or 0
        for x = -math.floor(xo), math.floor(xo) do
          if math.abs(x) >= xi-0.5 then
            local a = math.deg(math.atan(y/0.90, x)) % 360
            local inGap
            if g0 < g1 then inGap = (a >= g0 and a <= g1) else inGap = (a >= g0 or a <= g1) end
            if not inGap then pts[#pts+1] = {gx+x, gy+y, a} end
          end
        end
      end
    end
  end
  ring(8, 2, (120+gsh[f])%360, (204+gsh[f])%360)
  ring(4, 1, (300+gsh[f])%360, (24+gsh[f])%360)
  -- 바깥으로 뻗은 균열 (직선이 아니라 꺾인다 — 금은 곧게 가지 않는다)
  for _, s in ipairs({ {24, {0,0,1,1,2,2}}, {330, {0,-1,-1,-2,-2}}, {86, {0,1,1,2}} }) do
    for t = 1, #s[2] do
      for k = 0, 1 do
        local ar = math.rad(s[1] + s[2][t]*9 + k*6)
        pts[#pts+1] = { gx + math.floor((8+t)*math.cos(ar)+0.5),
                        gy + math.floor((8+t)*math.sin(ar)*0.90+0.5), s[1] }
      end
    end
  end
  for _, p in ipairs(pts) do
    putIn(ox, p[1]+1, p[2]+1, "241527"); putIn(ox, p[1]-1, p[2], "241527")
  end
  for _, p in ipairs(pts) do
    local col = "c9962e"
    if p[3] > 40 and p[3] < 150 then col = "884b2b" elseif p[3] > 218 and p[3] < 284 then col = "de9e41" end
    putIn(ox, p[1], p[2], col)
  end

  print(string.format("f%d %s", f-1, L.bbox(img, ox, SIDE)))
end

print("colors=" .. L.colorCount(img))
L.finish(spr, img, OUT .. "beetle.png")
print("saved")
