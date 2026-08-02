-- 숲 나무 3종 + 덤불
-- 🔴 밑그림 생성기다 — 수관은 손으로 적은 잎덩이 좌표표(CLUMPS)고, 가지는 손으로 적은 마디 사슬(NODES)이다.
-- 🔴 바닥은 #468232 밝은 풀이다(boss_room GRASS_TILE_BASE) — 수관 지배색을 같은 색으로 두면 나무가 바닥에 녹는다.
--    그래서 바닥보다 어둡고 차가운 덩어리 + 어두운 테두리로 간다.
-- 팔레트: TAKBON 60만. 광원: 왼쪽 위 고정. 표시 배율 ×1.
-- 프레임 128x128 (나무 3종) / 48x40 (덤불). 접지선 = row 120 (덤불 33).

local ROOT = "C:/Users/djgnf/Desktop/godot_games/tockbon/"
local ART  = ROOT .. "assets/aseprite/"
local OUT  = ROOT .. "assets/sprites/field/"

----------------------------------------------------------------------
-- 색 (전부 TAKBON 60)
----------------------------------------------------------------------
local C = {
  -- 잎 사다리 (밝음 → 어두움). 4=올리브·6=청록이 섞여 있어 빛은 따뜻하고 그늘은 차갑다.
  g1 = "D0DA91", g2 = "A8CA58", g3 = "75A743", g4 = "7A8C2E",
  g5 = "468232", g6 = "25562E", g7 = "19332D", g8 = "16281C",
  -- 이질적인 차가운 색조 ("있어선 안 될 곳이 반짝인다" — 발광이 아니라 색조다)
  c1 = "2F6152", c2 = "3FA9A0",
  -- 나무껍질
  b1 = "D7B594", b2 = "C09473", b3 = "AD7757", b4 = "884B2B",
  b5 = "7A4841", b6 = "4D2B32", b7 = "341C27", b8 = "2E1F18",
  -- 바랜 무채 (죽은 나무 전용 — 빛이 빠져나간 자리)
  s2 = "A8B5B2", s3 = "819796", s4 = "577277", s5 = "394A50", s6 = "2A2C32",
}

local LEAF = { C.g1, C.g2, C.g3, C.g4, C.g5, C.g6, C.g7, C.g8 }
local WOOD = { C.b1, C.b2, C.b3, C.b4, C.b5, C.b6, C.b7, C.b8 }

-- 🔴🔴 풍화(무채) 대응표 — WOOD의 각 단계와 **같은 밝기의 무채**.
-- 🔴 **색조 변화는 광원 축이 아니다.** 풍화는 나무가 어느 쪽으로 썩었느냐이지 어디가 그늘이냐가
--   아니다 → 사다리는 따뜻한 WOOD 그대로 두고, **광원과 무관한 얼룩**으로 무채를 얹는다.
local GREY_OF = { C.s2, C.s3, C.s3, C.s4, C.s4, C.s5, C.s6, C.b8 }

----------------------------------------------------------------------
-- 버퍼
----------------------------------------------------------------------
local Buf = {}
Buf.__index = Buf
function Buf.new(w, h)
  return setmetatable({ w = w, h = h, p = {} }, Buf)
end
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

-- 결정적 해시 (0..1)
local function hsh(x, y, s)
  local v = math.sin(x * 12.9898 + y * 78.233 + s * 37.719) * 43758.5453
  return v - math.floor(v)
end

local function clampi(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

----------------------------------------------------------------------
-- 잎덩이 수관 — 손으로 적은 타원 목록의 합집합.
--   각 덩이가 자기 중심 기준으로 음영을 받는다(= 실루엣 오프셋 복사가 아니다).
--   base = 그 덩이의 기본 어둠(뒤에 묻힌 덩이일수록 크다) — 손으로 적었다.
----------------------------------------------------------------------
local LX, LY = 0.56, 0.83  -- 광원 = 왼쪽 위

-- 잎 뭉치 도장 4종 (손으로 그린 5~8px 덩어리 — 1px 노이즈 금지)
local TUFT = {
  { {0,0},{1,0},{2,0},{0,1},{1,1},{2,1},{1,2} },
  { {0,0},{1,0},{-1,1},{0,1},{1,1},{2,1},{0,2},{1,2} },
  { {0,0},{1,0},{2,0},{3,0},{1,1},{2,1} },
  { {1,0},{0,1},{1,1},{2,1},{1,2},{2,2} },
}

-- 잎덩이 항목 = { cx, cy, rx, ry, base, himin }
--   himin = 이 덩이가 닿을 수 있는 가장 밝은 단계. 🔴 하이라이트를 몇 덩이에만 허용해 시선을 몰아준다.
local function canopy(buf, clumps, seed, opt)
  opt = opt or {}
  local cool = opt.cool or {}        -- 사다리 단계 → 차가운 색 치환 (침엽수)
  local lvl, cap = {}, {}
  for y = 0, buf.h - 1 do
    for x = 0, buf.w - 1 do
      local best, bd, second = nil, -1e9, -1e9
      for i = 1, #clumps do
        local k = clumps[i]
        local nx = (x + 0.5 - k[1]) / k[3]
        local ny = (y + 0.5 - k[2]) / k[4]
        local d = 1.0 - (nx * nx + ny * ny)
        if d > 0 then
          if d > bd then second = bd; bd = d; best = i
          elseif d > second then second = d end
        end
      end
      if best then
        local k = clumps[best]
        local nx = (x + 0.5 - k[1]) / k[3]
        local ny = (y + 0.5 - k[2]) / k[4]
        -- 덩이 **자기 표면** 기준 명암 (왼쪽 위가 밝다) — 실루엣 오프셋 복사가 아니다
        local t = (-nx) * LX + (-ny) * LY
        local v = k[5] - t * 1.9
        -- 🔴🔴 덩이 테두리를 **방향에 따라 갈라 쓴다** — 이게 「잎덩이가 여럿」을 만드는 몸이다.
        --   왼쪽 위 호(t>0.3)는 **밝게 튄다**(볕 받는 잎 등) · 나머지 호는 **진한 골**이 된다.
        --   밝은 쪽이 없으면 골이 텍스처에 묻혀 덩이가 안 선다.
        -- ⚠ 밴드 폭을 고정하면 덩이마다 똑같은 굵기의 초승달이 붙어 오히려 기계로 보인다 — 각도에 따라 출렁이고 덩이마다 위상이 다르다.
        local ang = math.atan(ny, nx)
        local band = 0.065 + 0.06 * math.abs(math.sin(ang * 3.0 + k[1] * 0.7))
        local rim = 1.0 - math.min(bd / band, 1.0)
        -- k[7] = 이 덩이의 하이라이트 세기. 🔴 좌상단 덩이만 세다 = 시선이 거기 몰린다.
        v = v + rim * ((t > 0.30) and -1.6 * (k[7] or 1.0) or 2.5)
        lvl[y * buf.w + x] = v
        cap[y * buf.w + x] = k[6] or 3
      end
    end
  end

  -- 잎 뭉치 texture — 🔴 격자로 놓으면 오프셋이 수관 전체에 사선 빗금을 긋는다(잎이 아니라 무늬로 읽힌다).
  --   흩뿌리기(Park-Miller)로 놓고 진폭도 낮춘다 — 덩이 테두리가 형태를 쥐므로 텍스처는 거들기만 하면 된다.
  local sp = opt.tuft_spacing or 4
  local rs = math.floor(seed * 7919) % 2147483646 + 1
  local function rnd()
    rs = (rs * 16807) % 2147483647
    return rs / 2147483647
  end
  for _ = 1, math.floor(buf.w * buf.h / (sp * sp) * 1.35) do
    local px = math.floor(rnd() * buf.w)
    local py = math.floor(rnd() * buf.h)
    local m = TUFT[1 + math.floor(rnd() * 4) % 4]
    local r = rnd()
    -- ⚠ 어둡히는 도장이 잦으면 수관 전체에 깨알 후추가 뿌려진다.
    local d = (r < 0.30) and 0.95 or ((r < 0.62) and -0.65 or 0.0)
    if d ~= 0.0 then
      for _, q in ipairs(m) do
        local i = (py + q[2]) * buf.w + (px + q[1])
        -- 🔴 볕 받는 덩이(cap<=2)엔 어둡히는 도장을 안 찍는다 — 하이라이트가 지저분해진다. 그늘 쪽에만 잎 그림자를 준다.
        if lvl[i] and not (d > 0 and (cap[i] or 3) <= 2) then lvl[i] = lvl[i] + d end
      end
    end
  end

  for y = 0, buf.h - 1 do
    for x = 0, buf.w - 1 do
      local i = y * buf.w + x
      if lvl[i] then
        local n = clampi(math.floor(lvl[i] + 0.5), cap[i], 8)
        buf:set(x, y, cool[n] or LEAF[n])
      end
    end
  end
end

----------------------------------------------------------------------
-- 외곽선 — 🔴 굵기가 어디나 같으면 스티커가 된다.
--   왼쪽 위(빛 쪽)는 1px에 한 단 밝은 그늘색 · 오른쪽 아래(하중 쪽)는 2px 최암부.
----------------------------------------------------------------------
local function outline(buf, mask_of, light_c, dark_c)
  local w, h = buf.w, buf.h
  local edge = {}
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if mask_of(buf, x, y) then
        local open_up = not mask_of(buf, x, y - 1)
        local open_dn = not mask_of(buf, x, y + 1)
        local open_l  = not mask_of(buf, x - 1, y)
        local open_r  = not mask_of(buf, x + 1, y)
        if open_up or open_dn or open_l or open_r then
          -- 이 가장자리가 빛 쪽인가 그늘 쪽인가
          local sx = (open_l and -1 or 0) + (open_r and 1 or 0)
          local sy = (open_up and -1 or 0) + (open_dn and 1 or 0)
          local lit = (-sx) * LX + (-sy) * LY
          -- 3 = **하중이 실린 자리**(정오른쪽·정아래)만 2px로 두껍다.
          -- ⚠ lit<=0.15를 전부 2px로 깔면 아래 둘레에 균일한 검은 띠가 생긴다.
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
            if mask_of(buf, nx, ny) and not edge[ny * w + nx] then buf:set(nx, ny, dark_c) end
          end
        end
      end
    end
  end
end

----------------------------------------------------------------------
-- 굵은 가지 — 손으로 적은 마디 사슬 {x, y, 반지름}
----------------------------------------------------------------------
local function stamp_disc(mask, w, h, cx, cy, r)
  local ri = math.ceil(r)
  for dy = -ri, ri do
    for dx = -ri, ri do
      if dx * dx + dy * dy <= r * r + 0.4 then
        local x, y = math.floor(cx + dx), math.floor(cy + dy)
        if x >= 0 and y >= 0 and x < w and y < h then mask[y * w + x] = true end
      end
    end
  end
end

local function limb(mask, w, h, nodes)
  for i = 1, #nodes - 1 do
    local a, b = nodes[i], nodes[i + 1]
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local n = math.max(math.abs(dx), math.abs(dy)) * 2
    for s = 0, n do
      local u = s / n
      stamp_disc(mask, w, h, a[1] + dx * u, a[2] + dy * u, (a[3] + (b[3] - a[3]) * u) * 0.5)
    end
  end
end

-- 마스크를 광원 방향으로 「행진」시켜 음영을 만든다 —
-- 위쪽 왼쪽 가장자리에서 몇 칸 안쪽인가 = 그 자리의 밝기. 형태를 따라간다.
local function shade_mask(buf, mask, w, h, ramp, base, span, seed, bleach)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if mask[y * w + x] then
        local k = span
        for s = 1, span do
          local sx = math.floor(x - LX * s + 0.5)
          local sy = math.floor(y - LY * s + 0.5)
          if sx < 0 or sy < 0 or sx >= w or sy >= h or not mask[sy * w + sx] then k = s - 1; break end
        end
        local kd = span
        for s = 1, span do
          local sx = math.floor(x + LX * s + 0.5)
          local sy = math.floor(y + LY * s + 0.5)
          if sx < 0 or sy < 0 or sx >= w or sy >= h or not mask[sy * w + sx] then kd = s - 1; break end
        end
        local v = base + (k - kd) * 0.5
        -- 세로결 (나무껍질) — 2~3px 덩어리로만
        if hsh(math.floor(x / 2), math.floor(y / 3), seed) < 0.26 then v = v + 0.8 end
        local n = clampi(math.floor(v + 0.5), 1, 8)
        local col = ramp[n]
        -- 🔴 풍화 얼룩 — **밝기는 그대로 두고 색조만 무채로** 뺀다 = 「색이 빠져나간 자리」.
        --   광원과 무관한 3x4 덩어리 해시라 줄이 안 생긴다.
        -- ⚠ 두 조건을 곱해야 한다 — ⓐ 볕 받는 쪽(k<=2)이고 ⓑ 얼룩 해시에 걸릴 것. ⓐ만 쓰면 「테이프」, ⓑ만 쓰면 「가운데 띠」가 된다.
        if bleach and k <= 2
            and hsh(math.floor(x / 3) + 3, math.floor(y / 4), seed + 2.0) < 0.55 then
          -- ⚠ 죽은 나무가 혼자 붉으면 밝기가 아니라 채도 문제다 — base를 더 내리지 말고 풍화 얼룩 비율을 올려 무채 면적을 늘린다.
          col = GREY_OF[n]
        end
        buf:set(x, y, col)
      end
    end
  end
end

----------------------------------------------------------------------
-- 접지 그림자 — 🔴 광원이 왼쪽 위니 그림자는 오른쪽 아래로 흐른다(대칭 파괴)
----------------------------------------------------------------------
local function ground_shadow(buf, cx, cy, rx, ry, seed)
  for y = math.floor(cy - ry) - 1, math.floor(cy + ry) + 1 do
    for x = math.floor(cx - rx) - 1, math.floor(cx + rx) + 1 do
      local nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
      local d = nx * nx + ny * ny
      local wob = 0.10 * math.sin(x * 0.41 + y * 0.9 + seed) + 0.06 * math.sin(x * 1.13 - seed)
      if d + wob <= 1.0 and buf:get(x, y) == nil then
        buf:set(x, y, (d + wob > 0.62) and C.g7 or C.g8)
      end
    end
  end
end

----------------------------------------------------------------------
-- 손으로 찍는 점들
----------------------------------------------------------------------
local function dots(buf, list, col, only_if)
  for _, p in ipairs(list) do
    local cur = buf:get(p[1], p[2])
    if cur ~= nil and (only_if == nil or only_if(cur)) then buf:set(p[1], p[2], col) end
  end
end

local function is_dark_leaf(c) return c == C.g6 or c == C.g7 or c == C.g8 end

-- 🔴 고립 조각 청소 (고립 1px 고대비 노이즈 금지) — 이웃 1개 이하는 지운다.
local function despeckle(buf)
  for _ = 1, 2 do
    local kill = {}
    for y = 0, buf.h - 1 do
      for x = 0, buf.w - 1 do
        if buf:get(x, y) ~= nil then
          local n = 0
          for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            if buf:get(x + d[1], y + d[2]) ~= nil then n = n + 1 end
          end
          if n <= 1 then kill[#kill + 1] = { x, y } end
        end
      end
    end
    if #kill == 0 then break end
    for _, p in ipairs(kill) do buf.p[p[2] * buf.w + p[1]] = nil end
  end
end

-- 🔴🔴 본체에서 **떨어져 나온 조각** 청소 (연결 성분이 min보다 작으면 지운다).
--   열 단위로 솎으면 이웃이 잘린 열이 통째로 고립돼 허공에 뜬 세로 막대가 남는다 — despeckle은 이걸 못 잡는다.
local function drop_small(buf, minsize)
  local seen = {}
  for y0 = 0, buf.h - 1 do
    for x0 = 0, buf.w - 1 do
      local i0 = y0 * buf.w + x0
      if buf.p[i0] ~= nil and not seen[i0] then
        local stack, comp = { { x0, y0 } }, {}
        seen[i0] = true
        while #stack > 0 do
          local p = table.remove(stack)
          comp[#comp + 1] = p
          for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nx, ny = p[1] + d[1], p[2] + d[2]
            if nx >= 0 and ny >= 0 and nx < buf.w and ny < buf.h then
              local i = ny * buf.w + nx
              if buf.p[i] ~= nil and not seen[i] then seen[i] = true; stack[#stack + 1] = { nx, ny } end
            end
          end
        end
        if #comp < minsize then
          for _, p in ipairs(comp) do buf.p[p[2] * buf.w + p[1]] = nil end
        end
      end
    end
  end
end

----------------------------------------------------------------------
-- ① tree_round — 활엽수. 넓고 뭉친 수관. 폭 ~117.
----------------------------------------------------------------------
local function tree_round()
  local W, H = 128, 128
  local buf = Buf.new(W, H)

  -- 밑동 (수관보다 먼저 = 수관이 위를 덮는다)
  local mask = {}
  -- ⚠ 128px 수관엔 밑동 반지름 18은 돼야 한다(15면 가늘어서 못 버틸 것처럼 보인다).
  limb(mask, W, H, { { 59, 122, 33 }, { 59, 113, 26 }, { 58, 103, 21 }, { 58, 91, 19 }, { 60, 79, 18 } })
  -- 뿌리 판 (왼쪽이 더 멀리·오른쪽은 짧고 굵게 — 대칭 파괴)
  limb(mask, W, H, { { 59, 118, 19 }, { 44, 121, 13 }, { 36, 122, 7 } })
  limb(mask, W, H, { { 59, 118, 18 }, { 73, 121, 12 }, { 79, 122, 8 } })
  -- 굵은 가지 둘 (수관 아래로 살짝 비어져 나온다)
  limb(mask, W, H, { { 58, 94, 13 }, { 44, 88, 8 }, { 34, 84, 5 } })
  limb(mask, W, H, { { 58, 96, 12 }, { 74, 92, 8 }, { 84, 89, 5 } })
  for y = 123, H - 1 do for x = 0, W - 1 do mask[y * W + x] = nil end end
  shade_mask(buf, mask, W, H, WOOD, 4.6, 5, 3.1)

  -- 수관 (손으로 적은 잎덩이 13개) — { cx, cy, rx, ry, base, himin, rim세기 }
  -- 🔴 himin·rim으로 하이라이트를 **왼쪽 위 덩이들에만** 몰아준다. 나머지는 g3 위로 못 간다.
  -- ⚠ 큰 덩이 하나를 중앙에 두면 그 테두리가 수관을 대각선으로 자르는 굵은 띠가 된다 — 둘로 쪼갠다.
  -- 🔴 덩이 중심이 일직선이면 각 덩이의 밝은 호가 이어붙어 수관을 가로지르는 사선 띠가 된다 — 지그재그로 흔들면 호가 끊긴다.
  local CL = {
    { 58,  23, 27, 21, 4.6, 2, 1.8 },
    { 32,  40, 23, 18, 4.2, 2, 2.0 },   -- 가장 밝은 덩이 (광원 쪽)
    { 86,  34, 24, 19, 5.3, 3, 1.2 },
    { 24,  62, 19, 16, 5.6, 3, 1.0 },
    { 99,  55, 19, 15, 6.1, 4, 0.6 },
    { 46,  53, 18, 15, 5.7, 3, 1.1 },   -- ↙ 왼쪽으로 당겨 (32,40)과 어긋나게
    { 77,  50, 17, 14, 6.0, 4, 0.8 },   -- ↗ 위로 올려 (86,34)-(81,78) 사선을 끊는다
    { 41,  76, 21, 14, 6.4, 4, 0.7 },
    { 81,  78, 22, 15, 6.8, 5, 0.4 },
    { 63,  71, 16, 13, 6.5, 4, 0.5 },
    { 60,  86, 17, 11, 7.0, 5, 0.4 },
    { 15,  46, 11, 10, 4.9, 3, 1.4 },
    { 110, 42, 10,  9, 5.7, 4, 0.6 },
    { 73,  10, 13, 10, 4.4, 2, 1.6 },
  }
  canopy(buf, CL, 1.7, {})

  -- 🔴 세계관: 「있어선 안 될 곳이 반짝인다」 — 발광이 아니라 **잎 사이에 고인 차가운 색조**.
  --   활엽수는 아주 조금만(손으로 찍은 세 자리). 그늘 픽셀에만 든다.
  dots(buf, { {52,66},{53,66},{51,67},{52,67},{53,67},{52,68},
              {88,58},{89,58},{88,59},{89,59},{90,59},{89,60},
              {36,86},{37,86},{36,87},{37,87},{38,87} }, C.c1, is_dark_leaf)
  dots(buf, { {52,67},{89,59} }, C.c2)

  outline(buf, function(b, x, y) return b:get(x, y) ~= nil end, C.g6, C.g8)
  -- ⚠ 그림자 중심이 밑동보다 너무 오른쪽이면 나무가 왼쪽으로 기운 듯 보인다.
  ground_shadow(buf, 66, 122, 41, 9, 0.7)
  return buf
end

----------------------------------------------------------------------
-- ② tree_pine — 침엽수. 좁고 층진 원뿔. 폭 ~76.
----------------------------------------------------------------------
local function tree_pine()
  local W, H = 128, 128
  local buf = Buf.new(W, H)

  local mask = {}
  limb(mask, W, H, { { 62, 122, 21 }, { 62, 114, 17 }, { 61, 104, 13 }, { 61, 92, 10 }, { 62, 70, 8 } })
  limb(mask, W, H, { { 62, 120, 13 }, { 52, 122, 8 } })
  limb(mask, W, H, { { 62, 120, 11 }, { 72, 122, 7 } })
  for y = 123, H - 1 do for x = 0, W - 1 do mask[y * W + x] = nil end end
  shade_mask(buf, mask, W, H, WOOD, 5.0, 4, 5.3)

  -- 🔴 침엽수의 몸은 아래로 처진 층(tier)이다 — 타원 잎덩이로는 매끈한 크리스마스 트리가 나와 활엽수와 실루엣이 안 갈린다.
  --   층마다 밑변이 톱니로 내려앉고, 그 그늘이 아래 층 위에 떨어져 가로 결이 생긴다. 그게 「침엽수」의 읽힘이다.
  --   { ytop, ybot, cx, 위폭, 아래폭, base, himin } — 손으로 적었다. cx가 60~63으로 흔들린다.
  -- ⚠ 층 위끝 간격이 균일하면 밑변 그늘이 균일한 가로 줄무늬가 된다 — 간격·두께를 흔들어라.
  local TIER = {
    { 79, 100, 61, 16, 38, 6.4, 6 },
    { 61,  88, 64, 12, 36, 6.0, 5 },
    { 48,  72, 59,  9, 31, 5.6, 5 },
    { 31,  57, 63,  6, 25, 5.2, 4 },
    { 17,  39, 60,  4, 18, 4.8, 4 },
    {  2,  23, 62,  2, 11, 4.6, 4 },
  }
  local COOL = { [5] = C.c1 }
  for _, T in ipairs(TIER) do
    local ytop, ybot, cx, hwt, hwb, base, himin = T[1], T[2], T[3], T[4], T[5], T[6], T[7]
    local span = ybot - ytop
    for x = math.floor(cx - hwb) - 6, math.ceil(cx + hwb) + 6 do
      local dxn = (x - cx) / hwb
      if math.abs(dxn) <= 1.02 then
        -- 이 x에서 층이 시작하는 행 (원뿔 옆선)
        local yt = ytop + math.floor(span * math.max(0.0, (math.abs(x - cx) - hwt) / (hwb - hwt)) ^ 1.25)
        -- 🔴 밑변 톱니 — 가지 끝일수록 길게 처진다.
        -- ⚠ x 한 칸마다 길이를 굴리면 밑변이 뭉개져 「흩어진 짧은 대시」가 된다 — 4~5px 구간마다 같은 길이를 줘야 톱니가 「가지 한 다발」로 읽힌다.
        local seg = math.floor((x - cx) / 4)
        local droop = 1 + math.floor(5.5 * math.abs(dxn) ^ 1.3
          + 4.0 * hsh(seg, ytop, 6.2) + 1.4 * hsh(math.floor((x - cx) / 9), ytop, 3.4))
        -- 🔴 층 옆선을 너덜하게 — **열을 지우지 않고 처짐 길이만 줄인다.**
        --   열을 통째로 솎으면 살아남은 열이 고립돼 허공에 뜬 막대가 된다.
        if math.abs(dxn) > 0.86 then
          droop = droop - math.floor(4.0 * hsh(math.floor(x / 3), ytop, 4.4))
        end
        local yb = ybot + droop
        for y = yt, yb do
          local vy = (y - ytop) / span
          -- ⚠ 가로 계수가 크면 오른쪽 절반(dxn>0)이 통째로 어두워져 층이 안 읽히고 덩어리로 뭉갠다.
          local t = (-dxn) * 0.62 + (1.0 - 2.0 * vy) * 0.5
          local v = base - t * 2.1   -- ⚠ 1.7이면 명암 폭이 좁아 청록 덩어리 하나로 보였다
          -- 🔴 층 밑변 3행이 **가장 어둡다** = 위 층이 아래 층에 드리우는 가로 결.
          if y > yb - 3 then v = v + 2.4 end
          if y < yt + 2 then v = v + 0.3 end
          -- 침엽 다발 — 세로로 짧은 결 (2px 폭 · 3px 높이)
          if hsh(math.floor(x / 2), math.floor(y / 3), 11.7) < 0.34 then v = v + 0.9
          elseif hsh(math.floor(x / 2) + 40, math.floor(y / 3), 11.7) < 0.22 then v = v - 0.7 end
          local n = clampi(math.floor(v + 0.5), himin, 8)
          buf:set(x, y, COOL[n] or LEAF[n])
        end
      end
    end
  end

  despeckle(buf)
  drop_small(buf, 24)

  -- 층 끝에 손으로 얹은 긴 침엽 몇 가닥 (좌우 개수가 다르다 — 대칭 파괴)
  -- ⚠ 손으로 적은 좌표가 본체에 안 붙으면 허공에 세로 막대가 뜬다 — 시작점 바로 위가 몸이어야만 그린다.
  for _, s in ipairs({ { 25, 100 }, { 33, 103 }, { 44, 104 }, { 78, 102 }, { 92, 98 },
                       { 28, 86 }, { 47, 89 }, { 88, 86 }, { 36, 71 }, { 82, 72 },
                       { 40, 56 }, { 79, 55 }, { 45, 39 }, { 74, 40 }, { 55, 23 } }) do
    local sy, tries = s[2], 0
    while tries < 6 and buf:get(s[1], sy - 1) == nil do sy = sy - 1; tries = tries + 1 end
    if buf:get(s[1], sy - 1) ~= nil then
      local len = 2 + math.floor(hsh(s[1], s[2], 9.4) * 4)
      local lean = (s[1] < 61) and -1 or 1
      for k = 0, len do
        local x = s[1] + math.floor(k * 0.4) * lean
        local y = sy + k
        if buf:get(x, y) == nil or is_dark_leaf(buf:get(x, y)) then
          buf:set(x, y, (k > len - 2) and C.g8 or C.g7)
        end
      end
    end
  end

  -- 고인 차가운 빛 — 침엽수는 활엽수보다 짙다. 층 밑변 그늘에만 든다(밝은 잎에 찍히면 얼룩이다).
  local function shaded(c) return is_dark_leaf(c) or c == C.c1 end
  dots(buf, { {49,68},{50,68},{48,69},{49,69},{50,69},{49,70},{50,70},
              {72,84},{73,84},{72,85},{73,85},{74,85},{73,86},
              {55,52},{56,52},{55,53},{56,53},
              {80,99},{81,99},{80,100},{81,100},{82,100} }, C.c1, shaded)
  dots(buf, { {49,69},{73,85},{81,100} }, C.c2, function(c) return c == C.c1 end)

  outline(buf, function(b, x, y) return b:get(x, y) ~= nil end, C.g6, C.g8)
  ground_shadow(buf, 69, 122, 30, 8, 2.2)
  return buf
end

----------------------------------------------------------------------
-- ③ tree_dead — 마른 나무. 잎 0. 벌어진 가지. 폭 ~92.
--    세계관: 「고인 빛이 빠져나간 자리」 → 청록 색조가 하나도 없고, 바랜 무채가 섞인다.
----------------------------------------------------------------------
local function tree_dead()
  local W, H = 128, 128
  local buf = Buf.new(W, H)
  local mask = {}

  -- 줄기 — 밑동 반지름 22. 30이면 「나무」가 아니라 굵은 통나무로 읽힌다.
  limb(mask, W, H, { { 60, 122, 22 }, { 60, 114, 19 }, { 59, 102, 15 }, { 58, 88, 12 },
                     { 57, 74, 10 }, { 58, 62, 8 }, { 59, 50, 6 } })
  limb(mask, W, H, { { 60, 120, 15 }, { 47, 122, 10 }, { 41, 123, 5 } })
  limb(mask, W, H, { { 60, 120, 13 }, { 72, 122, 9 }, { 79, 123, 5 } })

  -- 가지 사슬 (손으로 적었다) — 끝 반지름 1 = **1~2px로 뾰족하게 사그라진다**
  limb(mask, W, H, { { 57, 86, 10 }, { 46, 78, 7 }, { 36, 67, 5 }, { 28, 55, 4 }, { 23, 43, 3 }, { 19, 32, 2 }, { 17, 24, 1 } })
  limb(mask, W, H, { { 28, 55, 4 }, { 19, 51, 3 }, { 11, 45, 1 } })
  -- ⚠ 오른쪽 큰 가지가 왼쪽과 같은 각도·높이면 거울상이 된다 — 낮고 완만하게 · 짧게 끊어 「부러진 쪽」으로 만든다.
  limb(mask, W, H, { { 57, 76, 9 }, { 69, 72, 7 }, { 80, 64, 5 }, { 88, 55, 4 }, { 93, 47, 2 } })
  limb(mask, W, H, { { 80, 64, 5 }, { 91, 62, 3 }, { 99, 59, 1 } })
  limb(mask, W, H, { { 59, 100, 11 }, { 48, 93, 6 }, { 39, 85, 4 }, { 33, 78, 1 } })
  limb(mask, W, H, { { 60, 110, 13 }, { 73, 103, 7 }, { 83, 97, 4 }, { 89, 90, 1 } })
  limb(mask, W, H, { { 59, 50, 6 }, { 61, 39, 5 }, { 59, 28, 4 }, { 57, 17, 2 }, { 56, 7, 1 } })
  limb(mask, W, H, { { 59, 28, 4 }, { 69, 23, 3 }, { 78, 16, 1 } })
  limb(mask, W, H, { { 61, 39, 4 }, { 51, 32, 3 }, { 43, 24, 1 } })
  -- 부러진 그루터기 둘 (손으로 얹은 비대칭) — 「살아 있다가 부러졌다」가 읽힌다
  limb(mask, W, H, { { 58, 90, 7 }, { 68, 87, 4 }, { 73, 86, 3 } })
  limb(mask, W, H, { { 59, 64, 6 }, { 50, 61, 3 } })
  -- 🔴🔴 **123**이다 — 세 나무의 접지선(밑동 최하단 row 122)을 여기서 맞춘다. 하나만 어긋나면
  --   그 변형이 붙은 자리에서만 나무가 **공중에 뜨거나 땅에 박힌다**(랜덤 교체라 재현이 어렵다).
  for y = 123, H - 1 do for x = 0, W - 1 do mask[y * W + x] = nil end end

  -- bleach=true → 빛 받는 결에 바랜 무채가 든다 (세계관: 고인 빛이 **빠져나간** 자리)
  -- ⚠ base가 낮으면 밝은 갈색이 지배해 살아 있는 나무처럼 붉어진다.
  -- 사다리는 따뜻한 WOOD 그대로 · 무채는 풍화 얼룩(bleach=true)이 얹는다.
  shade_mask(buf, mask, W, H, WOOD, 5.8, 5, 8.6, true)

  -- 옹이 구멍 셋 (손으로 찍었다) — 시선이 가는 자리에 디테일을 몰아준다
  for _, k in ipairs({ { 55, 96, 3 }, { 63, 78, 2 }, { 57, 108, 4 } }) do
    for dy = -k[3], k[3] do
      for dx = -k[3], k[3] do
        if dx * dx + dy * dy * 1.6 <= k[3] * k[3] and buf:get(k[1] + dx, k[2] + dy) ~= nil then
          buf:set(k[1] + dx, k[2] + dy, (dy < 0 and dx < 0) and C.b7 or C.b8)
        end
      end
    end
  end

  -- 🔴 밑동 세로 균열 — 손질로 찍은 좌표를 이 표로 옮겨 적었다(안 옮기면 다시 생성할 때 손질이 그대로 날아간다).
  --   x가 몇 행마다 한 칸씩 어긋난다 = 갈라진 틈은 곧게 안 간다.
  local CRACK_MAIN = {
    { 56, 90 }, { 56, 91 }, { 57, 92 }, { 57, 93 }, { 57, 94 }, { 56, 95 }, { 56, 96 }, { 56, 97 },
    { 57, 98 }, { 57, 99 }, { 57, 100 }, { 57, 101 }, { 56, 102 }, { 56, 103 }, { 56, 104 },
    { 56, 105 }, { 57, 106 }, { 57, 107 }, { 57, 108 }, { 56, 109 }, { 56, 110 }, { 56, 111 },
    { 57, 112 }, { 57, 113 }, { 57, 114 }, { 57, 115 }, { 57, 116 }, { 56, 117 },
  }
  local CRACK_SUB = {
    { 52, 105 }, { 52, 106 }, { 52, 107 }, { 53, 108 }, { 53, 109 }, { 53, 110 },
    { 52, 111 }, { 52, 112 }, { 52, 113 }, { 53, 114 }, { 53, 115 },
  }
  dots(buf, CRACK_MAIN, C.b8)
  dots(buf, CRACK_SUB, C.b7)
  -- 갈라진 틈의 **왼쪽 입술만** 빛을 받는다 (광원 왼쪽 위) — 띄엄띄엄 얹어 균일한 선이 안 되게.
  -- ⚠ 입술을 주황 갈색(884B2B)으로 찍으면 어두운 밑동에 붉은 반점이 튄다 — 무채로, 개수는 적게.
  dots(buf, { { 55, 91 }, { 55, 96 }, { 56, 103 }, { 55, 110 }, { 56, 116 } }, C.s4)

  outline(buf, function(b, x, y) return b:get(x, y) ~= nil end, C.b4, C.b8)
  ground_shadow(buf, 67, 122, 33, 7, 4.5)
  return buf
end

----------------------------------------------------------------------
-- ④ bush — 관목. 나무가 커진 만큼 같이 올린다. 실루엣 ~44 x 32.
----------------------------------------------------------------------
-- 🔴 몸 ~35px(프레임 56x48) · 접지선 row 40 — 30px은 128px 나무 옆에서 「덤불」이 아니라 「이끼 덩어리」로 읽힌다.
local function bush()
  local W, H = 56, 48
  local buf = Buf.new(W, H)

  -- 🔴 관목은 「작은 나무」가 아니다 — 잔가지가 잎 사이로 **보여야** 관목으로 읽힌다.
  local mask = {}
  limb(mask, W, H, { { 26, 40, 6 }, { 25, 33, 4 }, { 23, 26, 2 } })
  limb(mask, W, H, { { 26, 38, 4 }, { 35, 33, 3 }, { 41, 28, 2 } })
  limb(mask, W, H, { { 26, 36, 3 }, { 19, 31, 2 }, { 15, 27, 1 } })
  -- ⚠ base가 낮으면 잔가지가 밝은 갈색이라 잎 사이에서 붉은 점(꽃? 상처?)으로 튄다.
  shade_mask(buf, mask, W, H, WOOD, 6.8, 3, 6.6)

  -- ⚠ 덩이가 크고 밝으면 바닥보다 밝은 빵 덩어리가 된다 — 잘게 쪼개 rim이 먹게 하고 전체를 한 단 내린다.
  local CL = {
    { 16, 21, 11, 10, 5.7, 4, 1.8 },
    { 31, 15, 12, 11, 5.3, 3, 2.0 },
    { 43, 23, 10,  8, 6.6, 5, 0.8 },
    { 23, 30, 11,  8, 7.0, 6, 0.6 },
    { 37, 31, 11,  7, 7.2, 6, 0.5 },
    { 10, 28,  7,  7, 6.3, 5, 1.0 },
    { 47, 31,  6,  5, 7.0, 6, 0.6 },
  }   -- ⚠ 8회차: 프레임 양 끝에 딱 붙어 여유가 0이었다 → 좌우로 2~3px 남긴다.
  canopy(buf, CL, 2.6, { tuft_spacing = 3 })
  drop_small(buf, 12)
  dots(buf, { { 28, 26 }, { 29, 26 }, { 28, 27 } }, C.c1, is_dark_leaf)
  outline(buf, function(b, x, y) return b:get(x, y) ~= nil end, C.g6, C.g8)
  ground_shadow(buf, 30, 41, 19, 5, 1.3)
  return buf
end

----------------------------------------------------------------------
-- 🔴 `TAKBON_ONLY`를 미리 설정하면 그 하나만 다시 만든다.
--   이미 얹은 손질을 날리지 않기 위한 안전장치다 — 전량 재생성은 손질 루프를 통째로 되감는다.
local only = TAKBON_ONLY
local function want(n) return only == nil or only == n end
if want("tree_round") then save(tree_round(), "tree_round") end
if want("tree_pine") then save(tree_pine(), "tree_pine") end
if want("tree_dead") then save(tree_dead(), "tree_dead") end
if want("bush") then save(bush(), "bush") end
print("done")
