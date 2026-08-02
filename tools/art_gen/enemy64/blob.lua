-- 구체 음영 밑그림기 — 「형태를 이해한 자리」에 명암을 붙이기 위한 착수점.
-- 손으로 쓴 각도별 반경 흔들림 표(wob)가 실루엣을 정하고, 램버트 항이 명암 띠를 만든다.
local B = {}

local function clamp(v,a,b) if v<a then return a elseif v>b then return b else return v end end

-- wob = 12개 제어값(각도 0=오른쪽, 반시계). 부드럽게 보간해 반경 배수를 낸다.
local function wobAt(wob, th)
  local n = #wob
  local t = (th % (2*math.pi)) / (2*math.pi) * n
  local i = math.floor(t); local f = t - i
  local a = wob[(i % n) + 1]; local b = wob[((i+1) % n) + 1]
  local s = f*f*(3-2*f)                 -- smoothstep
  return a + (b-a)*s
end

-- opts: cx,cy,rx,ryTop,ryBot,wob, ramp(밝은->어두운 배열), thresholds, light{x,y,z},
--       sss(밑에서 비쳐오는 양), ground(바닥 y, 그 아래는 자름)
-- 반환: mask[y][x]=단계번호(1..#ramp), 없으면 nil
function B.field(w, h, o)
  local mask = {}
  for y = 0, h-1 do mask[y] = {} end
  local lx, ly, lz = o.light[1], o.light[2], o.light[3]
  local ln = math.sqrt(lx*lx+ly*ly+lz*lz); lx,ly,lz = lx/ln, ly/ln, lz/ln
  for y = 0, h-1 do
    if not (o.ground and y > o.ground) then
      for x = 0, w-1 do
        local dx = (x + 0.5) - o.cx
        local dy = (y + 0.5) - o.cy
        local ry = (dy < 0) and o.ryTop or o.ryBot
        local nx = dx / o.rx
        local ny = dy / ry
        local th = math.atan(dy, dx)
        local wr = wobAt(o.wob, th)
        local d = math.sqrt(nx*nx + ny*ny) / wr
        if d <= 1.0 then
          -- 구면 법선 (평면 원판이 아니라 부피로 읽히게)
          local sx, sy = nx/wr, ny/wr
          local q = 1.0 - sx*sx - sy*sy
          local nz = math.sqrt(math.max(q, 0.0))
          local lam = sx*lx + sy*ly + nz*lz
          -- 🔴 명암 경계를 손으로 깨뜨린다 — 안 그러면 띠가 실루엣의 오프셋 복사가 된다.
          -- lamWob = 각도별 가감 표(내가 고른 값). 반경 방향으로도 약하게 실어 안쪽까지 흔든다.
          if o.lamWob then
            lam = lam + wobAt(o.lamWob, th) * (0.45 + 0.55*d)
          end
          -- 코어 섀도(터미네이터 바로 뒤가 가장 어둡고, 그 너머는 반사광으로 다시 든다)
          if o.core and lam < o.core[1] then
            local t2 = (o.core[1] - lam) / 0.5
            if t2 > 1 then t2 = 2 - t2 end
            lam = lam - o.core[2] * math.max(t2, 0)
          end
          -- 아래쪽 투과광 (젤리 느낌 — 바닥 가까이가 밝아진다)
          if o.sss and o.sss > 0 then
            local below = clamp((sy + 0.15) / 1.15, 0, 1)
            lam = lam + o.sss * below * below * (0.35 + 0.65*d)
          end
          -- 가장자리 반사(바닥 반사광) — 오른아래 테두리만
          if o.rim and d > 0.86 and sy > -0.1 and sx > -0.2 then
            lam = lam + o.rim * (d-0.86)/0.14
          end
          local step = #o.ramp
          for i = 1, #o.thr do
            if lam >= o.thr[i] then step = i; break end
          end
          mask[y][x] = step
        end
      end
    end
  end
  return mask
end

-- 외곽선: 안쪽이면서 바깥 이웃이 있는 픽셀. 방향에 따라 색이 갈리고, 그늘 쪽만 두꺼워진다.
-- outline = { up=색단계, side=..., down=... } (ramp 인덱스 대신 별도 색 테이블 인덱스)
function B.outline(mask, w, h, o)
  local ol = {}
  for y = 0, h-1 do ol[y] = {} end
  local function inside(x,y)
    if x<0 or y<0 or x>=w or y>=h then return false end
    return mask[y][x] ~= nil
  end
  for y = 0, h-1 do
    for x = 0, w-1 do
      if mask[y][x] then
        if not (inside(x-1,y) and inside(x+1,y) and inside(x,y-1) and inside(x,y+1)) then
          local dx = (x+0.5) - o.cx
          local dy = (y+0.5) - o.cy
          local th = math.atan(dy, dx)      -- -pi..pi, 아래가 +
          local k
          if dy < -0.25*o.ryTop and dx < 0.35*o.rx then k = "up"
          elseif dy > 0.35*o.ryBot then k = "down"
          else k = "side" end
          ol[y][x] = k
        end
      end
    end
  end
  -- 그늘 쪽(아래·오른쪽) 2px 두께
  local add = {}
  for y = 0, h-1 do
    for x = 0, w-1 do
      if ol[y][x] == "down" or (ol[y][x] == "side" and (x+0.5) > o.cx) then
        local dx = (x+0.5) - o.cx; local dy = (y+0.5) - o.cy
        local L = math.sqrt(dx*dx+dy*dy); if L < 1 then L = 1 end
        local ix = x - math.floor(dx/L + 0.5)
        local iy = y - math.floor(dy/L + 0.5)
        if iy>=0 and iy<h and ix>=0 and ix<w and mask[iy][ix] and not ol[iy][ix] then
          add[#add+1] = {ix, iy, ol[y][x]}
        end
      end
    end
  end
  for _, a in ipairs(add) do ol[a[2]][a[1]] = a[3] end
  return ol
end

-- ── 캡슐(메타볼) 몸통 ────────────────────────────────────────────────
-- 네 발 짐승은 구체 하나로 안 된다. 「굵기가 있는 뼈대」 여럿을 부드럽게 이어
-- 부피 높이 z를 만들고, 그 기울기에서 법선을 뽑아 음영을 준다.
-- parts = { {x1,y1,r1, x2,y2,r2}, ... }
local function heightAt(parts, x, y)
  local best = 0
  for _, p in ipairs(parts) do
    local ax, ay, ar = p[1], p[2], p[3]
    local bx, by, br = p[4], p[5], p[6]
    local dx, dy = bx-ax, by-ay
    local L2 = dx*dx + dy*dy
    local t = 0
    if L2 > 0 then
      t = ((x-ax)*dx + (y-ay)*dy) / L2
      if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local px, py = ax + dx*t, ay + dy*t
    local r = ar + (br-ar)*t
    local d2 = (x-px)^2 + (y-py)^2
    if d2 < r*r then
      local z = math.sqrt(r*r - d2)
      if z > best then best = z end
    end
  end
  return best
end

-- o: parts, ramp, thr, light, lamWob(선택), amb
function B.capsule(w, h, o)
  local mask, ht = {}, {}
  for y = 0, h-1 do mask[y] = {}; ht[y] = {} end
  local lx, ly, lz = o.light[1], o.light[2], o.light[3]
  local ln = math.sqrt(lx*lx+ly*ly+lz*lz); lx,ly,lz = lx/ln, ly/ln, lz/ln
  for y = 0, h-1 do
    for x = 0, w-1 do
      ht[y][x] = heightAt(o.parts, x+0.5, y+0.5)
    end
  end
  for y = 0, h-1 do
    for x = 0, w-1 do
      local z = ht[y][x]
      if z > 0 then
        local zl = (x > 0) and ht[y][x-1] or 0
        local zr = (x < w-1) and ht[y][x+1] or 0
        local zu = (y > 0) and ht[y-1][x] or 0
        local zd = (y < h-1) and ht[y+1][x] or 0
        local nx, ny = (zl - zr) * 0.5, (zu - zd) * 0.5
        local nn = math.sqrt(nx*nx + ny*ny + 1)
        nx, ny = nx/nn, ny/nn
        local nz = 1/nn
        local lam = nx*lx + ny*ly + nz*lz
        if o.lamWob then
          local th = math.atan(ny, nx)
          local n = #o.lamWob
          local t = (th % (2*math.pi)) / (2*math.pi) * n
          local i = math.floor(t); local fr = t - i
          local a = o.lamWob[(i % n)+1]; local b = o.lamWob[((i+1) % n)+1]
          lam = lam + a + (b-a)*(fr*fr*(3-2*fr))
        end
        lam = lam + (o.amb or 0)
        local step = #o.ramp
        for i = 1, #o.thr do
          if lam >= o.thr[i] then step = i; break end
        end
        mask[y][x] = step
      end
    end
  end
  return mask, ht
end

return B
