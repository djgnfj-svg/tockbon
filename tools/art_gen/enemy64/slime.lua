-- 수액 슬라임 — 64x64 x 4프레임. 나무 수액이 뭉쳐 움직이는 것.
-- 세계관: 문양을 삼킨 짐승 — 삼킨 마법진 조각이 수액 속에 잠겨 있다(발광 오라 아님).
local DIR = "C:/Users/djgnf/Desktop/godot_games/tockbon/tools/art_gen/enemy64/"
local OUT = "C:/Users/djgnf/Desktop/godot_games/tockbon/assets/sprites/enemies/"
local L = dofile(DIR .. "lib.lua")
local B = dofile(DIR .. "blob.lua")

local SIDE, N, GROUND = 64, 4, 58

-- 호박색 램프. 어두운 갈색은 외곽선에만 쓰고 몸통은 앰버 대역에 예산을 몰아준다
local RAMP = {"f7f7f2","e7d5b3","e8c170","de9e41","da863e","be772b","884b2b","7a4841"}
local THR  = {1.16, 1.00, 0.83, 0.655, 0.475, 0.27, 0.05}
local OLC  = { up = "884b2b", side = "602c2c", down = "341c27" }

local HEXES = {"f2cb3f","fbefa8","c9962e","f7f7f2","341c27","2e1f18","d7b594","602c2c",
               "e7d5b3","884b2b","ad7757","4d2b32"}
local C = {}
for _, h in ipairs(RAMP) do C[h] = L.hex(h) end
for _, h in pairs(OLC) do C[h] = L.hex(h) end
for _, h in ipairs(HEXES) do C[h] = L.hex(h) end

-- 각 프레임: 반경·흔들림·명암 흔들림을 손으로 잡는다.
-- 🔴 착지(f1)는 세게 눌리고 복귀(f3)는 약하게 — 선형 보간이 아니다.
-- wob 슬롯: 1=오른쪽 · 4=아래 · 7=왼쪽 · 10=위 (30°씩)
-- 🔴 아래를 부풀리고 위를 좁혀 「공」이 아니라 「퍼진 덩어리」로 만든다.
local FR = {
  { rx=27, cx=32, cy=34, key=56, over=3, sss=0.40,
    wob    ={1.02,1.045,1.05,1.03,1.045,1.015,0.995,0.945,0.905,0.885,0.915,0.975},
    lamWob ={0.00,0.10,-0.07,0.05,0.12,-0.06,0.03,0.11,-0.09,0.02,0.08,-0.04} },
  { rx=28, cx=32, cy=39, key=47, over=6, sss=0.50,      -- 착지: 크게 눌린다
    wob    ={1.05,1.075,1.065,1.03,1.055,1.03,1.015,0.95,0.885,0.855,0.895,0.985},
    lamWob ={0.05,0.11,-0.09,0.02,0.09,-0.07,0.07,0.12,-0.05,0.00,0.09,-0.02} },
  { rx=23, cx=32, cy=32, key=59, over=1, sss=0.26,      -- 도약: 위로 솟는다
    wob    ={0.975,0.99,1.01,1.005,1.00,0.985,0.98,1.005,1.03,1.02,0.99,0.965},
    lamWob ={-0.03,0.07,0.12,-0.05,0.04,0.09,-0.07,0.05,0.11,-0.04,0.02,0.07} },
  { rx=26, cx=33, cy=36, key=52, over=4, sss=0.42,      -- 잔여 흔들림: 살짝만 돌아온다
    wob    ={1.03,1.05,1.04,1.02,1.035,1.02,1.005,0.955,0.915,0.90,0.935,0.99},
    lamWob ={0.04,-0.05,0.09,0.11,-0.07,0.02,0.09,-0.03,0.06,0.12,-0.06,0.00} },
}

local spr, img = L.newStrip(N, SIDE)

local function has(ox, x, y)
  if x < 0 or x >= SIDE or y < 0 or y >= SIDE then return false end
  return img:getPixel(ox+x, y) ~= L.CLEAR
end
local function put(ox, x, y, c)
  if has(ox, x, y) then img:drawPixel(ox+x, y, C[c]) end
end

-- ── 삼킨 문양: 깨진 고리 (오른쪽이 끊겼다) + 떨어져 나온 파편 ────────
-- 🔴 고리는 행단위 스팬으로 굽는다 — 각도 루프로 찍으면 픽셀이 겹쳐 「엉킨 철사」가 된다.
local function ringPts(cx, cy, rad, sy, th, gap0, gap1)
  local pts = {}
  local ryo = rad * sy
  local ri, ryi = rad - th, (rad - th) * sy
  for y = -math.ceil(ryo), math.ceil(ryo) do
    local t = y / ryo
    if math.abs(t) <= 1 then
      local xo = rad * math.sqrt(1 - t*t)
      local ti = (ryi > 0) and (y / ryi) or 2
      local xi = (math.abs(ti) < 1) and ri * math.sqrt(1 - ti*ti) or 0
      for x = -math.floor(xo), math.floor(xo) do
        if math.abs(x) >= xi - 0.5 then
          local a = math.deg(math.atan(y / sy, x)) % 360
          -- ⚠ Lua의 a and b or c 삼항은 b가 false면 무너진다 — 에러 없이 문양이 통째로 안 그려진다.
          local inGap
          if gap0 < gap1 then inGap = (a >= gap0 and a <= gap1)
          else inGap = (a >= gap0 or a <= gap1) end
          if not inGap then pts[#pts+1] = { cx + x, cy + y, a } end
        end
      end
    end
  end
  return pts
end

-- 🔴 「수액에 잠겨 있다」를 만드는 건 밑그림자다 — 어두운 앰버를 아래오른쪽으로 1px 깔고
--    그 위에 밝은 획을 얹으면 몸에 얹힌 스티커가 아니라 속에 든 것으로 읽힌다.
local function drawGlyph(ox, cx, cy, rad, shift)
  -- 바깥 고리: 오른쪽 위가 끊겨 있다 (아래를 비우면 「웃는 입」으로 읽힌다)
  local pts = ringPts(cx, cy, rad, 0.82, 2, (296 + shift) % 360, (350 + shift) % 360)
  -- 안쪽 고리 조각: 다른 자리가 끊겨 있어 두 겹이 어긋난다 = 「마법진」의 인상
  for _, p in ipairs(ringPts(cx, cy, rad - 5, 0.82, 1, (110 + shift) % 360, (215 + shift) % 360)) do
    pts[#pts+1] = p
  end
  -- 바깥으로 뻗은 짧은 획 셋 (길이·굵기가 서로 다르다)
  for _, s in ipairs({ {200, 5, 2}, {268, 3, 1}, {124, 4, 2} }) do
    for t = 1, s[2] do
      for k = 0, s[3]-1 do
        local ar = math.rad(s[1] + k*6)
        pts[#pts+1] = { cx + math.floor((rad+t)*math.cos(ar)+0.5),
                        cy + math.floor((rad+t)*math.sin(ar)*0.82+0.5), s[1] }
      end
    end
  end
  -- 🔴 「삼킨 빛」은 몸 색이 아니다 — 밝은 코어 + 1px 어두운 밑그림자로 명도로 가른다(금색을 호박 몸에 올리면 명도차가 없어 안 보인다).
  for _, p in ipairs(pts) do put(ox, p[1]+1, p[2]+1, "602c2c") end
  for _, p in ipairs(pts) do
    local a = p[3]
    local col = "fbefa8"
    if a > 40 and a < 150 then col = "e8c170"          -- 아래쪽 = 수액에 더 잠겨 탁하다
    elseif a > 195 and a < 258 then col = "f7f7f2" end -- 빛을 정면으로 받는 짧은 구간
    put(ox, p[1], p[2], col)
  end
end

-- ── 수액 속 기포 (디테일을 시선 가는 곳에 몰아준다) ────────────────
local function bubble(ox, x, y, r)
  for yy = -r, r do
    for xx = -r, r do
      local d = xx*xx + yy*yy
      if d <= r*r + 1 then
        if d >= (r-1)*(r-1) then
          put(ox, x+xx, y+yy, (yy < 0 or xx < 0) and "884b2b" or "e8c170")   -- 위·왼쪽 테는 어둡고 아래는 밝다
        elseif xx <= -r+2 and yy <= -r+2 then put(ox, x+xx, y+yy, "e7d5b3")
        else put(ox, x+xx, y+yy, "de9e41") end
      end
    end
  end
end

-- ── 스페큘러 (손으로 그린 두 조각 — 완벽한 타원이 아니다) ───────────
local SPEC_LEG = L.legend({ W="f7f7f2", w="e7d5b3", h="e8c170" })
local SPEC = {
  {2, ".hwwwh"},
  {1, "hwWWWwh"},
  {0, "hwWWWWwh"},
  {0, "hwWWWWww"},
  {1, "hwWWwwh"},
  {2, "hwwwh"},
  {4, "hwh"},
  {5, "hw"},
  {6, "h"},
}
local SPEC2 = { {0,"hww"}, {0,"hwh"}, {1,"h"} }   -- 작은 곁 하이라이트

-- ── 눈 ───────────────────────────────────────────────────────────────
local EYE_LEG = L.legend({ e="341c27", k="2e1f18", w="e7d5b3", W="f7f7f2", r="884b2b", d="602c2c" })
local EYE_L = {
  {2, "rddd."},
  {1, "rdeeek"},
  {0, "rdeWWeek"},
  {0, "rdeWweeek"},
  {0, "rdeeeeeek"},
  {0, "rdeeeeeek"},
  {1, "rdeeeeek"},
  {2, "rdeeeek"},
  {3, "rdeek"},
}
local EYE_R = {
  {2, "rdd.."},
  {1, "rdeeek"},
  {0, "rdeWweek"},
  {0, "rdeweeek"},
  {0, "rdeeeeek"},
  {0, "rdeeeeeek"},
  {1, "rdeeeek"},
  {2, "rdeeek"},
  {3, "rdek"},
}

for f = 1, N do
  local o = FR[f]
  local ox = (f-1)*SIDE
  local topy = GROUND - o.key + 1
  local cy  = o.cy
  local ryT = (cy - topy) / o.wob[10]       -- wob이 위를 좁히므로 그만큼 되불린다
  local ryB = (GROUND - cy + o.over) / o.wob[4]   -- over만큼 바닥 아래로 넘겨 잘라 = 납작한 접지면
  local opt = { cx = o.cx, cy = cy, rx = o.rx, ryTop = ryT, ryBot = ryB,
                wob = o.wob, lamWob = o.lamWob, ramp = RAMP, thr = THR,
                light = {-0.50, -0.70, 0.51}, sss = o.sss, rim = 0.34,
                core = {0.30, 0.13}, ground = GROUND }
  local mask = B.field(SIDE, SIDE, opt)
  local ol = B.outline(mask, SIDE, SIDE, opt)
  for y = 0, SIDE-1 do
    for x = 0, SIDE-1 do
      local s = mask[y][x]
      if s then
        img:drawPixel(ox+x, y, C[ ol[y][x] and OLC[ol[y][x]] or RAMP[s] ])
      end
    end
  end
  -- 스페큘러 (프레임마다 자리·크기가 다르다)
  local sp = { {-13,-17}, {-13,-13}, {-10,-20}, {-11,-15} }
  L.blit(img, SPEC, ox + o.cx + sp[f][1], cy + sp[f][2], SPEC_LEG)
  L.blit(img, SPEC2, ox + o.cx + sp[f][1] + 11, cy + sp[f][2] + 4, SPEC_LEG)
  -- 아래왼쪽 반사광 테 (표면장력 — 젤리가 「공」이 아니라 「액체」로 읽히는 자리)
  for y = cy, GROUND - 1 do
    local seen = 0
    for x = 0, SIDE-1 do
      if mask[y][x] and not ol[y][x] then
        if seen == 0 then put(ox, x, y, "e8c170")
        elseif seen == 1 and (y - cy) > 4 then put(ox, x, y, "de9e41") end
        seen = seen + 1
        if seen > 1 then break end
      end
    end
  end
  -- 접지 그늘 (바닥 두 줄을 눌러 놓지 않으면 몸이 뜬다)
  for x = 0, SIDE-1 do
    if has(ox, x, GROUND) then put(ox, x, GROUND, "341c27") end
    if has(ox, x, GROUND-1) and math.abs(x - o.cx) < o.rx * 0.72 then put(ox, x, GROUND-1, "4d2b32") end
  end
  -- 삼킨 문양 (프레임마다 수액 속에서 조금씩 흐른다)
  local gsh = { {0,0,0}, {1,-1,14}, {-2,2,-12}, {2,1,22} }
  drawGlyph(ox, o.cx - 5 + gsh[f][1], cy + 5 + gsh[f][2], 11, gsh[f][3])
  -- 기포 셋
  -- 문양 고리(cx-5, cy+5, r11)를 피해 놓는다 — 겹치면 둘 다 엉킨 낙서가 된다
  local bb = { { {-18,17,4},{13,11,3} },
               { {-19,13,3},{14,6,3} },
               { {-15,19,4},{11,13,3} },
               { {-17,16,4},{13,9,3} } }
  for _, b in ipairs(bb[f]) do bubble(ox, o.cx + b[1], cy + b[2], b[3]) end
  -- 눈
  local eyY = cy - math.floor(ryT * 0.44)
  L.blit(img, EYE_L, ox + o.cx - 15, eyY, EYE_LEG)
  L.blit(img, EYE_R, ox + o.cx + 7, eyY + 1, EYE_LEG)
  print(string.format("f%d key=%d %s", f-1, o.key, L.bbox(img, ox, SIDE)))
end

print("colors=" .. L.colorCount(img))
L.finish(spr, img, OUT .. "slime.png")
print("saved")
