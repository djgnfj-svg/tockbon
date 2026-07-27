-- 밑그림 생성기 — 흙길/바닥 타일시트 (512x320, 64px, 8x5)
-- 세99. 생성기는 밑그림까지다 (ART_SPEC §4). 완성은 손질 패스가 한다.
--
-- 손질 1회차 반영:
--  ③ 경계가 일정 진폭 톱니 → 긴 평탄 구간 + 드문 큰 굴곡으로 리듬을 줬다
--  ② 그늘 띠 두께 균일 → 두께 프로파일(1~3px)로 자리마다 다르게
--  ④ 밝은 테두리가 실루엣을 그대로 복사 → 끊김 마스크로 조각내고 D.hi → D.lit으로 낮춤
--  ⑤ 질감 균등 분포 → 큰 저대비 패치 위주 + 고대비는 뭉쳐서 소량

local OUT_ASE = "C:/Users/djgnf/Desktop/godot_games/tockbon/assets/aseprite/tileset_ground.aseprite"

local W, H, T = 512, 320, 64
local INSET = 12             -- 풀↔흙 경계 기준 깊이 (타일 경계에서 고정 = 이어붙임 계약)
local FAR   = T - 1 - INSET  -- 51
local R_OUT = 7
local R_NUB = 6

------------------------------------------------------------------ 팔레트 (TAKBON 60)
local G = { deepest=0x16281c, deep=0x19332d, shade=0x25562e, base=0x468232,
            warm=0x7a8c2e, lit=0x75a743, hi=0xa8ca58, pale=0xd0da91, cool=0x2f6152 }
local D = { umber=0x2e1f18, dark=0x4d2b32, deep=0x7a4841, brown=0x884b2b, base=0xad7757,
            lit=0xc09473, hi=0xd7b594, pale=0xe7d5b3, warm=0xbe772b, ochre=0xc9962e }
local S = { deep=0x2a2c32, dark=0x394a50, med=0x4e5259, mid=0x577277, lit=0x819796, hi=0xa8b5b2 }

------------------------------------------------------------------ 경계 프로파일
-- 숫자 = 5 기준 편차(px). 🔴 첫·끝 글자는 '5' — 아니면 이어붙일 때 이음매가 튄다.
-- 리듬: 긴 평탄 구간 사이에 드문 큰 굴곡. 균일 톱니를 만들지 마라.
local PROF = {
  HT_A = "55544445" .. "55566665" .. "55444333" .. "21112223" .. "44455555" .. "66667777" .. "66655544" .. "43344455",
  HB_A = "55566665" .. "55444455" .. "66777666" .. "55554444" .. "33334445" .. "55566778" .. "87665443" .. "34445555",
  VL_A = "55444455" .. "66665554" .. "44433322" .. "23334444" .. "55566677" .. "76665554" .. "44455556" .. "66555555",
  VR_A = "55555666" .. "77766655" .. "44444555" .. "56666555" .. "44433344" .. "44555566" .. "66555444" .. "33444555",
  HT_B = "55666677" .. "76665555" .. "44433221" .. "12334455" .. "65554444" .. "33344455" .. "56666555" .. "44455555",
  HB_B = "54444333" .. "34445555" .. "66666555" .. "44455566" .. "77666555" .. "44443334" .. "44555566" .. "55444455",
  VL_B = "55555444" .. "43333444" .. "55566677" .. "66655554" .. "44443344" .. "45555666" .. "65554444" .. "55566555",
  VR_B = "55444333" .. "34455556" .. "66788776" .. "55554444" .. "34445555" .. "66655544" .. "44333444" .. "55556555",
}
local dev = {}
for k, s in pairs(PROF) do
  assert(#s == 64, k .. " 길이 " .. #s)
  assert(s:sub(1,1) == "5" and s:sub(64,64) == "5", k .. " 양끝")
  local a = {}
  for i = 0, 63 do a[i] = tonumber(s:sub(i+1, i+1)) - 5 end
  dev[k] = a
end

-- 그늘 두께(1~3px)·테두리 끊김 — 경계를 따라가며 변한다. (x+y)로 색인하면 가로·세로·모서리 모두 변한다.
local SHW = "33322111" .. "22333221" .. "11122333" .. "32221113" .. "33322211" .. "12233322" .. "21113332" .. "22111233"
local BRK = "11011100" .. "01111010" .. "00111101" .. "11000111" .. "01110011" .. "11101000" .. "00110111" .. "11011001"
assert(#SHW == 64 and #BRK == 64)
local function shw(x, y) return tonumber(SHW:sub(((x + y) % 64) + 1, ((x + y) % 64) + 1)) end
local function brk(x, y, o) local i = (x + y + o) % 64; return BRK:sub(i + 1, i + 1) == "1" end

------------------------------------------------------------------ 질감 스탬프 (좌우 비대칭 — 손으로 찍었다)
local ST = {
  {"..##.", ".####", "..###", "...#.", "....."},
  {".###.", "####.", ".##..", ".....", "....."},
  {"..#..", ".###.", "####.", "..##.", "....."},
  {"###..", "####.", ".###.", ".#...", "....."},
  {".##..", "###..", ".###.", "..#..", "....."},
  {"..#..", ".##..", ".###.", ".##..", "....."},
}
-- 🔴 손질 4회차 — 색 비율을 재 보니 짙은 색은 **0.3%뿐인데도 「벌레」처럼 튀었다**.
--   원인은 양이 아니라 **크기**다: 평평한 초록 위의 5~9px 덩어리는 지형이 아니라 점으로 읽힌다.
--   그래서 지우는 대신 **크게** 만들었다 — 22x18짜리 얼룩은 같은 색이어도 「그늘진 자리」로 읽힌다.
local HUGE = {
  { "........####..........", ".....#########........", "...############.......",
    "..##############......", ".################.....", "##################....",
    "###################...", "####################..", "####################..",
    "###################...", "#################.....", "..###############.....",
    "...#############......", "....###########.......", ".....########.........",
    "......#####...........", ".......###............", "......................" },
  { "..........#####.......", ".......##########.....", ".....#############....",
    "...###############....", "..#################...", ".##################...",
    "####################..", "###################...", "#################.....",
    "###############.......", "#############.........", "############..........",
    "###########...........", "..########............", "...######.............",
    "....####..............", ".....##...............", "......................" },
}
for i, s in ipairs(HUGE) do
  assert(#s == 18, "HUGE " .. i .. " 행 수 " .. #s)
  for j, row in ipairs(s) do assert(#row == 22, "HUGE " .. i .. " 행 " .. j .. " 길이 " .. #row) end
end

local BIG = {
  {"..####...", ".#######.", "#########", "#########", ".#######.", "..#####..", "...###...", "....#....", "........."},
  {"....###..", "..######.", ".########", "#########", "########.", "######...", "..#####..", "...####..", ".....##.."},
  {"..###....", ".######..", "########.", "#######..", "#######..", "..#####..", "...####..", "....##...", "........."},
  {".....#...", "...####..", "..######.", ".#######.", "########.", "#######..", "#####....", "..###....", "...#....."},
}

------------------------------------------------------------------ 픽셀 버퍼
local px = {}
for i = 0, W * H - 1 do px[i] = 0x000000 end
local function put(x, y, c) if x >= 0 and y >= 0 and x < W and y < H then px[y * W + x] = c end end

------------------------------------------------------------------ 마스크 (true = 흙)
local function makeMask(cons, nubs, v)
  local ht, hb = dev["HT_" .. v], dev["HB_" .. v]
  local vl, vr = dev["VL_" .. v], dev["VR_" .. v]
  local hasT = cons:find("T") ~= nil
  local hasB = cons:find("B") ~= nil
  local hasL = cons:find("L") ~= nil
  local hasR = cons:find("R") ~= nil
  local m = {}
  for y = 0, T - 1 do
    m[y] = {}
    for x = 0, T - 1 do
      local dT = y - (INSET + ht[x])
      local dB = (FAR - hb[x]) - y
      local dL = x - (INSET + vl[y])
      local dR = (FAR - vr[y]) - x
      local ok = true
      if hasT and dT < 0 then ok = false end
      if hasB and dB < 0 then ok = false end
      if hasL and dL < 0 then ok = false end
      if hasR and dR < 0 then ok = false end
      local function cut(a, b)
        if a < R_OUT and b < R_OUT then
          local u, w = R_OUT - a, R_OUT - b
          if u * u + w * w > R_OUT * R_OUT then ok = false end
        end
      end
      if ok then
        if hasT and hasL then cut(dT, dL) end
        if hasT and hasR then cut(dT, dR) end
        if hasB and hasL then cut(dB, dL) end
        if hasB and hasR then cut(dB, dR) end
      end
      if ok and nubs then
        for _, n in ipairs(nubs) do
          local a, b
          if n == "TL" then a = (INSET + ht[x]) - 1 - y; b = (INSET + vl[y]) - 1 - x
          elseif n == "TR" then a = (INSET + ht[x]) - 1 - y; b = x - (FAR - vr[y]) - 1
          elseif n == "BL" then a = y - (FAR - hb[x]) - 1; b = (INSET + vl[y]) - 1 - x
          else a = y - (FAR - hb[x]) - 1; b = x - (FAR - vr[y]) - 1 end
          if a >= 0 and b >= 0 then
            local keep = true
            if a < R_NUB and b < R_NUB then
              local u, w = R_NUB - a, R_NUB - b
              if u * u + w * w > R_NUB * R_NUB then keep = false end
            end
            if keep then ok = false end
          end
        end
      end
      m[y][x] = ok
    end
  end
  return m
end

------------------------------------------------------------------ 질감 레시피
-- 🔴 넓은 면은 조용해야 한다 (ART_SPEC §3.6). 큰 저대비 패치가 몸통이고 고대비는 뭉쳐서 아주 조금.
-- 🔴 손질 2회차: **넓은 저대비 얼룩이 몸통이고 고대비 점은 거의 없다.**
--   1회차의 작은 점 위주 질감은 이어 붙인 판에서 ⓐ 자글자글하고 ⓑ **반복이 그대로 읽혔다**
--   (점은 모양이 또렷해 눈이 같은 배열을 알아본다 — 부드러운 얼룩은 반복해도 안 들킨다).
-- 🔴🔴 손질 3회차 — **같은 타일 6x4 반복 검사**에서 물방울무늬 벽지가 나왔다(⑤+③).
--   답은 「무늬를 더 그리기」가 아니라 **비우기**다: 기존 `tile_grass.png`도 96%가 단색이다(ART_SPEC §3.6).
--   ⚠ 그리고 얼룩을 **타일 모서리에 걸쳐 둔다** — 감싸서 찍히므로 이웃 칸과 **이어져 한 덩어리**가 되고,
--     격자로 반복되는 「점」이 아니라 판을 가로지르는 큰 형태로 읽힌다.
local GRASS_BIG   = { {2,46,1},{34,6,3},{57,27,2},{20,58,4} }
local GRASS_SMALL = { {36,9,5,"warm"},{5,49,2,"warm"},{60,30,6,"warm"} }
local GRASS_TUFT  = { {38,11,4,"lit"} }
local DIRT_BIG    = { {4,42,2},{38,4,4},{58,24,1},{24,57,3} }                   -- 볕에 마른 자리
local DIRT_SMALL  = { {41,7,3,"lit"},{7,45,1,"lit"} }
local DIRT_RUT    = { {45,30,3,"deep"} }                                        -- 파인 자국
local PEBBLES     = { {44,32},{47,29},{51,33} }                                 -- 한 무리에만 몰아준다

local function stampG(ox, oy, bx, by, tbl, sidx, col, mask, want)
  local s = tbl[sidx]
  for j = 1, #s do
    local row = s[j]
    for i = 1, #row do
      if row:sub(i, i) == "#" then
        local tx, ty = (bx + i - 1) % T, (by + j - 1) % T
        if mask == nil or mask[ty][tx] == want then put(ox + tx, oy + ty, col) end
      end
    end
  end
end

------------------------------------------------------------------ 타일 한 장
local function paintTile(ox, oy, mask, tox, toy, opt)
  opt = opt or {}
  for y = 0, T - 1 do
    for x = 0, T - 1 do
      put(ox + x, oy + y, mask[y][x] and (opt.dirtBase or D.base) or (opt.grassBase or G.base))
    end
  end
  if not opt.noGrass then
    for _, e in ipairs(GRASS_BIG) do
      stampG(ox, oy, (e[1]+tox)%T, (e[2]+toy)%T, BIG, e[3], G.warm, mask, false) end
    for _, e in ipairs(GRASS_SMALL) do
      stampG(ox, oy, (e[1]+tox)%T, (e[2]+toy)%T, ST, e[3], G[e[4]], mask, false) end
    for _, e in ipairs(GRASS_TUFT) do
      stampG(ox, oy, (e[1]+tox)%T, (e[2]+toy)%T, ST, e[3], G[e[4]], mask, false) end
  end
  if not opt.noDirt then
    for _, e in ipairs(DIRT_BIG) do
      stampG(ox, oy, (e[1]+tox)%T, (e[2]+toy)%T, BIG, e[3], D.lit, mask, true) end
    for _, e in ipairs(DIRT_SMALL) do
      stampG(ox, oy, (e[1]+tox)%T, (e[2]+toy)%T, ST, e[3], D[e[4]], mask, true) end
    for _, e in ipairs(DIRT_RUT) do
      stampG(ox, oy, (e[1]+tox)%T, (e[2]+toy)%T, ST, e[3], D[e[4]], mask, true) end
    if not opt.noPebbles then
      for _, p in ipairs(PEBBLES) do
        local bx, by = (p[1]+tox)%T, (p[2]+toy)%T
        for j = 0, 1 do for i = 0, 1 do
          local tx, ty = (bx+i)%T, (by+j)%T
          if mask[ty][tx] then put(ox+tx, oy+ty, D.lit) end
        end end
        if mask[by][bx] then put(ox+bx, oy+by, D.hi) end
        local sx, sy = (bx+2)%T, (by+1)%T
        if mask[sy][sx] then put(ox+sx, oy+sy, D.deep) end
      end
    end
  end
  -- 경계 음영 — 광원 왼쪽 위. 길이 파였고 풀이 높다.
  if not opt.flat then
    local snap = {}
    for y = 0, T-1 do snap[y] = {} for x = 0, T-1 do snap[y][x] = mask[y][x] end end
    -- 🔴 타일 밖은 **감싸지 말고 붙들어라(clamp)**. 감싸면 `dirt_R`처럼 한쪽만 풀인 타일이
    --   자기 반대편을 이웃으로 착각해 **왼쪽 끝에 없는 그늘을 긋는다** — 한 칸만 보면 안 보이고
    --   이어 붙인 판에서 **흙 한복판에 검은 세로줄**로 드러난다(손질 2회차에 이 판에서 잡혔다).
    -- ⚠ 예외 하나: **자기 자신과 이어 깔리는 얼룩 칸**은 감싸야 한다(clamp하면 좌우 끝에서 음영이
    --   끊겨 이음매가 보인다). 길 타일은 clamp, 얼룩 칸은 wrap — 쓰임이 달라 규칙도 다르다.
    local function dirtAt(x, y)
      if opt.wrapShade then return snap[(y+T)%T][(x+T)%T] end
      local cx = x < 0 and 0 or (x > T-1 and T-1 or x)
      local cy = y < 0 and 0 or (y > T-1 and T-1 or y)
      return snap[cy][cx]
    end
    for y = 0, T-1 do
      for x = 0, T-1 do
        if snap[y][x] then
          -- 흙: 위/왼쪽에 풀이 있으면 그늘. 두께가 자리마다 다르다.
          local th = shw(x, y)
          local hit = 0
          for d = 1, th do
            -- 🔴 왼쪽에 풀이 있다고 다 그늘이 아니다. **아래 둑**(길 건너편 풀)도 경계가 굽으면
            --   왼쪽에 걸린다 — 그러면 아래 경계에까지 검은 줄이 그어진다(5배 확대에서 잡혔다).
            --   「그 풀이 위로도 이어지는가」를 같이 물어 **가까운 둑일 때만** 그늘을 준다.
            local leftBank = (not dirtAt(x-d, y)) and (not dirtAt(x-d, y-1))
            local upBank   = (not dirtAt(x, y-d)) and (not dirtAt(x-1, y-d))
            if leftBank or upBank or ((not dirtAt(x-d, y-d)) and (not dirtAt(x-d, y-d+1))) then
              hit = d; break
            end
          end
          -- 🔴 두께만이 아니라 **진하기도 같이 변한다** — 두께만 흔들면 굵기가 같은 검은 아이라인이
          --   그대로 남는다(② 윤곽선 굵기가 어디나 같다). 얕은 자리는 연하게 끝난다.
          if hit > 0 then
            local ramp = (th == 3) and { D.dark, D.deep, D.brown }
                      or ((th == 2) and { D.deep, D.brown } or { D.brown })
            put(ox+x, oy+y, ramp[hit] or D.brown)
          end
          -- 아래/오른쪽 풀 턱의 발치 — 빛이 닿는다. 끊어서만.
          -- 🔴 두 자리를 다 만족할 때만 = 점선이 아니라 **끊긴 토막**이 된다(1회차엔 점선이었다)
          if hit == 0 and ((not dirtAt(x+1, y)) or (not dirtAt(x, y+1)))
             and brk(x, y, 0) and brk(x, y, 1) then
            put(ox+x, oy+y, D.lit)
          end
        else
          -- 풀: 흙이 위/왼쪽 = 올라오는 비탈이라 빛을 받는다 / 아래·오른쪽 = 떨어지는 턱 끝
          -- 같은 「둑 판정」을 풀 쪽에도 쓴다 — 안 그러면 굽은 자리에서 위 둑이 아랫 둑 취급을 받는다.
          -- 🔴 **먼 둑은 빛을 받는 비탈이다** — 그늘의 짝이라 폭도 같이 변해야 한 몸으로 읽힌다.
          --   1px 균일 테두리로 두니 길이 「오려 붙인 종이」로 보였다.
          local th = shw(x, y)
          local far = 0
          for d = 1, th do
            if (dirtAt(x, y-d) and dirtAt(x-1, y-d)) or (dirtAt(x-d, y) and dirtAt(x-d, y-1)) then
              far = d; break
            end
          end
          local nearBank = (dirtAt(x, y+1) and dirtAt(x+1, y+1)) or (dirtAt(x+1, y) and dirtAt(x+1, y+1))
          if far > 0 then
            if far == 1 and th == 3 and brk(x, y, 11) then put(ox+x, oy+y, G.hi)
            else put(ox+x, oy+y, G.lit) end
          elseif nearBank and brk(x, y, 29) then
            put(ox+x, oy+y, G.shade)
          end
        end
      end
    end
  end
end

------------------------------------------------------------------ 타일 표
local TILES = {
  {0,0,"TL","dirt_TL",nil,"A"}, {1,0,"T","dirt_T_a",nil,"A"}, {2,0,"T","dirt_T_b",nil,"B"},
  {3,0,"TR","dirt_TR",nil,"A"}, {4,0,"L","dirt_L",nil,"A"}, {5,0,"","dirt_C_a",nil,"A"},
  {6,0,"R","dirt_R",nil,"A"}, {7,0,"","dirt_C_b",nil,"B"},
  {0,1,"BL","dirt_BL",nil,"A"}, {1,1,"B","dirt_B_a",nil,"A"}, {2,1,"B","dirt_B_b",nil,"B"},
  {3,1,"BR","dirt_BR",nil,"A"},
  {4,1,"","in_TL",{"TL"},"A"}, {5,1,"","in_TR",{"TR"},"A"},
  {6,1,"","in_BL",{"BL"},"A"}, {7,1,"","in_BR",{"BR"},"A"},
  {0,2,"LR","path_V_a",nil,"A"}, {1,2,"LR","path_V_b",nil,"B"},
  {2,2,"TB","path_H_a",nil,"A"}, {3,2,"TB","path_H_b",nil,"B"},
  {4,2,"TL","corner_ES",{"BR"},"A"}, {5,2,"TR","corner_WS",{"BL"},"A"},
  {6,2,"BL","corner_EN",{"TR"},"A"}, {7,2,"BR","corner_WN",{"TL"},"A"},
  {0,3,"BLR","end_N",nil,"A"}, {1,3,"TLR","end_S",nil,"A"},
  {2,3,"TBR","end_W",nil,"A"}, {3,3,"TBL","end_E",nil,"A"},
  {4,3,"","cross",{"TL","TR","BL","BR"},"A"},
  {5,3,"T","tee_S",{"BL","BR"},"A"}, {6,3,"B","tee_N",{"TL","TR"},"A"},
  {7,3,"L","tee_E",{"TR","BR"},"A"},
  {0,4,"R","tee_W",{"TL","BL"},"A"},
}
local OFF = { {0,0},{23,11},{41,29},{7,44},{52,19},{30,53},{17,35},{45,6} }
local function offFor(c, r) local o = OFF[((c*3 + r*5) % 8) + 1]; return o[1], o[2] end

for _, t in ipairs(TILES) do
  local m = makeMask(t[3], t[5], t[6])
  local tox, toy = offFor(t[1], t[2])
  paintTile(t[1]*T, t[2]*T, m, tox, toy, {})
end

------------------------------------------------------------------ 바닥 다양성 (row 4)
local function fullMask(val)
  local m = {}
  for y = 0, T-1 do m[y] = {} for x = 0, T-1 do m[y][x] = val end end
  return m
end

-- (1,4) 풀 A — 낮 기본
paintTile(1*T, 4*T, fullMask(false), 9, 21, { flat = true })
-- (2,4) 풀 B — 짙은 얼룩·이끼
do
  paintTile(2*T, 4*T, fullMask(false), 37, 5, { flat = true })
  local ox, oy = 2*T, 4*T
  -- 🔴 얼룩은 **크고 조용하게**. 1회차의 짙은 작은 점은 이어 붙인 판에서 「벌레」로 보였다.
  -- 🔴🔴 손질 5회차 — 짙은 얼룩을 **크게** 만들어 봤더니 점이 아니라 **돌덩이**가 됐다(더 나빠졌다).
  --   TAKBON 60의 초록은 간격이 넓어 base(#468232)보다 어두운 색은 전부 Δ휘도 23↑다 —
  --   그 정도 차이는 크기와 무관하게 **물체로 읽힌다**.
  --   🔴 결론: **풀 위에는 밝은 자국만 얹는다.** 어두운 자국은 구멍·벌레·돌이 되고,
  --      밝은 자국은 「빛 받은 풀잎」으로 가라앉는다. 프로젝트의 기존 `tile_grass.png`도
  --      어두운 바탕에 **밝은 색만** 흩어 놨다 — 그게 이 팔레트에서 되는 방식이다.
  --   그래서 풀B는 「짙은 풀」이 아니라 **「볕에 마른 풀」**(warm이 넓게 깔린 자리)로 성격을 바꿨다.
  stampG(ox, oy, 6, 8, HUGE, 1, G.warm, nil, nil)
  stampG(ox, oy, 38, 40, HUGE, 2, G.warm, nil, nil)
  for _, e in ipairs({{50,22,2},{22,44,4}}) do
    stampG(ox, oy, e[1], e[2], BIG, e[3], G.warm, nil, nil) end
  for _, e in ipairs({{12,17,2},{44,49,5},{30,30,1}}) do
    stampG(ox, oy, e[1], e[2], ST, e[3], G.lit, nil, nil) end
end
-- (3,4) 풀 C — 밝은 새순·잔꽃
do
  paintTile(3*T, 4*T, fullMask(false), 51, 33, { flat = true })
  local ox, oy = 3*T, 4*T
  -- 새순은 **두 무리에만** 몰아준다 (⑤ — 시선 가는 곳에 디테일, 나머지는 비운다)
  for _, e in ipairs({{13,10,2},{16,14,5},{41,31,3},{45,35,1}}) do
    stampG(ox, oy, e[1], e[2], ST, e[3], G.lit, nil, nil) end
  -- 🔴 밝은 점은 **한 자리만**. 두 자리를 두니 판 위에 흰 점이 격자로 찍혔다.
  put(ox+14, oy+12, G.hi); put(ox+15, oy+12, G.hi); put(ox+14, oy+13, G.hi)
end
-- (4,4) 마른 흙
paintTile(4*T, 4*T, fullMask(true), 13, 47, { flat = true })
-- (5,4) 자갈 — 다져진 흙 위에 돌이 뭉쳐 깔렸다
-- 🔴 손질 5회차에 통째로 다시 잡았다. 옛 판은 **어두운 자줏빛 바탕(#7a4841) + 청회색 돌**이라
--    「자갈」이 아니라 **생고기에 뿌린 색종이**로 보였다. 원인 둘:
--    ⓐ 바탕이 옆 흙 타일과 톤이 갈려 같은 땅으로 안 읽혔다 ⓑ 청회색은 이 화면에 없는 색계열이다.
--    → 바탕은 **흙과 같은 색**으로 두고 「알갱이가 드러난 자리」로 만든다. 회색 돌은 **셋만** 섞는다.
do
  paintTile(5*T, 4*T, fullMask(true), 28, 9, { flat = true, noPebbles = true, noDirt = true })
  local ox, oy = 5*T, 4*T
  -- 톤 변화는 **밝은 쪽으로만** (어두운 얼룩은 딱지처럼 보였다 — 풀에서 배운 것과 같은 규칙이다)
  for _, e in ipairs({{6,40,2},{40,8,4},{30,46,1}}) do
    stampG(ox, oy, e[1], e[2], BIG, e[3], D.lit, nil, nil) end
  -- 무리 셋 + 흩어진 몇 (균등 분포 금지). 🔴 회색 돌은 뺐다 — TAKBON의 회색은 **푸른 계열**이라
  --   따뜻한 흙 위에서 파란 점으로 튄다(초록 위의 주황과 같은 병).
  local stones = { {6,8},{10,6},{9,12},{14,10},{5,15},{13,15},{17,7},{11,17},
                   {38,30},{43,27},{41,34},{47,32},{36,36},{45,38},{50,29},{39,41},{44,44},
                   {22,52},{26,49},{20,57},{28,55},
                   {55,14},{58,46},{31,20} }
  for i, s in ipairs(stones) do
    local wide = (i % 4 ~= 0)
    local body = (i % 3 == 0) and D.lit or D.hi
    for j = 0, 1 do for k = 0, (wide and 2 or 1) do
      put(ox + (s[1]+k)%T, oy + (s[2]+j)%T, body) end end
    if i % 5 == 0 then put(ox + s[1]%T, oy + s[2]%T, D.pale) end   -- 제일 밝은 점은 드물게
    put(ox + (s[1]+ (wide and 3 or 2))%T, oy + (s[2]+1)%T, D.deep)
  end
end
-- (6,4) 잔풀이 난 흙 — **긴 길의 단조로움을 깨는** 흙 변형
--
-- 🔴🔴 이 칸은 세 번 갈아엎었다. 「마른 잎(갈색)」 → 「드러난 흙(#ad7757)」 → 지금.
--   앞의 둘이 실패한 이유가 **같다**: 풀 위에 **떠 있는 다른 색 섬**은 크기·밝기와 무관하게
--   **물체로 읽힌다**(갈색은 붉은 점, 살구색은 분홍 꽃잎이 됐다 — 판에 깔아 보고서야 드러났다).
--   🔴 규칙: **흙은 길에 붙어 있을 때만 흙이다.** 풀밭 한복판에 흙 섬을 띄우지 마라.
--   그래서 방향을 뒤집었다 — 풀 위의 흙이 아니라 **흙 위의 풀**이다. 길에 난 잡초는 눈에
--   익은 형태라 물체로 튀지 않고, 무엇보다 **가장 많이 반복되는 면(길)**을 깨 준다.
do
  paintTile(6*T, 4*T, fullMask(true), 44, 27, { flat = true })
  local ox, oy = 6*T, 4*T
  for _, e in ipairs({{11,14,2},{15,11,5},{9,19,1},{17,17,4},{38,45,3},{42,49,6}}) do
    stampG(ox, oy, e[1], e[2], ST, e[3], G.warm, nil, nil) end
  put(ox+12, oy+13, G.lit); put(ox+39, oy+46, G.lit)
  -- 낙엽은 **쌓인 데 쌓인다** — 한 무리로 몰아준다. 고루 뿌리면 판 전체가 자글자글해진다.
  -- 🔴 주황(ochre/warm)은 뺐다 — 초록의 보색이라 0.03%만 있어도 판에서 색종이 조각으로 튄다.
end
-- (7,4) 흙·풀 얼룩 (전이 — 길 가장자리를 흐린다)
-- 🔴 `flat`이다. 둑 음영(밝은 테두리)을 얹었더니 풀 섬마다 밝은 초록 테가 둘려 **브로콜리**가 됐다.
--    여기 풀은 「길보다 높은 둑」이 아니라 **같은 높이에 섞인 풀**이라 테두리가 붙을 이유가 없다.
-- ⚠ 그래서 감쌈(wrapShade)도 필요 없다 — 음영을 아예 안 그리니 이음매가 생길 자리가 없다.
do
  local m = fullMask(true)
  for _, e in ipairs({{4,6,1},{34,8,3},{9,38,2},{47,24,4},{25,47,3},{52,44,1},{60,12,3}}) do
    local s = BIG[e[3]]
    for j = 1, #s do
      local row = s[j]
      for i = 1, #row do
        if row:sub(i,i) == "#" then m[(e[2]+j-1)%T][(e[1]+i-1)%T] = false end
      end
    end
  end
  for _, e in ipairs({{2,30,1},{40,50,2}}) do
    local s = HUGE[e[3]]
    for j = 1, #s do
      local row = s[j]
      for i = 1, #row do
        if row:sub(i,i) == "#" then m[(e[2]+j-1)%T][(e[1]+i-1)%T] = false end
      end
    end
  end
  paintTile(7*T, 4*T, m, 19, 41, { flat = true })
end

------------------------------------------------------------------ 저장
local spr = Sprite(W, H, ColorMode.RGB)
spr.filename = OUT_ASE
local img = Image(W, H, ColorMode.RGB)
for y = 0, H-1 do
  for x = 0, W-1 do
    local v = px[y*W + x]
    img:drawPixel(x, y, app.pixelColor.rgba(math.floor(v/65536)%256, math.floor(v/256)%256, v%256, 255))
  end
end
spr.cels[1].image = img
spr.cels[1].position = Point(0, 0)
spr:saveAs(OUT_ASE)
print("OK saved " .. OUT_ASE)
