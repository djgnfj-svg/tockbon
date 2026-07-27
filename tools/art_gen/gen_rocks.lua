-- 숲 바위 2종 — 세100 · takbon-art
--
-- 🔴 이건 **밑그림 생성기**다 (ART_SPEC §4 = 「생성기는 밑그림까지, 완성은 손질이 한다」).
--    실루엣은 **손으로 적은 꼭짓점 목록**이고, 면(facet) 경계도 **손으로 그은 두 직선**이다.
--    돌린 뒤엔 export → Read → 국소 수정 루프를 돈다. (표 밖의 값을 수식으로 만들지 않는다.)
--
-- 🔴🔴 **나무와 일부러 반대로 만든다.** 나무는 부드러운 잎덩이 + 둥근 실루엣 + 초록이다.
--    바위가 같은 결이면 한 화면에 놓았을 때 「같은 것이 크기만 다르게」 보인다 →
--      · 실루엣: **각지고 가로로 넓다**(나무는 세로로 길다)
--      · 음영: **평면 세 장(facet)**이 딱 갈린다(나무는 덩이마다 둥글게 돈다)
--      · 색: **무채**(나무는 초록/갈색)
--    이 세 축이 갈려야 「기둥 밭」이 아니라 숲 바닥이 된다.
--
-- 팔레트: TAKBON 60만. 광원: 왼쪽 위 고정. 표시 배율 x1.
-- rock_big  프레임 80x64 · 접지선 row 56
-- rock      프레임 28x22 · 접지선 row 19

local ROOT = "C:/Users/djgnf/Desktop/godot_games/tockbon/"
local ART  = ROOT .. "assets/aseprite/"
local OUT  = ROOT .. "assets/sprites/field/"

----------------------------------------------------------------------
-- 색 (전부 TAKBON 60)
----------------------------------------------------------------------
local C = {
  -- 돌 사다리 (밝음 -> 어두움). 명도 204/176/144/106/81/69/44/28
  r1 = "C7CFCC", r2 = "A8B5B2", r3 = "819796", r4 = "577277",
  r5 = "4E5259", r6 = "394A50", r7 = "2A2C32", r8 = "151D28",
  -- 이끼 (바위를 풀밭에 **박아 넣는** 색 — 이게 없으면 붙여 놓은 스티커가 된다)
  m1 = "75A743", m2 = "468232", m3 = "25562E", m4 = "19332D", m5 = "16281C",
  -- 고인 차가운 빛 (세계관 — 발광이 아니라 색조다)
  c1 = "2F6152", c2 = "3FA9A0",
}
-- 사다리는 **끝까지 무채**다.
--
-- 🔴🔴 5회차에 여섯 장을 한 줄로 세워 보니 **바위만 완전 무채**라 「다른 게임에서 온 것」 같았다
--   (나머지 다섯은 전부 채도 있는 초록·갈색). 그래서 중간 한 칸(4E5259, 명도 81)을
--   청록 2F6152(명도 80)로 갈아 봤는데 — **6회차 x5 검수에서 실패로 판정했다**:
--   명도가 같아도 **채도가 다르면 얼룩이 색 반점으로 튄다.** 앞면이 회색인데 그 사이에
--   청록이 점점이 박혀 「이끼」도 「광물」도 아닌 지저분한 점이 됐다(§3-5 고립 노이즈).
--   🔴 **색조는 사다리(명암 축)에 실으면 안 된다** — 이 프로젝트가 죽은 나무에서 이미 배운 것과
--     같은 실수다(gen_trees.lua의 GREY_OF 머리말 참조). 색조는 **넓은 얼룩**으로 따로 얹는다.
local STONE = { C.r1, C.r2, C.r3, C.r4, C.r5, C.r6, C.r7, C.r8 }

----------------------------------------------------------------------
-- 버퍼 (gen_trees.lua와 같은 idiom)
----------------------------------------------------------------------
local Buf = {}
Buf.__index = Buf
function Buf.new(w, h) return setmetatable({ w = w, h = h, p = {} }, Buf) end
function Buf:set(x, y, c)
  x = math.floor(x); y = math.floor(y)
  if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
  self.p[y * self.w + x] = c
end
function Buf:get(x, y)
  x = math.floor(x); y = math.floor(y)
  if x < 0 or y < 0 or x >= self.w or y >= self.h then return nil end
  return self.p[y * self.w + x]
end

local function hexcol(h)
  return app.pixelColor.rgba(
    tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 255)
end

local function save(buf, name)
  local spr = Sprite(buf.w, buf.h, ColorMode.RGB)
  local img = Image(buf.w, buf.h, ColorMode.RGB)
  for y = 0, buf.h - 1 do
    for x = 0, buf.w - 1 do
      local c = buf:get(x, y)
      if c then img:putPixel(x, y, hexcol(c)) end
    end
  end
  spr.cels[1].image = img
  spr.cels[1].position = Point(0, 0)
  spr:saveAs(ART .. name .. ".aseprite")
  spr:saveCopyAs(OUT .. name .. ".png")
  spr:close()
  print("saved " .. name)
end

local function hsh(x, y, s)
  local v = math.sin(x * 12.9898 + y * 78.233 + s * 37.719) * 43758.5453
  return v - math.floor(v)
end

local function clampi(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

----------------------------------------------------------------------
-- 손으로 적은 꼭짓점 목록을 채운다 (스캔라인)
----------------------------------------------------------------------
local function fill_poly(mask, w, h, pts)
  local ymin, ymax = 1e9, -1e9
  for _, p in ipairs(pts) do
    if p[2] < ymin then ymin = p[2] end
    if p[2] > ymax then ymax = p[2] end
  end
  for y = math.floor(ymin), math.ceil(ymax) do
    local sy = y + 0.5
    local xs = {}
    local n = #pts
    for i = 1, n do
      local a, b = pts[i], pts[i % n + 1]
      if (a[2] <= sy and b[2] > sy) or (b[2] <= sy and a[2] > sy) then
        xs[#xs + 1] = a[1] + (b[1] - a[1]) * (sy - a[2]) / (b[2] - a[2])
      end
    end
    table.sort(xs)
    for i = 1, #xs - 1, 2 do
      for x = math.floor(xs[i] + 0.5), math.floor(xs[i + 1] + 0.5) do
        if x >= 0 and y >= 0 and x < w and y < h then mask[y * w + x] = true end
      end
    end
  end
end

-- 직선 한 줄의 어느 쪽인가 (양수 = 왼/위쪽). 면 경계를 **손으로 긋기** 위한 자.
local function side(p1, p2, x, y)
  return (p2[1] - p1[1]) * (y + 0.5 - p1[2]) - (p2[2] - p1[2]) * (x + 0.5 - p1[1])
end

----------------------------------------------------------------------
-- 외곽선 — 하중 쪽만 2px (gen_trees.lua와 같은 계약)
----------------------------------------------------------------------
local LX, LY = 0.56, 0.83

local function outline(buf, light_c, dark_c)
  local w, h = buf.w, buf.h
  local edge = {}
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if buf:get(x, y) ~= nil then
        local ou = buf:get(x, y - 1) == nil
        local od = buf:get(x, y + 1) == nil
        local ol = buf:get(x - 1, y) == nil
        local orr = buf:get(x + 1, y) == nil
        if ou or od or ol or orr then
          local sx = (ol and -1 or 0) + (orr and 1 or 0)
          local sy = (ou and -1 or 0) + (od and 1 or 0)
          local lit = (-sx) * LX + (-sy) * LY
          edge[y * w + x] = (lit > 0.15) and 1 or ((lit < -0.55) and 3 or 2)
        end
      end
    end
  end
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local e = edge[y * w + x]
      if e == 1 then
        buf:set(x, y, light_c)
      elseif e then
        buf:set(x, y, dark_c)
        if e == 3 then
          for _, d in ipairs({ { 0, -1 }, { -1, 0 } }) do
            local nx, ny = x + d[1], y + d[2]
            if buf:get(nx, ny) ~= nil and not edge[ny * w + nx] then buf:set(nx, ny, dark_c) end
          end
        end
      end
    end
  end
end

-- 🔴 광원이 왼쪽 위니 그림자는 오른쪽 아래로 흐른다 (나무와 같은 계약 — 한 화면에 서면 바로 비교된다)
local function ground_shadow(buf, cx, cy, rx, ry, seed)
  for y = math.floor(cy - ry) - 1, math.floor(cy + ry) + 1 do
    for x = math.floor(cx - rx) - 1, math.floor(cx + rx) + 1 do
      local nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
      local d = nx * nx + ny * ny
      local wob = 0.10 * math.sin(x * 0.41 + y * 0.9 + seed) + 0.06 * math.sin(x * 1.13 - seed)
      if d + wob <= 1.0 and buf:get(x, y) == nil then
        buf:set(x, y, (d + wob > 0.62) and C.m4 or C.m5)
      end
    end
  end
end

local function dots(buf, list, col, only_if)
  for _, p in ipairs(list) do
    local cur = buf:get(p[1], p[2])
    if cur ~= nil and (only_if == nil or only_if(cur)) then buf:set(p[1], p[2], col) end
  end
end

-- 지금 색에서 사다리를 n칸 옮긴다 (밝게 = 음수). 고정색을 박지 않아야 면마다 어울린다.
local function step_tone(buf, x, y, n)
  local cur = buf:get(x, y)
  if cur == nil then return end
  for i, s in ipairs(STONE) do
    if cur == s then buf:set(x, y, STONE[clampi(i + n, 1, 8)]); return end
  end
end

-- 손으로 적은 마디를 잇는 금 (crack). 면 경계를 따라 그어야 「깨진 돌」로 읽힌다.
--
-- 🔴🔴 1회차에 **정반대로 그렸다**: 홈의 **위쪽** 입술을 밝게 찍어서 금이 「흰 실」이 됐다.
--   광원이 위쪽이면 V홈의 **위쪽 벽은 빛을 등지고(어둡다)** 아래쪽 벽이 빛을 받는다.
--   게다가 고정색 819796을 박아 면 색과 무관하게 튀었다 → **사다리 한 칸**만 움직인다.
local function crack(buf, nodes, deep)
  for i = 1, #nodes - 1 do
    local a, b = nodes[i], nodes[i + 1]
    local n = math.max(math.abs(b[1] - a[1]), math.abs(b[2] - a[2]))
    for s = 0, n do
      local x = math.floor(a[1] + (b[1] - a[1]) * s / n + 0.5)
      local y = math.floor(a[2] + (b[2] - a[2]) * s / n + 0.5)
      if buf:get(x, y) ~= nil then
        step_tone(buf, x, y, deep and 3 or 2)          -- 금 = 어둡게
        -- ⚠ 2회차: 아랫벽을 3에 2번 밝혔더니 여전히 **연속된 밝은 실선**이었다 → 4에 1번.
        -- ⚠ 3회차: 그래도 V자 흰 선이 보였다 → **깊은 금(deep)은 아랫벽을 아예 안 밝힌다.**
        --   금은 「선」이 아니라 「띄엄띄엄 빛이 걸리는 홈」으로 읽혀야 한다.
        if not deep and s % 4 == 0 then step_tone(buf, x, y + 1, -1) end
      end
    end
  end
end

-- 🔴 겹쳐 놓은 돌의 **자기 테두리**를 긋는다 — 안 그으면 큰 돌에 흡수된다(1·2·3회차 다 그랬다).
--   빛 쪽(왼위)은 밝게 · 그늘 쪽은 어둡게. **한 색으로 두르면 스티커**가 되고,
--   어두운 색으로만 두르면 큰 바위의 그늘 면 위에서 **아예 안 보인다**(3회차가 그 상태).
local function edge_of(buf, m, w, h, light_c, dark_c)
  local todo = {}
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if m[y * w + x] then
        local ou = not m[(y - 1) * w + x]
        local od = not m[(y + 1) * w + x]
        local ol = not m[y * w + x - 1]
        local orr = not m[y * w + x + 1]
        if ou or od or ol or orr then
          local sx = (ol and -1 or 0) + (orr and 1 or 0)
          local sy = (ou and -1 or 0) + (od and 1 or 0)
          todo[#todo + 1] = { x, y, ((-sx) * LX + (-sy) * LY) > 0.15 }
        end
      end
    end
  end
  for _, p in ipairs(todo) do buf:set(p[1], p[2], p[3] and light_c or dark_c) end
end

-- 폴리곤 테두리만 긋는다
local function stroke_poly(buf, pts, col)
  for i = 1, #pts do
    local a, b = pts[i], pts[i % #pts + 1]
    local n = math.max(math.abs(b[1] - a[1]), math.abs(b[2] - a[2]))
    for s = 0, n do
      local x = math.floor(a[1] + (b[1] - a[1]) * s / n + 0.5)
      local y = math.floor(a[2] + (b[2] - a[2]) * s / n + 0.5)
      if buf:get(x, y) ~= nil then buf:set(x, y, col) end
    end
  end
end

----------------------------------------------------------------------
-- 면 셋으로 칠한다 — 🔴 이게 「바위」의 몸이다.
--   나무는 덩이마다 둥글게 도는 음영이고, 바위는 **평면이 딱 갈린다.**
--   면 안에서는 아주 얕은 기울기만 준다(평면이니까). 경계에서 값이 **뚝** 떨어져야 각져 보인다.
----------------------------------------------------------------------
local function shade_facets(buf, mask, w, h, L1a, L1b, L2a, L2b, tone, seed)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if mask[y * w + x] then
        local base, dark_face = nil, false
        if L2a ~= nil and side(L2a, L2b, x, y) < 0 then
          base = tone[3]; dark_face = true                 -- 오른쪽 면 (가장 어둡다)
        elseif side(L1a, L1b, x, y) < 0 then
          base = tone[1]                                   -- 윗면 (볕을 받는다)
        else
          base = tone[2]                                   -- 앞면
        end
        -- 면 안의 얕은 기울기 (오른쪽 아래로 갈수록 살짝 어둡다)
        local v = base + (x - w * 0.4) * 0.013 + (y - h * 0.35) * 0.020
        -- 🔴 반사광 — 그늘 면 **아래쪽**은 땅에서 튕겨 온 빛을 받는다.
        --   ⚠ 2회차엔 이게 없어서 오른쪽 면이 통째로 검은 덩어리가 됐다(형태가 죽었다).
        if dark_face and y > h * 0.58 then v = v - 0.9 end
        buf:set(x, y, STONE[clampi(math.floor(v + 0.5), 1, 8)])
      end
    end
  end
end

-- 광물 얼룩 — ⚠ 1회차엔 `hsh(x/3, y/3)` 격자였는데 화면에서 **체크무늬**로 읽혔다(진단 ③).
--   격자를 버리고 흩뿌린다. 얼룩은 사다리 한 칸만 움직여 면의 평평함을 안 깬다.
local function mottle(buf, mask, w, h, seed, n)
  local BLOB = {
    { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 1, 1 } },
    { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } },
    { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 } },
    { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 1, 2 } },
  }
  local rs = math.floor(seed * 7919) % 2147483646 + 1
  local function rnd() rs = (rs * 16807) % 2147483647; return rs / 2147483647 end
  for _ = 1, n do
    local px, py = math.floor(rnd() * w), math.floor(rnd() * h)
    local m = BLOB[1 + math.floor(rnd() * 4) % 4]
    local d = (rnd() < 0.55) and 1 or -1
    for _, q in ipairs(m) do
      local x, y = px + q[1], py + q[2]
      if x >= 0 and y >= 0 and x < w and y < h and mask[y * w + x] then step_tone(buf, x, y, d) end
    end
  end
end

----------------------------------------------------------------------
-- ① rock_big — 나무(128)와 덤불(35) 사이를 메우는 덩어리. 화면 키 64px.
----------------------------------------------------------------------
local function rock_big()
  local W, H = 80, 64
  local buf = Buf.new(W, H)
  local mask = {}

  -- 손으로 적은 실루엣 — **가로로 넓고 각지다**(나무와 반대 리듬).
  -- ⚠ 1회차: 꼭짓점 11개에 각도 변화가 완만해 **식빵 돔**이 됐다. 9개로 줄이고 **긴 직선**을 뒀다:
  --   납작한 윗면 · 완만한 왼 어깨 · 뚝 떨어지는 오른쪽 = 좌우가 안 맞는다(진단 ①).
--
  -- 🔴🔴 **곁돌은 뺐다.** 1·2·3회차에 「기대어 선 작은 돌」을 오른쪽 아래에 붙였는데 세 번 다
  --   큰 바위에 **흡수**됐다(색을 밝혀도, 테두리를 둘러도). 80x64에서 큰 바위가 거의 전부를
  --   차지하니 곁돌이 설 자리가 없다 — 겹친 실루엣은 **더 큰 캔버스에서만** 읽힌다.
  --   실루엣 다양성은 대신 **오른쪽 아래의 각진 단(shelf)**이 낸다: (76,38)→(69,42)→(74,50).
  -- ⚠ 실측으로 잡은 것: 처음 표는 실루엣이 **61px**이라 확정치 64에 3px 모자랐다
  --   (「화면 키」는 눈이 아니라 자로 재야 한다 — ART_SPEC §1이 그래서 두 칸짜리 표다).
  local MAIN = {
    { 3, 46 }, { 11, 21 }, { 30, 3 }, { 48, 0 }, { 66, 15 },
    { 76, 38 }, { 69, 42 }, { 74, 50 }, { 64, 56 }, { 30, 56 }, { 7, 53 },
  }
  fill_poly(mask, W, H, MAIN)

  -- 면 경계 = 손으로 그은 두 직선. L1 = 윗면/앞면 · L2 = 앞면/오른쪽면
  -- ⚠ 1회차 톤(2.7/4.4/6.0)은 밝은 풀 위에서 **바위만 하얗게 떴다** — 나무는 어두운데 혼자 밝으면
  --   한 결로 안 읽힌다. 한 단 내렸다.
  shade_facets(buf, mask, W, H, { 2, 44 }, { 58, 2 }, { 52, 0 }, { 66, 58 },
    { 3.6, 5.2, 6.0 }, 3.7)
  -- ⚠ 4회차: 곁돌을 빼니 앞면이 밋밋해졌다 → 얼룩을 90 → 130으로.
  mottle(buf, mask, W, H, 3.7, 55)

  -- 금 — ⚠ 2회차엔 면 경계(L1)를 따라 긴 금을 하나 더 그었는데, **면 경계가 이미 그 일을 한다.**
  --   금까지 겹치니 「흰 실을 붙인 것」이 됐다 → 짧게 둘로 쪼개고 앞면 가로 금만 남긴다.
  crack(buf, { { 19, 30 }, { 26, 24 } }, true)
  crack(buf, { { 38, 14 }, { 46, 10 } }, true)
  -- ⚠ 3회차: 앞면 가로 금이 아직 **V자 흰 선**으로 읽혔다 → 밝은 아랫벽이 없는 깊은 금으로, 더 짧게.
  crack(buf, { { 24, 43 }, { 33, 39 } }, true)
  crack(buf, { { 40, 41 }, { 47, 44 } }, true)
  crack(buf, { { 63, 25 }, { 66, 32 } }, false)

  -- 🔴 이끼 — **바위를 풀밭에 박아 넣는다.** 윗면 어깨와 밑동에 손으로 얹는다.
  --   이게 없으면 아무리 잘 그려도 「풀 위에 올려 둔 돌」로 보인다.
  -- ⚠ 1회차: 이끼가 **초록 점 몇 개**로 흩어져 이물질로 보였다 → 손으로 적은 **덩어리**로 뭉치고,
  --   밑동은 통째로 두른다(풀에 파묻힌 자리). 덩어리 안에서만 가장자리를 해시로 갉는다.
  local function is_stone(c)
    for _, s in ipairs(STONE) do if c == s then return true end end
    return false
  end
  -- { cx, cy, rx, ry, 종류 } — "top"=볕 받는 윗면 이끼 · "base"=밑동 그늘 이끼 ·
  -- 🔴 "lichen"=**넓은 지의류 얼룩**. 6회차 신설: 바위를 숲 물건으로 만드는 색조를 여기서 준다
  --   (사다리에 청록을 끼워 넣었다가 색 반점으로 튀어 실패했다 — 위 STONE 머리말 참조).
  --   넓은 면적이라 「이끼 낀 화강암」으로 읽히고, 점으로 흩어지지 않는다.
  --
  -- 🔴🔴 6회차 실패에서 나온 규칙: `d < 0.45`면 **무조건 채웠더니** 얼룩이 **완벽한 타원**이 됐다
  --   — 앞면에 곰팡이 자국 같은 동그라미 셋이 나란히 났다(진단 ①: 완벽한 대칭).
  --   → **코어를 확정으로 채우지 않는다.** 중심에서 멀어질수록 확률이 떨어지게만 하면
  --     경계가 저절로 너덜해지고 덩어리 모양이 매번 달라진다.
  --   앞면 지의류는 크게 넷 → 작게 여섯으로 흩고, 밑동 이끼는 위로 더 번지게 했다
  --   (실제 바위도 아래쪽이 이끼가 많다 — 초록기는 거기서 얻는 게 자연스럽다).
  for _, k in ipairs({ { 17, 25, 7, 5, "top" }, { 31, 11, 6, 4, "top" }, { 44, 7, 5, 3, "top" },
                       { 12, 46, 9, 7, "base" }, { 27, 51, 12, 7, "base" },
                       { 45, 52, 10, 6, "base" }, { 63, 53, 8, 5, "base" },
                       { 22, 36, 6, 4, "lichen" }, { 49, 28, 5, 5, "lichen" },
                       { 36, 45, 6, 4, "lichen" }, { 60, 42, 4, 4, "lichen" },
                       { 30, 20, 4, 3, "lichen" }, { 55, 47, 5, 3, "lichen" } }) do
    for dy = -k[4], k[4] do
      for dx = -k[3], k[3] do
        local nx, ny = dx / k[3], dy / k[4]
        local d = nx * nx + ny * ny
        -- ⚠ 7회차: 확률만 쓰니 이번엔 가장자리가 **1px 별/가시** 모양으로 성겼다(§3-5 위반).
        --   해시를 **2px 블록**으로 물려 최소 덩어리를 2x2로 보장하고, 아주 작은 코어만 확정으로 채운다.
        if d <= 1.0 and (d < 0.28
            or hsh(math.floor((k[1] + dx) / 2), math.floor((k[2] + dy) / 2), 8.1) < (1.0 - d) * 1.15) then
          local cur = buf:get(k[1] + dx, k[2] + dy)
          if cur ~= nil and is_stone(cur) then
            -- ⚠ 3·4회차: 밝은 초록이 뭉쳐 **나뭇잎**처럼 보였다 → 밝은 점을 아예 안 쓰고
            --   m3/m4(어두운 초록) 둘로만 간다. 이끼는 「초록 얼룩」이지 「잎」이 아니다.
            if k[5] == "top" then
              buf:set(k[1] + dx, k[2] + dy, (d > 0.55) and C.m4 or C.m3)
            elseif k[5] == "base" then
              buf:set(k[1] + dx, k[2] + dy, (dy < 0) and C.m4 or C.m5)
            else
              -- 지의류는 **돌의 명암을 따라간다** — 밝은 돌 위에선 옅고 그늘에선 짙다.
              --   (돌 색을 무시하고 한 색으로 덮으면 그림 위에 붙인 스티커가 된다.)
              local light = (cur == C.r1 or cur == C.r2 or cur == C.r3)
              buf:set(k[1] + dx, k[2] + dy, light and C.c1 or ((d > 0.6) and C.m5 or C.m4))
            end
          end
        end
      end
    end
  end

  -- 고인 차가운 빛 — **금 안쪽에만**. 발광이 아니라 그늘 속 색점이다(침엽수와 같은 어법).
  dots(buf, { { 28, 22 }, { 29, 22 }, { 30, 22 }, { 29, 23 } }, C.c1)
  dots(buf, { { 29, 22 } }, C.c2)

  outline(buf, C.r5, C.r8)
  ground_shadow(buf, 40, 57, 36, 7, 1.9)
  return buf
end

----------------------------------------------------------------------
-- ② rock — 바닥에 흩는 작은 돌. 프레임·크기는 옛것 그대로(28x22), 손질·팔레트만 새로.
----------------------------------------------------------------------
local function rock_small()
  local W, H = 28, 22
  local buf = Buf.new(W, H)
  local mask = {}

  -- 큰 돌 하나 + 곁에 조약돌 하나 = 「흩어져 있다」로 읽힌다 (한 덩이면 그냥 혹이다)
  fill_poly(mask, W, H, { { 3, 15 }, { 5, 9 }, { 10, 5 }, { 16, 4 }, { 20, 8 }, { 21, 14 }, { 18, 18 }, { 7, 18 } })
  fill_poly(mask, W, H, { { 20, 13 }, { 24, 11 }, { 26, 15 }, { 24, 18 }, { 20, 18 } })

  -- 작은 돌은 면이 둘이면 충분하다 (L2 없음). 큰 바위와 같은 톤대를 쓴다(한 결로 읽히게).
  shade_facets(buf, mask, W, H, { 1, 16 }, { 20, 3 }, nil, nil, { 3.7, 5.4, 6.6 }, 5.5)
  mottle(buf, mask, W, H, 5.5, 14)

  crack(buf, { { 8, 12 }, { 13, 9 }, { 17, 8 } }, true)
  dots(buf, { { 6, 16 }, { 7, 17 }, { 12, 17 }, { 13, 17 }, { 16, 17 }, { 22, 17 } }, C.m5)
  dots(buf, { { 4, 12 }, { 5, 12 } }, C.m3)

  outline(buf, C.r5, C.r8)
  ground_shadow(buf, 15, 19, 12, 3, 4.2)
  return buf
end

----------------------------------------------------------------------
local only = TAKBON_ONLY
if only == nil or only == "rock_big" then save(rock_big(), "rock_big") end
if only == nil or only == "rock" then save(rock_small(), "rock") end
print("done")
