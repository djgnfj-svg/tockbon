-- 재생 덩굴 — 64x64 x 6프레임. 고정형. 꽃이 열리면 그 안에 삼킨 문양이 있다.
-- 🔴 열림은 선형이 아니다: 닫힘 → 닫힘 → 금이 감 → **한 프레임에 활짝** → 유지 → 반쯤 닫힘.
local DIR = "C:/Users/djgnf/Desktop/godot_games/tockbon/tools/art_gen/enemy64/"
local OUT = "C:/Users/djgnf/Desktop/godot_games/tockbon/assets/sprites/enemies/"
local L = dofile(DIR .. "lib.lua")
local B = dofile(DIR .. "blob.lua")

local SIDE, N, GROUND = 64, 6, 57

local RAMP = {"d0da91","a8ca58","7a8c2e","75a743","468232","2f6152","25562e","19332d","16281c"}
local THR  = {1.22, 1.06, 0.86, 0.66, 0.46, 0.26, 0.08, -0.10}
local OLC  = { up = "25562e", side = "19332d", down = "16281c" }

local HEX = {"d0da91","a8ca58","7a8c2e","75a743","468232","2f6152","25562e","19332d","16281c",
             "752438","a53030","cf573c","da863e","e8c170","fbefa8","f7f7f2","f2cb3f","c9962e",
             "341c27","241527","884b2b"}
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

-- 줄기: 밑에서 끝까지 2차곡선. 왼쪽 한 줄이 밝다(왼쪽 위 광원)
local function stalk(ox, x0, y0, x1, y1, w, bend, dark)
  local n = y0 - y1
  for i = 0, n do
    local t = i / n
    local x = x0 + (x1-x0)*t + bend*math.sin(t*math.pi)
    local y = y0 - i
    local xi = math.floor(x + 0.5)
    local ww = (t > 0.72) and math.max(1, w-1) or w
    for k = 0, ww-1 do
      local col
      if k == 0 then col = dark and "468232" or "7a8c2e"
      elseif k == ww-1 then col = dark and "16281c" or "19332d"
      else col = dark and "25562e" or "468232" end
      put(ox, xi + k, y, col)
    end
  end
end

-- 잎: 줄기에 붙는 작은 타원 (방향·크기가 제각각)
local function leaf(ox, x, y, dx, dy, len, wid)
  local n = len
  for i = 0, n do
    local t = i/n
    local w = math.floor(wid * math.sin(t*math.pi) + 0.5)
    local px = math.floor(x + dx*i + 0.5)
    local py = math.floor(y + dy*i + 0.5)
    for k = -w, w do
      local col
      if k <= -w+1 then col = "a8ca58"
      elseif k >= w-1 then col = "19332d"
      elseif t < 0.5 then col = "468232" else col = "25562e" end
      put(ox, px + k, py, col)
    end
  end
  put(ox, math.floor(x+dx*n+0.5), math.floor(y+dy*n+0.5), "16281c")
end

-- 꽃: openness 0=봉오리 … 1=활짝. 중심에 삼킨 문양.
local function flower(ox, cx, cy, openness, spin)
  if openness < 0.2 then
    -- 봉오리 (오므린 꽃잎이 겹친 모양)
    local BUD = L.legend({ R="752438", r="a53030", o="cf573c", y="da863e",
                           g="25562e", G="468232", k="341c27" })
    local M = {
      {6, "k"},
      {6, "R"},
      {5, "kR"},
      {5, "kR"},
      {4, "kRr"},
      {4, "kRro"},
      {3, "kRroo"},
      {3, "kRrooR"},
      {2, "kRrooyoR"},
      {2, "kRrooyorR"},
      {1, "kRrrooyoorRk"},
      {1, "kRrrooyoorRk"},
      {0, "kRRrrooyoorrRk"},
      {0, "kRRrrooooorrRk"},
      {0, "kRRrrroooorrRk"},
      {1, "kRRrrrooorrRk"},
      {1, "kRRRrrrorrRk"},
      {2, "kGgRRRRRgGk"},
      {2, "kGGgggGGk"},
      {3, "kGGGGGk"},
    }
    L.blit(img, M, ox + cx - 7, cy - 15, BUD)
    if openness > 0.08 then     -- 금이 가기 시작한다 (한 줄만 벌어진다)
      for i = 0, 9 do put(ox, cx - 1, cy - 8 + i, (i % 3 == 0) and "fbefa8" or "e8c170") end
      put(ox, cx, cy - 8, "f7f7f2"); put(ox, cx, cy - 4, "f7f7f2")
    end
    return
  end
  -- 활짝 — 꽃잎 다섯이 중심에서 뻗는다 (각도·크기가 미세하게 다르다)
  local rad = 3 + openness * 5
  local PET = { {-92, 0.84}, {-18, 1.00}, {56, 1.08}, {128, 1.00}, {200, 0.90} }
  for pi, p in ipairs(PET) do
    local ar = math.rad(p[1] + spin)
    local px = cx + rad * math.cos(ar)
    local py = cy + rad * math.sin(ar) * 0.88
    local rw = (2.6 + openness*2.6) * p[2]
    local rh = (2.2 + openness*2.2) * p[2]
    for yy = -math.ceil(rh)-1, math.ceil(rh)+1 do
      for xx = -math.ceil(rw)-1, math.ceil(rw)+1 do
        local d = (xx/rw)^2 + (yy/rh)^2
        if d <= 1.15 then
          local col
          if d > 0.92 then col = "752438"
          elseif xx < -rw*0.35 and yy < 0 then col = "da863e"
          elseif xx < 0 or yy < 0 then col = "cf573c"
          else col = "a53030" end
          put(ox, math.floor(px+xx+0.5), math.floor(py+yy+0.5), col)
        end
      end
    end
    if pi == 1 then   -- 위 꽃잎 끝만 밝게 (시선이 가는 자리)
      put(ox, math.floor(px+0.5), math.floor(py-rh+0.5), "e8c170")
    end
  end
  -- 중심: 어두운 우물 + 그 안의 삼킨 문양(깨진 고리)
  for yy = -4, 4 do for xx = -5, 5 do
    if (xx/5)^2 + (yy/4)^2 <= 1 then put(ox, cx+xx, cy+yy, "241527") end
  end end
  local rr = 3
  for a = 0, 359, 6 do
    local da = ((a + 180) % 360) - 180
    if math.abs(da) > 46 then
      local ar = math.rad(a + spin*2)
      local x = cx + math.floor(rr*math.cos(ar) + 0.5)
      local y = cy + math.floor(rr*math.sin(ar)*0.85 + 0.5)
      put(ox, x, y, (da < -80 or da > 150) and "f7f7f2" or "fbefa8")
    end
  end
  -- 위로 뻗는 수술 다발 (열린 프레임도 실루엣 키를 채운다)
  for _, st in ipairs({ {-14, 12}, {-3, 15}, {7, 11}, {-24, 9}, {17, 8} }) do
    local ar = math.rad(-90 + st[1] + spin)
    for t = 3, st[2] do
      local x = cx + math.floor(t*math.cos(ar)+0.5)
      local y = cy + math.floor(t*math.sin(ar)+0.5)
      put(ox, x, y, (t > st[2]-3) and "e8c170" or "752438")
    end
    local x = cx + math.floor((st[2]+1)*math.cos(ar)+0.5)
    local y = cy + math.floor((st[2]+1)*math.sin(ar)+0.5)
    put(ox, x, y, "fbefa8"); put(ox, x, y-1, "f7f7f2")
  end
  for _, s in ipairs({ {-120, 5}, {-40, 4}, {150, 5} }) do   -- 밖으로 새는 획
    local ar = math.rad(s[1] + spin*2)
    for t = rr+1, rr+s[2] do
      put(ox, cx + math.floor(t*math.cos(ar)+0.5), cy + math.floor(t*math.sin(ar)*0.85+0.5),
          (t < rr+3) and "f2cb3f" or "c9962e")
    end
  end
end

-- ── 프레임: 흔들림(줄기 끝 x오프셋) · 꽃 열림 ────────────────────────
local FR = {
  { sway = { 0,  0,  0,  0}, open = 0.00, spin =  0, bob = 0 },
  { sway = {-1,  1, -1,  0}, open = 0.10, spin =  0, bob = 0 },
  { sway = {-1,  1, -2,  1}, open = 0.16, spin =  0, bob = -1 },
  { sway = { 1, -1,  1, -1}, open = 1.00, spin =  0, bob = -1 },   -- 한 프레임에 활짝
  { sway = { 2, -2,  2, -1}, open = 0.94, spin = 14, bob = 0 },
  { sway = { 1, -1,  1,  0}, open = 0.44, spin = 28, bob = 0 },    -- 반쯤 닫힌다
}

for f = 1, N do
  local o  = FR[f]
  local ox = (f-1)*SIDE
  local cx = 32

  -- ── 줄기 넷 (가운데가 꽃을 인다) ────────────────────────────────
  local S = {
    { cx-13, 48, cx-19 + o.sway[1], 24, 3, -2.0, true  },
    { cx+ 7, 47, cx+15 + o.sway[2], 27, 3,  2.4, true  },
    { cx+ 1, 49, cx+ 9 + o.sway[3], 34, 2,  1.4, true  },
    { cx- 5, 46, cx- 3 + o.sway[4], 18 + o.bob, 3, -1.6, false },
  }
  for _, s in ipairs(S) do stalk(ox, s[1], s[2], s[3], s[4], s[5], s[6], s[7]) end

  -- 가시 (재생 덩굴은 밟으면 아픈 것이다 — 곁줄기에만 붙인다)
  for _, th in ipairs({ {-16,38,-1}, {-18,30,-1}, {12,37,1}, {14,31,1}, {6,42,1} }) do
    local tx, ty, d = cx + th[1] + (o.sway[1]*0), th[2], th[3]
    put(ox, tx, ty, "16281c"); put(ox, tx + d, ty - 1, "25562e")
    put(ox, tx + d*2, ty - 2, "7a8c2e")
  end

  -- 잎 (자리·방향·크기가 제각각 — 균등 배치 금지)
  leaf(ox, cx-16 + o.sway[1], 33, -0.85, -0.30, 7, 2.4)
  leaf(ox, cx-11,             40,  0.55, -0.62, 5, 1.8)
  leaf(ox, cx+12 + o.sway[2], 33,  0.90, -0.24, 6, 2.2)
  leaf(ox, cx+ 6,             41, -0.42, -0.70, 4, 1.6)
  leaf(ox, cx+ 8 + o.sway[3], 38,  0.80, -0.42, 5, 1.9)
  leaf(ox, cx- 6,             28, -0.72, -0.52, 5, 2.0)
  leaf(ox, cx- 1,             26,  0.68, -0.58, 4, 1.7)

  -- ── 밑동 두둑 (이끼 덮인 뿌리) ──────────────────────────────────
  local opt = { cx=cx, cy=48, rx=23, ryTop=12, ryBot=13,
                wob={1.03,1.05,1.04,1.02,1.05,1.02,1.00,0.95,0.90,0.87,0.92,0.98},
                lamWob={0.00,0.10,-0.07,0.05,0.12,-0.06,0.03,0.11,-0.09,0.02,0.08,-0.04},
                ramp=RAMP, thr=THR, light={-0.52,-0.68,0.52}, sss=0.10, rim=0.28,
                core={0.30,0.12}, ground=GROUND }
  local mask = B.field(SIDE, SIDE, opt)
  local ol   = B.outline(mask, SIDE, SIDE, opt)
  for y = 0, SIDE-1 do for x = 0, SIDE-1 do
    if mask[y][x] then img:drawPixel(ox+x, y, C[ ol[y][x] and OLC[ol[y][x]] or RAMP[mask[y][x]] ]) end
  end end
  -- 🔴 매끈한 초록 돔은 「수박」으로 읽힌다 — 잎날을 겹쳐 덮어 덩굴 더미로 만든다.
  --    잎마다 각도·길이가 다르고, 밝은 쪽(왼위)에 밝은 잎을 몰아준다.
  local BLADE = { {-22,43, 0.95,-0.18, 14, 3.2, 1}, {-11,40, 0.88,-0.36, 11, 2.8, 1},
                  {  1,39, 0.84,-0.08, 15, 3.0, 0}, { 11,43, 0.76, 0.26, 13, 2.6, 0},
                  {-19,50, 0.98, 0.12, 16, 2.4, 0}, { -2,50, 0.94, 0.16, 14, 2.2, 0},
                  { -8,45,-0.94, 0.04, 10, 2.4, 1}, { 18,38, 0.62,-0.52,  9, 2.2, 0},
                  {-24,49,-0.70,-0.30,  8, 2.0, 1}, { 20,47, 0.80, 0.34, 10, 2.2, 0} }
  for _, bl in ipairs(BLADE) do
    local n = bl[5]
    for i = 0, n do
      local t = i/n
      local w = math.floor(bl[6] * math.sin(t*math.pi) + 0.5)
      local px = math.floor(cx + bl[1] + bl[3]*i + 0.5)
      local py = math.floor(bl[2] + bl[4]*i + 0.5)
      for k = -w, w do
        local col
        if k <= -w+1 then col = (bl[7] == 1) and "a8ca58" or "75a743"
        elseif k >= w then col = "16281c"
        elseif t < 0.45 then col = (bl[7] == 1) and "7a8c2e" or "468232"
        else col = "25562e" end
        put(ox, px, py + k, col)
      end
    end
  end
  -- 두둑 위 이끼 반점 (덩어리 2~3px — 1px 노이즈 금지)
  for _, m in ipairs({ {-15,42,3},{-4,39,2},{9,43,3},{-9,50,2},{14,47,2},{2,52,3} }) do
    for yy = 0, 1 do for xx = 0, m[3]-1 do
      putIn(ox, cx+m[1]+xx, m[2]+yy, (yy == 0) and "d0da91" or "a8ca58")
    end end
  end
  -- 접지 그늘
  for x = 0, SIDE-1 do
    if has(ox,x,GROUND) then putIn(ox, x, GROUND, "16281c") end
    if has(ox,x,GROUND-1) and math.abs(x-cx) < 16 then putIn(ox, x, GROUND-1, "19332d") end
  end

  -- ── 꽃 ─────────────────────────────────────────────────────────
  flower(ox, cx - 3 + o.sway[4], 17 + o.bob, o.open, o.spin)

  print(string.format("f%d open=%.2f %s", f-1, o.open, L.bbox(img, ox, SIDE)))
end

print("colors=" .. L.colorCount(img))
L.finish(spr, img, OUT .. "vine.png")
print("saved")
