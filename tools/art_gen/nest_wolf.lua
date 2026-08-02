-- 늑대 둥지 (NEST) 랜드마크
-- 🔴 밑그림 생성기다 — 능선/굴 입구/가지/뼈는 전부 손으로 적은 좌표표다(수식으로 만든 곡선이 아니다).
-- 팔레트: TAKBON 60 (assets/aseprite/takbon.gpl) 밖의 색을 쓰지 않는다.
-- 광원: 왼쪽 위 고정.
-- 프레임 192x152 · 2컷 (1=온전함 / 2=비워짐).
-- 🔴 좌표표는 원본 캔버스(160x128)에서 손으로 그린 것을 그대로 두고 mx/my에서 한 번만 1.2배 확대한다 — 표를 다시 적으면 손맛이 리셋된다.
--   확대가 만든 매끈한 계단은 jag로 손본다.

local W, H = 192, 152

-- 좌표 확대: 원본 캔버스(160x128) → 이 캔버스
local function mx(x) return math.floor((x - 8) * 1.2 + 0.5) + 10 end
local function my(y) return math.floor((y - 42) * 1.2 + 0.5) + 50 end
local function mnodes(t)
  local o = {}
  for i, n in ipairs(t) do o[i] = { mx(n[1]), my(n[2]), n[3] } end
  return o
end

----------------------------------------------------------------------
-- 색 (전부 TAKBON 60)
----------------------------------------------------------------------
local C = {
  d0 = "2E1F18", d1 = "4D2B32", d2 = "7A4841", d3 = "884B2B",
  d4 = "AD7757", d5 = "C09473", d6 = "D7B594", d7 = "E7D5B3",
  -- ⚠ 어둠도 따뜻해야 흙으로 읽힌다 — 푸른 무채(151D28/202E37) 대신 k4(241527)를 쓴다.
  k0 = "090A14", k4 = "241527", k3 = "341C27",
  g0 = "16281C", g1 = "25562E", g2 = "468232", g3 = "75A743",
  g4 = "7A8C2E", g5 = "A8CA58",
  s0 = "2A2C32", s1 = "4E5259", s2 = "577277", s3 = "819796",
  s4 = "A8B5B2", s5 = "C7CFCC", s6 = "EBEDE9",
  w1 = "602C2C",
  y0 = "C9962E", y1 = "DE9E41", y2 = "E8C170",
}

-- 흙 명암 사다리 (밝음 → 어두움). tone 인덱스 0..6
local TONE = { C.d6, C.d5, C.d4, C.d3, C.d2, C.d1, C.d0 }

----------------------------------------------------------------------
-- 손으로 적은 능선 (마운드 윗변) — x = 12..151
--   왼쪽 낮은 봉우리 / 안부(saddle) / 오른쪽 큰 봉우리(굴 지붕).
--   ⚠ 일부러 계단을 불규칙하게 뒀다.
----------------------------------------------------------------------
-- ⚠ 짐승이 판 굴은 세로로 서지 않는다 — 봉우리가 뾰족하면 「바위산」으로 읽힌다. 주봉 하나 + 왼쪽은 어깨(shoulder).
local SRC_X0 = 8
local TOP_SRC = {
  105,104,102,101,100, 98, 97, 96, 94, 93, -- 8..17
   92, 91, 90, 90, 89, 88, 86, 84, 84, 83, -- 18..27  (혹 = 84,84 평평)
   81, 80, 80, 79, 78, 77, 76, 75, 74, 73, -- 28..37
   72, 72, 71, 71, 71, 71, 72, 72, 72, 72, -- 38..47  (왼 어깨 — 3회차에 「봉우리」를 「부풀음」으로 낮췄다)
   72, 72, 72, 72, 72, 72, 72, 73, 73, 73, -- 48..57
   73, 72, 72, 72, 71, 71, 70, 69, 69, 68, -- 58..67  (안부 — V자를 메웠다)
   67, 66, 63, 61, 59, 58, 58, 56, 54, 53, -- 68..77  (턱 72..74)
   51, 50, 50, 49, 48, 47, 47, 46, 46, 45, -- 78..87
   45, 44, 43, 43, 42, 42, 42, 42, 43, 44, -- 88..97  (주봉 마루 — 7회차에 6px 올렸다)
   45, 46, 47, 49, 50, 52, 53, 54, 55, 57, -- 98..107
   60, 62, 63, 63, 63, 64, 66, 68, 69, 71, -- 108..117 (선반 110..113)
   72, 74, 75, 77, 78, 80, 81, 82, 84, 84, -- 118..127
   84, 85, 87, 89, 90, 92, 93, 95, 96, 98, -- 128..137 (선반 126..128)
   99,100,101,102,103,103,104,104,105,105, -- 138..147
  106,106,107,107,108,                     -- 148..152
}

-- 밑변 — 일부러 ±1 들쭉날쭉하게 적었다 (매끈한 타원 = 「계산된 것」).
local BOT_SRC = {
  107,108,109,109,110,110,111,111,112,112, -- 8..17
  112,113,113,114,113,114,114,115,114,115, -- 18..27
  115,116,115,116,116,116,117,116,117,117, -- 28..37
  116,117,117,117,116,117,117,117,117,116, -- 38..47
  117,117,117,117,116,117,117,117,117,117, -- 48..57
  117,117,116,117,117,117,117,117,116,117, -- 58..67
  117,117,117,117,116,117,117,117,117,117, -- 68..77
  117,117,117,116,117,117,117,117,117,116, -- 78..87
  117,117,117,117,117,117,116,117,117,117, -- 88..97
  117,117,116,117,117,116,117,117,116,116, -- 98..107
  117,116,116,117,116,116,115,116,116,115, -- 108..117
  116,115,115,116,115,114,115,114,114,115, -- 118..127
  114,113,114,113,113,112,113,112,112,111, -- 128..137
  112,111,110,111,110,109,110,109,108,107, -- 138..147
  107,106,105,104,103,                     -- 148..152
}

----------------------------------------------------------------------
-- 굴 입구 (den mouth) — x = 64..100. 왼쪽 림이 가파르고 오른쪽이 완만 = 비대칭.
----------------------------------------------------------------------
-- ⚠ 입구는 낮고 넓게(47x38) — 세로로 길면 「동굴」이 되고, 좁으면 사냥개(32px)에 빠듯하다.
local SRC_MX0 = 58
local MTOP_SRC = {
  113,110,106,102, 99, 96, 93, 91, 89, 87, -- 58..67
   85, 84, 82, 81, 80, 78, 77, 76, 76, 75, -- 68..77
   75, 74, 74, 74, 74, 74, 75, 75, 76, 77, -- 78..87
   78, 80, 82, 84, 87, 90, 93, 97,100,104, -- 88..97
  107,110,112,113,113,114,114,             -- 98..104
}
local MBOT_SRC = {
  113,113,112,112,111,111,110,110,110,109, -- 58..67
  109,109,109,110,110,110,111,111,111,111, -- 68..77
  112,112,112,112,112,112,111,111,111,110, -- 78..87
  110,110,110,111,111,111,112,112,112,113, -- 88..97
  113,113,113,114,114,114,114,             -- 98..104
}

-- 무너짐(2컷)용 — 능선 침하량과 반쯤 메워진 입구.
local SRC_SLX0 = 50
local SLUMP_SRC = {
-- ⚠ 침하의 봉우리는 굴 위(x≈88)에 와야 지붕이 꺼진다.
   0,  0,  1,  1,  2,  2,  3,  4,  5,  6, -- 50..59
   7,  8,  9, 10, 12, 13, 14, 16, 17, 18, -- 60..69
  19, 20, 21, 22, 22, 23, 23, 24, 24, 25, -- 70..79
  24, 25, 26, 27, 28, 28, 28, 29, 29, 29, -- 80..89  (지붕이 가장 깊이 꺼진 자리)
  29, 29, 28, 28, 27, 26, 26, 25, 25, 24, -- 90..99
  23, 22, 21, 20, 19, 17, 16, 15, 14, 13, -- 100..109  (11회차: 여기가 안 꺼져 새 봉우리가 났다)
  12, 10,  9,  8,  6,  5,  4,  3,  2,  1, -- 110..119
}
-- 🔴 반쯤 열린 입구는 「막혔다」로만 읽힌다 — 흙이 흘러내려 얕은 함몰만 남긴다.
local MTOP2_SRC = {
  113,113,112,112,111,111,110,110,110,109, -- 58..67
  109,109,109,110,109,107,105,104,104,104, -- 68..77
  104,104,104,104,104,104,103,103,103,102, -- 78..87
  102,102,103,104,106,108,110,111,112,112, -- 88..97
  113,113,113,114,114,114,114,             -- 98..104
}

----------------------------------------------------------------------
-- 버퍼
----------------------------------------------------------------------
local B = {}
local function clear()
  B = {}
  for y = 0, H - 1 do B[y] = {} end
end
local function set(x, y, c)
  if x < 0 or y < 0 or x >= W or y >= H then return end
  B[y][x] = c
end
local function get(x, y)
  if x < 0 or y < 0 or x >= W or y >= H then return nil end
  return B[y][x]
end

----------------------------------------------------------------------
-- 확대 — 손 표를 1.2배로 다시 뽑고, 매끈해진 계단을 손으로 흔든다
----------------------------------------------------------------------
local X0,  X1  = mx(8),  mx(152)
local MX0, MX1 = mx(58), mx(104)
local APX0     = mx(40)
local SLX0     = mx(50)

local function unmx(nx) return (nx - 10) / 1.2 + 8 end

local function resample(src, srcx0, nx0, nx1, mapy)
  local out = {}
  for nx = nx0, nx1 do
    local ox = unmx(nx)
    local i = math.floor(ox) - srcx0 + 1
    local f = ox - math.floor(ox)
    local a, b = src[i], src[i + 1]
    local v = nil
    if a and b then v = a + (b - a) * f elseif a then v = a end
    if v then out[nx - nx0 + 1] = mapy and my(v) or math.floor(v * 1.2 + 0.5) end
  end
  return out
end

-- 🔴 확대는 곡선을 매끈하게 만든다 — 손으로 고른 구간에 혹·패임을 다시 넣는다(값·자리를 눈으로 보고 골랐다).
--    → 손으로 고른 구간에 혹·패임을 다시 넣는다. 값·자리를 눈으로 보고 골랐다.
local function jag(tb, x0, list)
  for _, j in ipairs(list) do
    for x = j[1], j[2] do
      local i = x - x0 + 1
      if tb[i] then tb[i] = tb[i] + j[3] end
    end
  end
end

local TOP  = resample(TOP_SRC,  SRC_X0, X0, X1, true)
local BOT  = resample(BOT_SRC,  SRC_X0, X0, X1, true)
local MTOP = resample(MTOP_SRC, SRC_MX0, MX0, MX1, true)
local MBOT = resample(MBOT_SRC, SRC_MX0, MX0, MX1, true)
local MTOP2 = resample(MTOP2_SRC, SRC_MX0, MX0, MX1, true)
local SLUMP = resample(SLUMP_SRC, SRC_SLX0, SLX0, mx(119), false)

jag(TOP, X0, {
  { 22, 27, 2 }, { 34, 39, -1 }, { 44, 49, 2 }, { 56, 61, -1 }, { 64, 69, 2 },
  { 77, 81, -1 }, { 87, 91, 1 }, { 98, 103, -1 }, { 109, 114, 2 }, { 120, 125, -1 },
  { 131, 137, 2 }, { 145, 150, -1 }, { 157, 162, 2 }, { 169, 174, -1 },
})
jag(BOT, X0, {
  { 20, 24, 1 }, { 31, 34, -1 }, { 42, 45, 1 }, { 53, 56, -1 }, { 65, 68, 1 },
  { 79, 82, -1 }, { 93, 96, 1 }, { 105, 109, -1 }, { 117, 120, 1 },
  { 129, 133, -1 }, { 141, 145, 1 }, { 153, 157, -1 }, { 165, 169, 1 },
})
jag(MTOP, MX0, { { 75, 79, 2 }, { 88, 92, -1 }, { 103, 107, 1 }, { 115, 119, -1 } })

local function topAt(x)  local i = x - X0 + 1;  return TOP[i]  end
local function botAt(x)  local i = x - X0 + 1;  return BOT[i]  end
local function mtopAt(x, t) local i = x - MX0 + 1; return (t or MTOP)[i] end
local function mbotAt(x) local i = x - MX0 + 1; return MBOT[i] end
local function slumpAt(x)
  local i = x - SLX0 + 1
  return SLUMP[i] or 0
end

----------------------------------------------------------------------
-- 흙 몸통
----------------------------------------------------------------------
-- 🔴 계단식 bias는 세로 줄무늬 경계를 만든다 — 8px 간격 손 표를 선형보간한다(값은 로브를 보고 적었다).
local BIAS_STEP = 8
-- ⚠ 오른쪽 꼬리를 높이면 사면이 통째로 어두운 덩어리가 돼 형태가 죽는다.
-- 🔴 지배 톤이 흙길 타일(AD7757)과 같으면 배경에 녹는다 = 랜드마크 계약 파기.
--   884B2B luma 90 vs 흙길 132 vs 잔디 468232 103 — 둘 다에 대해 선다.
local BIAS = { -- x = 8, 16, 24, ... 152
  2.0, 1.5, 1.0, 0.3, -0.2, 0.1, 0.7, 1.2, 0.8, 0.0, -0.4, -0.1, 0.7, 1.0, 1.2, 1.3, 1.4, 1.5, 1.5,
}
local function bias(x)
  local f = (unmx(x) - 8) / BIAS_STEP
  local i = math.floor(f)
  if i < 0 then i = 0 end
  if i > #BIAS - 2 then i = #BIAS - 2 end
  local a, b = BIAS[i + 1], BIAS[i + 2]
  return a + (b - a) * (f - i)
end

-- 앞자락(파낸 흙이 앞으로 밀려난 자리) — 굴 앞에만 손으로 얹었다.
-- ⚠ 실루엣을 오프셋 복사(y >= by-9)하면 바닥을 빙 두른다.
local SRC_APX0 = 40
local APRON_SRC = { -- x = 40..126, 이 y보다 아래가 느슨한 흙
  116,115,114,114,113,112,112,111,110,110, -- 40..49
  109,108,108,107,107,106,106,105,105,104, -- 50..59
  104,104,103,103,103,104,104,105,105,106, -- 60..69
  107,107,108,108,108,107,107,106,106,105, -- 70..79
  105,104,104,104,105,105,106,106,107,107, -- 80..89
  108,108,107,107,106,106,105,105,106,106, -- 90..99
  107,108,108,109,110,110,111,112,112,113, -- 100..109
  113,114,114,115,115,116,116,117,117,118, -- 110..119
  118,118,119,119,120,120,121,             -- 120..126
}
local APRON = resample(APRON_SRC, SRC_APX0, APX0, mx(126), true)
local function apronAt(x)
  local i = x - APX0 + 1
  return APRON[i]
end

local function toneAt(x, d, slope)
  local t
  if d <= 2 then t = 0
  elseif d <= 6 then t = 1
  elseif d <= 13 then t = 2
  elseif d <= 24 then t = 3
  elseif d <= 40 then t = 4
  else t = 5 end
  if slope < -1 then t = t - 1
  elseif slope > 1 then t = t + 1 end
  return t + bias(x)
end

local function build_mound(broken)
  math.randomseed(9901)
  for x = X0, X1 do
    local ty = topAt(x)
    local by = botAt(x)
    if ty and by then
      if broken then ty = ty + slumpAt(x) end
      local tyl = topAt(x - 1) or ty
      local tyr = topAt(x + 1) or ty
      if broken then
        tyl = tyl + slumpAt(x - 1)
        tyr = tyr + slumpAt(x + 1)
      end
      local slope = tyr - tyl
      local ap = apronAt(x)
      if ty <= by then
        for y = ty, by do
          local d = y - ty
          local t = toneAt(x, d, slope)
          if ap and y >= ap then t = t - 0.8 end
          -- 접지: 광원 반대(오른아래)만 진하게 · 왼쪽은 흙길 색으로 풀어 준다
          if y >= by then t = (x > mx(84)) and 5.5 or 2.0 end
          t = math.floor(t + 0.5)
          if t < 0 then t = 0 end
          if t > 6 then t = 6 end
          set(x, y, TONE[t + 1])
        end
      end
    end
  end
end

-- 굴 파내기 + 안쪽 어둠
-- 🔴 그냥 검은 구멍은 밋밋하다 — 빛이 닿는 안쪽 벽·바닥의 흙·가장자리 결로 「깊이」를 만든다.
local function carve_mouth(broken)
  local mt = broken and MTOP2 or MTOP
  for x = MX0, MX1 do
    local a = mtopAt(x, mt)
    local b = mbotAt(x)
    if a and b and a <= b then
      local depth = b - a
      for y = a, b do
        local dy = y - a
        local c
        if dy <= 0 then c = C.d1
        elseif dy <= 2 then c = C.k3
        elseif dy <= 5 then c = C.k4
        else c = C.k0 end
        -- 🔴 통짜 검정은 「구멍」이지 「깊이」가 아니다 — 바닥의 흙을 4단으로 깐다
        if y == b then c = C.d1
        elseif y == b - 1 then c = C.d0
        elseif y >= b - 3 then c = C.k3 end
        if depth <= 3 then c = C.k3 end
        set(x, y, c)
      end
      -- 왼쪽 안쪽 벽 — 광원이 닿는 만큼만 (오른쪽 벽은 안 밝힌다 = 비대칭)
      if x >= MX0 + 4 and x <= MX0 + 26 and depth > 10 then
        local lit = math.floor((MX0 + 27 - x) / 2)
        for k = 0, lit do
          local y = a + 2 + k
          if y <= b - 4 then set(x, y, (k <= 1) and C.d2 or ((k <= 3) and C.d1 or C.k3)) end
        end
      end
    end
  end
  -- ⚠ 입구 아래 앞자락이 밝으면 「입술」처럼 보인다 — 드나드는 자리는 흙이 다져져 어두우니 문턱을 눌러 준다.
  for x = MX0 + 1, MX1 - 1 do
    local b = mbotAt(x)
    if b then
      for k = 1, 5 do
        local y = b + k
        local cur = get(x, y)
        if cur == C.d6 then set(x, y, C.d4)
        elseif cur == C.d5 then set(x, y, C.d3)
        elseif cur == C.d4 then set(x, y, C.d3)
        elseif cur == C.d3 and k <= 2 then set(x, y, C.d2) end
      end
    end
  end
  -- 입구 위 처마(overhang) 그늘 — 두께가 자리마다 다르다(마루 아래가 가장 두껍다)
  for x = MX0 + 1, MX1 - 1 do
    local a = mtopAt(x, mt)
    if a then
      local n = 2
      if x > mx(68) and x < mx(92) then n = 5 end
      if x > mx(74) and x < mx(86) then n = 6 end
      for k = 1, n do
        local y = a - k
        if get(x, y) then
          set(x, y, (k <= 2) and C.d1 or C.d2)
        end
      end
    end
  end
end

-- 🔴 외곽선이 없으면 밝은 풀밭 위에서 가장자리가 사라진다.
--    광원 반대(오른쪽·아래)만 두껍게, 왼쪽 위는 거의 안 붙인다.
local function outline()
  local add = {}
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      if get(x, y) then
        local right = not get(x + 1, y)
        local down  = not get(x, y + 1)
        local left  = not get(x - 1, y)
        local up    = not get(x, y - 1)
        if right or down then
          local strong = (right and down) or (x > mx(90) and down) or (x > mx(110) and right)
          add[#add + 1] = { x, y, strong and C.d0 or C.d1 }
        elseif (left or up) and x > mx(96) then
          add[#add + 1] = { x, y, C.d2 }
        end
      end
    end
  end
  for _, p in ipairs(add) do
    local cur = get(p[1], p[2])
    -- 굴 안쪽 어둠·뼈·풀에는 덧칠하지 않는다
    if cur ~= C.k0 and cur ~= C.k4 and cur ~= C.k3
       and cur ~= C.s5 and cur ~= C.s4 and cur ~= C.g2 and cur ~= C.g3 and cur ~= C.g1 then
      set(p[1], p[2], p[3])
    end
  end
end

----------------------------------------------------------------------
-- 선/획 도구
----------------------------------------------------------------------
local function stamp(x, y, t, c, onlyOver)
  local function p(px, py)
    if onlyOver and not get(px, py) then return end
    set(px, py, c)
  end
  if t <= 1 then p(x, y)
  elseif t == 2 then p(x, y); p(x + 1, y); p(x, y + 1); p(x + 1, y + 1)
  elseif t == 3 then p(x, y); p(x - 1, y); p(x + 1, y); p(x, y - 1); p(x, y + 1)
  else
    for dy = -1, 1 do for dx = -1, 1 do p(x + dx, y + dy) end end
  end
end

local function seg(x0, y0, x1, y1, t0, t1, c, onlyOver)
  local dx, dy = x1 - x0, y1 - y0
  local n = math.max(math.abs(dx), math.abs(dy))
  if n == 0 then stamp(x0, y0, t0, c, onlyOver); return end
  for i = 0, n do
    local f = i / n
    local x = math.floor(x0 + dx * f + 0.5)
    local y = math.floor(y0 + dy * f + 0.5)
    local t = math.floor(t0 + (t1 - t0) * f + 0.5)
    stamp(x, y, t, c, onlyOver)
  end
end

-- 원본(160x128) 좌표로 부르는 선 도구 — 특징물 좌표는 전부 이걸 지난다
local function segO(x0, y0, x1, y1, t0, t1, c, onlyOver)
  seg(mx(x0), my(y0), mx(x1), my(y1), t0, t1, c, onlyOver)
end

-- 가지: 아래 그늘 → 몸통 → 위 하이라이트 (3단)
-- ⚠ socket으로 밑동을 흙에 박지 않으면 흙 위에 얹힌 막대로 보인다.
local function branch(nodes, socket)
  for i = 1, #nodes - 1 do
    local a, b = nodes[i], nodes[i + 1]
    seg(a[1], a[2] + 1, b[1], b[2] + 1, a[3], b[3], C.k3)
  end
  for i = 1, #nodes - 1 do
    local a, b = nodes[i], nodes[i + 1]
    seg(a[1], a[2], b[1], b[2], a[3], b[3], C.w1)
  end
  for i = 1, #nodes - 1 do
    local a, b = nodes[i], nodes[i + 1]
    if a[3] >= 3 then
      -- 하이라이트는 밑동 쪽에만 — 끝까지 끌면 굵기가 어디나 같아 보인다
      local hx = math.floor((a[1] + b[1]) / 2)
      local hy = math.floor((a[2] + b[2]) / 2)
      seg(a[1], a[2] - 1, hx, hy - 1, 1, 1, C.d3)
    end
  end
  if socket then
    -- 밑동이 흙을 파고든 자리: 어두운 구멍 + 밀려 올라온 흙
    local sx, sy = nodes[1][1], nodes[1][2]
    for dy = 0, 3 do
      for dx = -2, 2 do
        if get(sx + dx, sy + dy) and math.abs(dx) + dy <= 4 then
          set(sx + dx, sy + dy, (dy == 0) and C.d2 or C.d1)
        end
      end
    end
    for dx = -3, 3 do
      if get(sx + dx, sy + 4) then set(sx + dx, sy + 4, C.d5) end
    end
  end
end

----------------------------------------------------------------------
-- 결·질감
----------------------------------------------------------------------
-- 🔴 고랑+뿌리가 겹치면 표면이 온통 세로 빗금(「긁힌 벽」)이 된다 — 획을 걷고 부피는 넓은 면 음영으로 준다(경계는 손 8px 표를 보간).
local function patch(sx0, sstep, stops, sbots, delta)
  local x0, step = mx(sx0), sstep * 1.2
  local tops, bots = {}, {}
  for i, v in ipairs(stops) do tops[i] = my(v) end
  for i, v in ipairs(sbots) do bots[i] = my(v) end
  local function lerp(tb, x)
    local f = (x - x0) / step
    local i = math.floor(f)
    if i < 0 or i > #tb - 2 then return nil end
    local a, b = tb[i + 1], tb[i + 2]
    return a + (b - a) * (f - i)
  end
  local idx = {}
  for i, c in ipairs(TONE) do idx[c] = i - 1 end
  for x = x0, x0 + step * (#tops - 1) do
    local ty, by = lerp(tops, x), lerp(bots, x)
    if ty and by then
      -- ⚠ 경계를 ±1 흔들면 1px 세로 톱니가 난다 — 손 표의 곡선이 이미 불규칙하니 지터는 뺀다.
      for y = math.floor(ty), math.floor(by) do
        local cur = get(x, y)
        local i = cur and idx[cur]
        if i then
          local n = i + delta
          if n < 0 then n = 0 end
          if n > 6 then n = 6 end
          set(x, y, TONE[n + 1])
        end
      end
    end
  end
end

local function form_lobes()
  -- 오른쪽 사면의 큰 그늘 — 아래로 열려 있어 경계가 하나뿐이다
  patch(106, 8, { 84, 82, 86, 94, 102 }, { 118, 118, 118, 118, 116 }, 1)
  -- 왼 어깨의 밝은 면 (좁게 — 넓으면 통째로 밝아 평평해진다)
  patch(22, 8, { 92, 84, 78, 76, 78 }, { 102, 96, 90, 88, 88 }, -1)
  -- 주봉 왼쪽 밝은 면
  patch(68, 8, { 70, 62, 56, 54 }, { 82, 74, 68, 66 }, -1)
  -- ⚠ 오른쪽 사면이 통짜 어둠이면 형태가 없다 → 능선에서 내려오는 스퍼 하나.
  patch(110, 8, { 64, 76, 90 }, { 82, 94, 108 }, -1)
  -- ⚠ 왼 어깨가 밝은 삼각형 하나면 밋밋하다 → 흙이 접힌 자리를 하나 넣는다.
  local fold = { { 27, 85 }, { 34, 91 }, { 41, 97 }, { 47, 104 } }
  for i = 1, #fold - 1 do
    local a, b = fold[i], fold[i + 1]
    segO(a[1], a[2] - 1, b[1], b[2] - 1, 1, 1, C.d6, true)
    segO(a[1], a[2], b[1], b[2], 2, 2, C.d4, true)
    segO(a[1], a[2] + 2, b[1], b[2] + 2, 1, 1, C.d3, true)
  end
end

local function roots(broken)
  -- 파낸 흙에 드러난 뿌리 — 굴 입구 주변에만 남겼다 (디테일은 시선 가는 곳에)
  local sets = {
    { {54, 84, 2}, {57, 92, 2}, {54, 101, 1} },
    { {106, 86, 2}, {112, 94, 2}, {110, 103, 1} },
    { {74, 70, 1}, {84, 66, 2}, {94, 68, 1} },
  }
  for _, nd in ipairs(sets) do
    for i = 1, #nd - 1 do
      local a, b = nd[i], nd[i + 1]
      segO(a[1], a[2], b[1], b[2], a[3], b[3], C.d1, true)
      segO(a[1] - 1, a[2], b[1] - 1, b[2], 1, 1, C.d3, true)
    end
  end
  if broken then
    -- 갈라진 틈
    for _, ck in ipairs({
      { 44, 92, 56, 104 }, { 56, 104, 51, 113 },
      { 106, 84, 118, 98 }, { 118, 98, 126, 108 },
      { 86, 76, 94, 86 }, { 70, 82, 62, 94 },
    }) do
      segO(ck[1] - 1, ck[2] - 1, ck[3] - 1, ck[4] - 1, 1, 1, C.d6, true)
      segO(ck[1], ck[2], ck[3], ck[4], 2, 2, C.d0, true)
    end
  end
end

local function stones()
  -- 🔴 무채 회색 돌은 따뜻한 흙 위에서 스티커처럼 뜬다 — 작게, 밝은 회색은 빼고, 아랫단은 흙 어둠으로 박는다.
  -- ⚠ 왼쪽 돌을 두개골 바로 위에 두면 둘이 한 덩어리 얼룩으로 읽힌다.
  local st = { { 51, 98, 4, 2 }, { 128, 95, 4, 2 } }
  for _, s in ipairs(st) do
    local x, y, w, h = mx(s[1]), my(s[2]), s[3] + 1, s[4] + 1
    for dy = 0, h - 1 do
      for dx = 0, w - 1 do
        if get(x + dx, y + dy) then
          local c = (dy == 0) and C.s1 or C.d0
          set(x + dx, y + dy, c)
        end
      end
    end
    for dx = -1, w do
      if get(x + dx, y + h) then set(x + dx, y + h, C.d1) end
    end
  end
end

local function grain()
  -- 흙 알갱이 — 바닥 타일(tileset_ground)과 같은 결을 낸다. 2~3px 덩어리만.
  -- ⚠ 밝은 알갱이가 표면에 흩어지면 「곰팡이」처럼 보인다 — 수를 줄이고 대비를 낮춘다.
  for i = 1, 140 do
    local x = math.random(X0, X1)
    local ty, by = topAt(x), botAt(x)
    if ty and by and (ty + 2) <= (by - 1) then
      local y = math.random(ty + 2, by - 1)
      -- 🔴 바탕 톤을 읽어 바로 이웃한 한 단으로만 얼룩을 낸다 — 명도차가 벌어지면 「곰팡이」가 된다.
      local idx = {}
      for k, cc in ipairs(TONE) do idx[cc] = k - 1 end
      local base = get(x, y)
      local bi = base and idx[base]
      if bi then
        local n = bi + ((math.random() < 0.45) and -1 or 1)
        if n < 0 then n = 1 end
        if n > 6 then n = 5 end
        local c = TONE[n + 1]
        local w = math.random(2, 4)
        local h = math.random(1, 2)
        for dy = 0, h - 1 do
          for dx = 0, w - 1 do
            local cur = get(x + dx, y + dy)
            if cur and idx[cur] then set(x + dx, y + dy, c) end
          end
        end
      end
    end
  end
end

local function grass()
  -- 발치 풀 — 지면과 이어붙이는 몫
  local tufts = {
    -- ⚠ 사면 위 뭉치는 뿌리 없이 공중에 떠 보인다 — 발치로 내린다.
    { 12, 108 }, { 18, 112 }, { 44, 116 }, { 22, 104 }, { 15, 100 },
    { 144, 104 }, { 149, 100 }, { 138, 110 }, { 130, 113 }, { 120, 111 },
    { 56, 119 }, { 110, 117 },
  }
  for _, t in ipairs(tufts) do
    local x, y = mx(t[1]), my(t[2])
    local n = 3 + (x % 3)
    for i = 0, n - 1 do
      local bx = x + i * 2 - n
      local hgt = 3 + ((x + i * 5) % 4)
      for k = 0, hgt - 1 do
        local c = (k >= hgt - 1) and C.g3 or C.g2
        if k == 0 then c = C.g1 end
        set(bx + math.floor(k / 3), y - k, c)
      end
    end
  end
end

local function claws()
  -- 입구 앞 발톱 자국 — 나란하지 않게 부러 흐트러뜨렸다
  -- 🔴 굴 아래 나란한 세로 획은 「이빨」로 읽힌다(금색 호 = 「미소」와 합쳐져 얼굴이 된다) — 하이라이트를 걷고 수를 줄이고 각도를 흩는다.
  local marks = {
    { 55, 108, 62, 116 },
    { 68, 106, 71, 117 },
    { 84, 107, 89, 116 },
    { 99, 108, 104, 114 },
  }
  for _, m in ipairs(marks) do
    segO(m[1], m[2], m[3], m[4], 1, 1, C.d2, true)
  end
end

-- 🔴 발자국이 없으면 「짐승 굴」까지만 읽히고 늑대가 안 읽힌다.
--    간격·크기를 손으로 흐트러뜨렸다 — 같은 도장을 반복해 찍으면 대칭으로 읽힌다.
local function paws()
  local pw = {
    { 70, 119, 0 }, { 78, 116, 1 }, { 86, 118, 0 }, { 94, 114, 1 }, { 104, 117, 0 },
    { 62, 115, 1 }, { 112, 113, 0 },
  }
  for _, p in ipairs(pw) do
    local x, y, v = mx(p[1]), my(p[2]), p[3]
    local toes = (v == 0)
      and { {0, 0}, {2, 0}, {4, 0} }
      or  { {0, 0}, {2, -1}, {4, 0} }
    -- ⚠ 어두운 앞자락에 묻히지 않게 — 눌린 자리는 더 어둡게, 흙 턱은 더 밝게.
    for _, t in ipairs(toes) do
      if get(x + t[1], y + t[2]) then set(x + t[1], y + t[2], C.d1) end
    end
    for dx = 1, 3 do
      for dy = 1, 2 do
        if get(x + dx, y + dy) then set(x + dx, y + dy, C.d1) end
      end
    end
    for dx = 0, 4 do
      if get(x + dx, y + 3) then set(x + dx, y + 3, C.d5) end
    end
  end
end

local function bones(broken)
  -- 🔴 두개골은 따뜻한 뼈색(E7D5B3/D7B594)에 아래를 흙에 묻는다 — 무채 회색은 흙과 안 붙고 스티커처럼 뜬다.
  -- ⚠ 작게 그리면 두개골이 아니라 「흰 얼룩」이 된다 — 눈구멍을 키워 뚫고 주둥이를 왼아래로 뺀다.
  -- ⚠ 주인공은 굴이다 — 두개골이 유일한 흰 물건이면 시선이 그리로 간다. 하이라이트를 빼고 대비를 한 단 죽인다.
  local SK = {
    "....WWWWWM......",
    "..MWWWWWWWM.....",
    ".MWWWWWWWWWM....",
    ".MWWKKKWWKKKWM..",
    "MWWKKKKWKKKKWM..",
    "MWWKKKWWKKKWWM..",
    "MWWWWWWWWWWWM...",
    ".MWWWWWWWWWM....",
    ".MWWWWWWWWS.....",
    "MWWKWWKWMS......",
    "MWSMWMSS........",
    ".S..S...........",
  }
  local map = { W = C.d7, M = C.d6, S = C.d2, K = C.k3 }
  local ox, oy = mx(26), my(100)
  for r = 1, #SK do
    local row = SK[r]
    for i = 1, #row do
      local ch = row:sub(i, i)
      local y = oy + r - 1
      -- 아래 두 줄은 흙에 반쯤 묻힌다 (드문드문만 남긴다)
      if ch ~= "." and not (r >= #SK - 1 and (i % 2 == 0)) then
        set(ox + i - 1, y, map[ch])
      end
    end
  end
  -- 정수리에 아주 작은 하이라이트 — 광원 왼쪽 위
  set(ox + 5, oy, C.s5); set(ox + 6, oy, C.s5); set(ox + 4, oy + 1, C.s5)
  -- 갈비뼈 몇 대 (오른쪽 앞자락)
  -- ⚠ 갈비뼈가 어두운 흙에 묻히지 않게 한 단 밝히고 아래에 그늘을 깐다.
  -- ⚠ d7 갈비뼈 둘을 나란히 세우면 「손가락」으로 튄다 — 하나로 줄이고 한 단 낮췄다.
  local ribs = { { 121, 103, 129, 108, 137, 109 } }
  for _, rb in ipairs(ribs) do
    segO(rb[1], rb[2] + 1, rb[3], rb[4] + 1, 2, 1, C.d1)
    segO(rb[3], rb[4] + 1, rb[5], rb[6] + 1, 1, 1, C.d1)
    segO(rb[1], rb[2], rb[3], rb[4], 2, 1, C.d5)
    segO(rb[3], rb[4], rb[5], rb[6], 1, 1, C.d5)
  end
  -- 긴 뼈 하나 (굴 바로 앞 — 시선이 가는 자리)
  local bx, by = mx(44), my(118)
  seg(bx, by + 1, bx + 17, by + 2, 1, 1, C.s3)
  seg(bx, by, bx + 17, by + 1, 2, 2, C.d7)
  set(bx - 1, by, C.d6); set(bx - 1, by + 1, C.s3); set(bx, by - 1, C.d7)
  set(bx + 18, by + 1, C.d6); set(bx + 18, by + 2, C.s3); set(bx + 17, by, C.d7)
  if broken then
    segO(98, 116, 110, 114, 2, 1, C.d7)
    segO(98, 117, 110, 115, 1, 1, C.s3)
  end
end

local function glyph_light()
  -- 🔴 「삼킨 문양이 배어 나온다」 — 발광체가 아니다.
  -- 🔴 가로로 굽은 호는 어떻게 배치해도 「미소」로 읽힌다 — 세로 긁힘으로 간다.
  --    「문양을 삼킨 짐승」이 굴 벽을 긁었고 그 자국에만 빛이 남았다.
  local claw = {
    { 71, 96, 101 },  -- x, y0, y1 (길이·간격을 손으로 흐트러뜨렸다)
    { 75, 91,  99 },
    { 82, 94,  98 },
    { 87, 99, 102 },
  }
  for i, s in ipairs(claw) do
    local gx = mx(s[1])
    for y = my(s[2]), my(s[3]) do
      if get(gx, y) then set(gx, y, C.y0) end
    end
    if get(gx, my(s[2])) then set(gx, my(s[2]), (i == 2) and C.y2 or C.y1) end
  end
end

local function branches(broken)
  if not broken then
    -- 🔴 가지는 마디마다 꺾고(1-2-3-2-1), 밑동을 흙에 박고, 끝을 1px까지 가늘게 뺀다.
    branch(mnodes({ { 92, 58, 4 }, { 101, 51, 3 }, { 109, 46, 3 }, { 117, 38, 2 },
             { 123, 32, 2 }, { 126, 25, 1 }, { 128, 21, 1 } }), true)
    -- ⚠ 곁가지가 주가지와 나란하면 「같은 막대 두 개」로 보인다 — 각도를 완전히 가른다.
    branch(mnodes({ { 110, 56, 2 }, { 119, 51, 2 }, { 127, 49, 1 }, { 134, 50, 1 } }))
    -- 왼쪽으로 기운 가지 (오른쪽보다 짧고 더 꺾인다)
    branch(mnodes({ { 56, 78, 3 }, { 51, 69, 3 }, { 48, 62, 2 }, { 43, 56, 2 },
             { 41, 48, 1 }, { 39, 43, 1 } }), true)
    branch(mnodes({ { 48, 62, 2 }, { 40, 59, 2 }, { 33, 60, 1 } }))
    -- 입구 위를 가로지르는 가지 (시선을 굴로 몰아준다)
    -- ⚠ 굴 크기를 바꾸면 이 가지가 입구를 문다 — 처마 위로 올려라.
    branch(mnodes({ { 50, 84, 3 }, { 60, 76, 3 }, { 74, 68, 3 }, { 88, 69, 2 }, { 100, 76, 2 } }))
    -- 오른 사면의 짧은 그루터기
    branch(mnodes({ { 112, 71, 3 }, { 120, 67, 2 }, { 128, 66, 1 } }), true)
    -- 앞자락에 굴러 있는 가지
    branch(mnodes({ { 99, 113, 3 }, { 110, 110, 3 }, { 122, 109, 2 }, { 133, 108, 1 } }))
  else
    -- 무너진 뒤: 서 있던 가지가 앞으로 쓰러졌다
    -- 🔴 부러진 그루터기를 원래 자리에 남기고 몸통은 앞에 눕힌다 — 그래야 「부러졌다」가 읽힌다.
    branch(mnodes({ { 92, 79, 4 }, { 97, 74, 3 }, { 100, 70, 2 } }), true)   -- 그루터기(오른쪽)
    branch(mnodes({ { 104, 98, 3 }, { 122, 104, 3 }, { 140, 107, 2 }, { 152, 109, 1 } }))
    branch(mnodes({ { 56, 96, 3 }, { 52, 91, 2 }, { 50, 87, 1 } }), true)    -- 그루터기(왼쪽)
    branch(mnodes({ { 48, 106, 3 }, { 34, 111, 3 }, { 22, 114, 2 }, { 12, 116, 1 } }))
    branch(mnodes({ { 58, 112, 3 }, { 78, 116, 3 }, { 98, 113, 2 } }))
    branch(mnodes({ { 112, 88, 3 }, { 120, 85, 2 }, { 127, 84, 1 } }), true) -- 그루터기(오른 사면)
    -- 부러진 단면 — 속살이 밝다. 이게 없으면 그루터기가 그냥 짧은 가지로 보인다.
    for _, t in ipairs({ { 100, 70 }, { 50, 87 }, { 127, 84 } }) do
      local tx, ty = mx(t[1]), my(t[2])
      for dy = 0, 1 do
        for dx = 0, 1 do
          if get(tx + dx, ty + dy) then set(tx + dx, ty + dy, C.d6) end
        end
      end
      if get(tx, ty) then set(tx, ty, C.d7) end
    end
  end
end

-- 🔴 더미 셋을 나란히 두면 검은 삼각형 세 개 = 「이빨」이 된다 — 한 번에 쏟아져 내린 하나의 자락으로 간다.
-- ⚠ 자락이 높으면 남은 함몰을 통째로 덮는다 — 함몰이 보여야 「무너진 굴」이다.
local SPX0 = 60
local SPILLTOP = { -- x = 60..104, 흘러내린 흙의 윗변
  115,114,113,112,111,110,110,109,109,108, -- 60..69
  108,107,107,108,108,107,107,106,106,107, -- 70..79
  107,106,106,107,107,108,108,107,107,108, -- 80..89
  109,109,110,110,111,112,112,113,114,114, -- 90..99
  115,115,116,116,117,                     -- 100..104
}
local function rubble()
  for sx = SPX0, 104 do
    local ty = SPILLTOP[sx - SPX0 + 1]
    local x = mx(sx)
    local a = my(ty)
    local b = my(117)
    for y = a, b do
      local d = y - a
      local c
      if d == 0 then c = C.d5
      elseif d <= 2 then c = C.d4
      elseif d <= 7 then c = C.d3
      else c = C.d2 end
      if y >= b - 1 then c = C.d1 end
      if get(x, y) or y > a then set(x, y, c) end
      if get(x + 1, y) or y > a then set(x + 1, y, c) end
    end
  end
  -- 쏟아진 자국 — 흙이 끌린 결
  for _, m in ipairs({ { 70, 100, 66, 116 }, { 84, 98, 82, 117 }, { 96, 102, 100, 115 } }) do
    segO(m[1], m[2], m[3], m[4], 1, 1, C.d2, true)
  end
end

local function spill()
  -- 🔴 밑변이 톱니면 「찢어진 종이」로 보인다 — 아래로 흙알갱이를 흩어 파낸 흙이 길로 퍼진 결을 만든다(길 색 AD7757 그대로).
  math.randomseed(4471)
  -- ⚠ 낱픽셀이 흩어지면 「부스러기」로 보인다 — 2~4px 덩어리로 밑동에 붙여 흩는다.
  for i = 1, 120 do
    local x = math.random(X0 - 2, X1 + 2)
    local by = botAt(x) or botAt(math.min(math.max(x, X0), X1))
    if by then
      local y = by + math.random(1, 3)
      if y < H and not get(x, y) then
        local c = (math.random() < 0.7) and C.d4 or C.d3
        if math.random() < 0.15 then c = C.d5 end
        local w = math.random(2, 4)
        local h = (math.random() < 0.4) and 2 or 1
        for dy = 0, h - 1 do
          for dx = 0, w - 1 do
            if not get(x + dx, y + dy) and y + dy < H then set(x + dx, y + dy, c) end
          end
        end
      end
    end
  end
end

local function ground_shadow()
  -- 광원 반대(오른아래)로 떨어지는 접지 그림자 — 왼쪽엔 안 붙인다
  for x = mx(80), X1 + 4 do
    local by = botAt(x) or botAt(X1)
    if by then
      local n = 1 + math.floor((x - mx(80)) / 36)
      for k = 1, n do
        local y = by + k
        if y < H then
          local cur = get(x, y)
          if cur == nil or cur == C.d4 or cur == C.d3 or cur == C.d5 then
            set(x, y, (k == 1) and C.d1 or C.d2)
          end
        end
      end
    end
  end
end

local function rim_light(broken)
  -- 능선 윗변에 1px 하이라이트 — 왼쪽 위를 향한 면에만
  for x = X0 + 1, X1 - 1 do
    local a, b = topAt(x - 1), topAt(x + 1)
    local ty = topAt(x)
    if a and b and ty then
      if broken then
        a = a + slumpAt(x - 1); b = b + slumpAt(x + 1); ty = ty + slumpAt(x)
      end
      local slope = b - a
      if slope <= -1 then
        if get(x, ty) then set(x, ty, C.d6) end
        if get(x, ty + 1) and slope <= -2 then set(x, ty + 1, C.d5) end
      elseif slope >= 2 then
        if get(x, ty) then set(x, ty, C.d1) end
      end
    end
  end
end

----------------------------------------------------------------------
-- 조립
----------------------------------------------------------------------
local function compose(broken)
  clear()
  build_mound(broken)
  form_lobes()
  roots(broken)
  stones()
  grain()
  rim_light(broken)
  carve_mouth(broken)
  if broken then rubble() end
  claws()
  paws()
  spill()
  outline()
  branches(broken)
  bones(broken)
  grass()
  if not broken then glyph_light() end
  ground_shadow()
end

----------------------------------------------------------------------
-- 출력
----------------------------------------------------------------------
local function hex2rgb(h)
  return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
end

local spr = Sprite(W, H, ColorMode.RGB)
spr.filename = "C:/Users/djgnf/Desktop/godot_games/tockbon/assets/aseprite/nest_wolf.aseprite"
while #spr.frames < 2 do spr:newEmptyFrame() end

for fi = 1, 2 do
  compose(fi == 2)
  local img = Image(W, H, ColorMode.RGB)
  img:clear(app.pixelColor.rgba(0, 0, 0, 0))
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local c = B[y][x]
      if c then
        local r, g, b = hex2rgb(c)
        img:drawPixel(x, y, app.pixelColor.rgba(r, g, b, 255))
      end
    end
  end
  spr:newCel(spr.layers[1], fi, img, Point(0, 0))
end

spr.layers[1].name = "nest"
spr:saveAs(spr.filename)
print("saved " .. spr.filename .. " frames=" .. #spr.frames)
