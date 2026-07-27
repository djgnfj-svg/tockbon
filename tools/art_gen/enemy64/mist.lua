-- 안개 정령 — 64x64 x 4프레임.
-- 🔴 1회차는 구체 음영기를 그대로 썼더니 「다리 달린 돌덩이」가 됐다. 안개는 테두리가 있으면 안 된다.
--    행별 좌/우 폭 표(손으로 쓴 값)로 두건 쓴 형체를 잡고, 검은 외곽선 없이 명도로만 가장자리를 만든다.
local DIR = "C:/Users/djgnf/Desktop/godot_games/tockbon/tools/art_gen/enemy64/"
local OUT = "C:/Users/djgnf/Desktop/godot_games/tockbon/assets/sprites/enemies/"
local L = dofile(DIR .. "lib.lua")

local SIDE, N = 64, 4
local RAMP = {"f7f7f2","ebede9","c7cfcc","a8b5b2","819796","577277","4e5259","394a50","2a2c32"}
local THR  = {0.99, 0.88, 0.75, 0.615, 0.47, 0.33, 0.19, 0.05}

local HEX = {"f7f7f2","ebede9","c7cfcc","a8b5b2","819796","577277","4e5259","394a50","2a2c32",
             "202e37","151d28","c8f5ee","a4dddb","73bed3","3fa9a0","2f6152"}
local C = {}
for _, h in ipairs(HEX) do C[h] = L.hex(h) end

-- ── 몸 윤곽: y=2..47, {왼쪽 폭, 오른쪽 폭}. 머리 → 목 → 어깨 → 자락으로 벌어진다 ──
local PROF = {
  {2,3},
  {4,5},{7,8},{9,10},{11,11},{12,12},{13,13},{14,13},{14,14},{15,14},{15,15},
  {15,15},{15,15},{15,14},{14,14},{14,14},{14,13},{13,13},{13,12},{12,12},{12,11},
  {11,11},{11,12},{12,13},{13,15},{15,17},{17,18},{18,20},{19,21},{20,22},{21,22},
  {21,23},{22,23},{22,24},{23,24},{23,24},{23,25},{24,25},{24,25},{24,24},{23,24},
  {23,23},{22,23},{21,22},{20,21},{19,19},{17,18},
  {16,17},{15,15},{13,14},{12,12},{10,11},{8,9},
}
local TOPY = 1

-- 가장자리 홈 (손으로 고른 자리만 파인다 — 매끈한 타원을 깨는 값)
local NOTCH = {
  { {6,"R",2},{13,"L",2},{19,"R",3},{24,"L",2},{30,"R",2},{33,"L",3},{38,"R",2},{42,"L",2} },
  { {5,"L",2},{11,"R",3},{17,"L",2},{23,"R",2},{28,"L",3},{35,"R",2},{40,"L",2},{44,"R",2} },
  { {8,"R",3},{14,"L",2},{20,"R",2},{26,"L",2},{31,"R",3},{36,"L",2},{41,"R",2},{45,"L",2} },
  { {4,"L",2},{10,"R",2},{16,"L",3},{22,"R",2},{29,"L",2},{34,"R",3},{39,"L",2},{43,"R",2} },
}

local FR = {
  { lean = {0,0,0,0,-1,-1,-1,0,0,0,0,1,1,1,1,1,0,0,0,0,-1,-1,-1,-1,0,0,0,0,1,1,1,1,1,1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0},
    bob = 1, wisp = { {-11,7,-0.26,6},{-1,9,-0.04,7},{9,6,0.20,5} } },
  { lean = {1,1,1,0,0,0,-1,-1,-1,-1,0,0,0,1,1,1,1,1,1,0,0,0,-1,-1,-1,-1,-1,0,0,0,0,1,1,1,1,0,0,0,0,-1,-1,-1,-1,0,0,0},
    bob = 0, wisp = { {-12,5,-0.38,5},{-2,8,-0.18,7},{8,9,0.10,6} } },
  { lean = {-1,-1,0,0,0,1,1,1,1,0,0,0,0,-1,-1,-1,-1,0,0,0,1,1,1,1,1,0,0,0,-1,-1,-1,-1,0,0,0,0,1,1,1,1,1,0,0,0,-1,-1},
    bob = 3, wisp = { {-10,4,-0.12,5},{0,6,0.10,6},{10,4,0.30,4} } },
  { lean = {0,0,1,1,1,1,0,0,0,-1,-1,-1,-1,-1,0,0,0,1,1,1,1,0,0,0,0,-1,-1,-1,-1,0,0,0,1,1,1,1,1,0,0,0,-1,-1,-1,0,0,0},
    bob = 0, wisp = { {-11,8,0.10,6},{-1,6,0.26,6},{9,9,0.40,5} } },
}

local spr, img = L.newStrip(N, SIDE)
local function put(ox,x,y,c)
  if x>=0 and x<SIDE and y>=0 and y<SIDE then img:drawPixel(ox+x,y,C[c]) end
end
local function has(ox,x,y)
  if x<0 or x>=SIDE or y<0 or y>=SIDE then return false end
  return img:getPixel(ox+x,y) ~= L.CLEAR
end
local function putIn(ox,x,y,c) if has(ox,x,y) then put(ox,x,y,c) end end

local function shadeStep(lam)
  for i = 1, #THR do if lam >= THR[i] then return i end end
  return #RAMP
end

-- 자락 한 가닥 (아래로 갈수록 가늘어지고 끝이 흩어진다)
local function wisp(ox, x0, y0, len, curve, w0)
  local x = x0
  for i = 0, len-1 do
    local t = i/len
    x = x + curve
    local w = math.max(1, math.floor(w0*(1 - t*t*0.8) + 0.5))
    local xi = math.floor(x+0.5)
    for k = 0, w-1 do
      local px = xi - math.floor(w/2) + k
      local col
      if k == 0 and w > 2 then col = "a8b5b2"
      elseif k == w-1 and w > 1 then col = "4e5259"
      elseif t > 0.65 then col = "577277" else col = "819796" end
      put(ox, px, y0+i, col)
    end
  end
  local xe = math.floor(x + curve*3 + 0.5)
  put(ox, xe, y0+len+1, "577277"); put(ox, xe+1, y0+len+1, "4e5259")
  put(ox, xe, y0+len+2, "394a50")
end

for f = 1, N do
  local o  = FR[f]
  local ox = (f-1)*SIDE
  local cx = 32
  local nt = {}
  for _, n in ipairs(NOTCH[f]) do nt[n[1]] = n end

  -- 자락 먼저 (몸 아래로 깔린다)
  for _, s in ipairs(o.wisp) do wisp(ox, cx + s[1], 51 + o.bob, math.min(s[2],4), s[3], s[4]) end

  for i, p in ipairs(PROF) do
    local y = TOPY + i - 1 + o.bob
    local lean = o.lean[i] or 0
    local lw, rw = p[1], p[2]
    local n = nt[i]
    if n then if n[2] == "L" then lw = lw - n[3] else rw = rw - n[3] end end
    local t = (i-1) / #PROF
    for x = -lw, rw do
      local half = (x < 0) and lw or rw
      local nx = x / math.max(half, 1)
      local nz = math.sqrt(math.max(0, 1 - nx*nx))
      local lam = nx*(-0.44) + nz*0.66            -- 세로 원기둥 음영 (2회차보다 낮춘다)
      lam = lam + 0.46 - 0.30*t                   -- 머리는 빛을 받고 자락은 가라앉는다
      if i >= 7 and i <= 21 and math.abs(x) < 11 then lam = lam - 0.32 end  -- 두건 속 그늘
      if i > 40 then lam = lam - (i-40)*0.05 end                            -- 밑단이 풀린다
      local px = cx + x + lean
      -- 🔴 가장자리는 검은 선이 아니라 명도로만. 그늘 쪽을 +2 하면 1px 검은 띠가 생겨
      --    「그림자 스티커」가 된다(2회차 결함) — +1 하고 중간 회색에서 멈춘다.
      local step = math.min(shadeStep(lam), 6)   -- 몸 안쪽은 중간 회색에서 멈춘다
      if x == -lw then step = math.max(1, step - 1)
      elseif x == rw then step = math.min(8, step + 2) end   -- 가장 바깥 한 줄만 더 내려간다
      put(ox, px, y, RAMP[step])
    end
  end

  -- 밑단을 2~3px 덩어리로 끊는다 (실체 없음 — 1px 노이즈는 금지라 덩어리로)
  local CUT = { {43,-14,3},{44,-6,4},{44,9,3},{45,-19,4},{45,2,5},{45,14,4},
                {46,-16,5},{46,-3,4},{46,9,5},{47,-12,6},{47,4,7},{47,-20,3},
                {48,-17,5},{48,-5,7},{48,7,5},{49,-13,6},{49,2,8},
                {50,-10,7},{50,4,7},{51,-8,9},{51,5,6},{52,-6,11} }
  for _, c in ipairs(CUT) do
    local y = TOPY + c[1] - 1 + o.bob + ((f-1) % 2)
    for k = 0, c[3]-1 do
      local px = cx + c[2] + k + (f-1)*2 - 3
      if has(ox, px, y) then img:drawPixel(ox+px, y, L.CLEAR) end
    end
  end

  -- 밑단 정리: 이웃이 둘 미만인 픽셀은 지운다 (자글자글한 1px 노이즈 금지 — ART_SPEC §3-5)
  local kill = {}
  for y = 0, SIDE-1 do
    for x = 0, SIDE-1 do
      if has(ox,x,y) then
        local n = 0
        if has(ox,x-1,y) then n=n+1 end
        if has(ox,x+1,y) then n=n+1 end
        if has(ox,x,y-1) then n=n+1 end
        if has(ox,x,y+1) then n=n+1 end
        if n < 2 then kill[#kill+1] = {x,y} end
      end
    end
  end
  for _, k in ipairs(kill) do img:drawPixel(ox+k[1], k[2], L.CLEAR) end

  -- ── 삼킨 문양: 형체 없는 몸에서 유일하게 단단한 것 ──────────────────
  local gx, gy = cx - 1, 33 + o.bob
  local gsh = { 0, 26, -20, 44 }
  local pts = {}
  local function ring(rad, th, g0, g1)
    local ryo = rad*0.86
    for y = -math.ceil(ryo), math.ceil(ryo) do
      local t = y/ryo
      if math.abs(t) <= 1 then
        local xo = rad*math.sqrt(1-t*t)
        local ri, ryi = rad-th, (rad-th)*0.86
        local ti = (ryi>0) and (y/ryi) or 2
        local xi = (math.abs(ti)<1) and ri*math.sqrt(1-ti*ti) or 0
        for x = -math.floor(xo), math.floor(xo) do
          if math.abs(x) >= xi-0.5 then
            local a = math.deg(math.atan(y/0.86, x)) % 360
            local inGap
            if g0 < g1 then inGap = (a >= g0 and a <= g1) else inGap = (a >= g0 or a <= g1) end
            if not inGap then pts[#pts+1] = {gx+x, gy+y, a} end
          end
        end
      end
    end
  end
  ring(9, 2, (298+gsh[f])%360, (346+gsh[f])%360)
  ring(4, 1, (118+gsh[f])%360, (204+gsh[f])%360)
  for _, s in ipairs({ {186,4,2}, {250,3,1}, {98,5,2} }) do
    for t = 1, s[2] do for k = 0, s[3]-1 do
      local ar = math.rad(s[1] + k*7)
      pts[#pts+1] = { gx + math.floor((9+t)*math.cos(ar)+0.5),
                      gy + math.floor((9+t)*math.sin(ar)*0.86+0.5), s[1] }
    end end
  end
  for _, p in ipairs(pts) do putIn(ox, p[1]+1, p[2]+1, "2f6152") end
  for _, p in ipairs(pts) do
    local col = "c8f5ee"
    if p[3] > 40 and p[3] < 150 then col = "3fa9a0" elseif p[3] > 195 and p[3] < 258 then col = "f7f7f2" end
    putIn(ox, p[1], p[2], col)
  end

  -- ── 얼굴: 두건 그늘 속 구멍 둘 + 그 안의 찬 빛 ──────────────────────
  local EYE = L.legend({ d="202e37", k="151d28", c="73bed3", C="c8f5ee", W="f7f7f2", a="2a2c32" })
  local E_L = { {1,"aadd."}, {0,"adkkkd"}, {0,"adkWCCk"}, {0,"adkCCck"}, {1,"adkcckd"}, {2,"addkd"}, {3,"add"} }
  local E_R = { {1,"add."}, {0,"adkkd"}, {0,"adkWCk"}, {0,"adkCck"}, {1,"adkckd"}, {2,"addk"}, {3,"ad"} }
  local eyY = TOPY + 9 + o.bob
  L.blit(img, E_L, ox + cx - 11, eyY, EYE)
  L.blit(img, E_R, ox + cx + 3,  eyY + 1, EYE)

  print(string.format("f%d %s", f-1, L.bbox(img, ox, SIDE)))
end

print("colors=" .. L.colorCount(img))
L.finish(spr, img, OUT .. "mist.png")
print("saved")
