-- 탁본 적 스프라이트 공용 라이브러리 (TAKBON 60 팔레트만)
-- 밑그림 blit 도구. 실제 그림은 각 종 스크립트의 ASCII 맵이 쥔다.
local M = {}

-- TAKBON 60 (assets/aseprite/takbon.gpl) — 여기 없는 색은 쓰지 마라
M.PAL = {
  ["172038"]=1,["253a5e"]=1,["3c5e8b"]=1,["4f8fba"]=1,["73bed3"]=1,["a4dddb"]=1,
  ["19332d"]=1,["25562e"]=1,["468232"]=1,["75a743"]=1,["a8ca58"]=1,["d0da91"]=1,
  ["4d2b32"]=1,["7a4841"]=1,["ad7757"]=1,["c09473"]=1,["d7b594"]=1,["e7d5b3"]=1,
  ["341c27"]=1,["602c2c"]=1,["884b2b"]=1,["be772b"]=1,["de9e41"]=1,["e8c170"]=1,
  ["241527"]=1,["411d31"]=1,["752438"]=1,["a53030"]=1,["cf573c"]=1,["da863e"]=1,
  ["1e1d39"]=1,["402751"]=1,["7a367b"]=1,["a23e8c"]=1,["c65197"]=1,["df84a5"]=1,
  ["090a14"]=1,["10141f"]=1,["151d28"]=1,["202e37"]=1,["394a50"]=1,["577277"]=1,
  ["819796"]=1,["a8b5b2"]=1,["c7cfcc"]=1,["ebede9"]=1,
  ["16281c"]=1,["2f6152"]=1,["7a8c2e"]=1,["c9962e"]=1,["f2cb3f"]=1,["fbefa8"]=1,
  ["2a2c32"]=1,["4e5259"]=1,["2e1f18"]=1,["8b5fbf"]=1,["e0a3e8"]=1,["3fa9a0"]=1,
  ["c8f5ee"]=1,["f7f7f2"]=1,
}

function M.hex(h)
  assert(M.PAL[string.lower(h)], "PALETTE VIOLATION: " .. h)
  local r = tonumber(string.sub(h,1,2),16)
  local g = tonumber(string.sub(h,3,4),16)
  local b = tonumber(string.sub(h,5,6),16)
  return app.pixelColor.rgba(r,g,b,255)
end

-- 범례(문자 -> hex) -> 문자 -> 패킹된 색
function M.legend(t)
  local out = {}
  for k,v in pairs(t) do out[k] = M.hex(v) end
  return out
end

M.CLEAR = app.pixelColor.rgba(0,0,0,0)

-- rows = { {u_start, "chars"}, ... }  index i -> v = i-1
-- '.' = 건드리지 않음(투명 유지 / 아래 층 보존)
function M.blit(img, rows, ox, oy, leg)
  for i, row in ipairs(rows) do
    local u0, s = row[1], row[2]
    local v = oy + i - 1
    for j = 1, #s do
      local c = string.sub(s, j, j)
      if c ~= "." then
        local col = leg[c]
        assert(col, "unknown legend char: '" .. c .. "' row " .. i)
        local x, y = ox + u0 + j - 1, v
        if x >= 0 and y >= 0 and x < img.width and y < img.height then
          img:drawPixel(x, y, col)
        end
      end
    end
  end
end

-- 좌우 미러 (문자열 뒤집기 + 조명 문자 스왑)
function M.mirror(rows, width, swap)
  local out = {}
  for i, row in ipairs(rows) do
    local u0, s = row[1], row[2]
    local r = string.reverse(s)
    if swap then
      local t = {}
      for j = 1, #r do
        local c = string.sub(r,j,j)
        t[j] = swap[c] or c
      end
      r = table.concat(t)
    end
    out[i] = { width - (u0 + #s), r }
  end
  return out
end

-- 실루엣 bbox 측정 (검산용)
function M.bbox(img, fx, fw)
  local x0, y0, x1, y1 = 9999, 9999, -1, -1
  for y = 0, img.height-1 do
    for x = fx, fx+fw-1 do
      local p = img:getPixel(x,y)
      if app.pixelColor.rgbaA(p) > 0 then
        if x < x0 then x0 = x end
        if x > x1 then x1 = x end
        if y < y0 then y0 = y end
        if y > y1 then y1 = y end
      end
    end
  end
  if x1 < 0 then return "EMPTY" end
  return string.format("w=%d h=%d  x[%d..%d] y[%d..%d]", x1-x0+1, y1-y0+1, x0-fx, x1-fx, y0, y1)
end

function M.colorCount(img)
  local seen, n = {}, 0
  for y = 0, img.height-1 do
    for x = 0, img.width-1 do
      local p = img:getPixel(x,y)
      if app.pixelColor.rgbaA(p) > 0 then
        if not seen[p] then seen[p] = true; n = n + 1 end
      end
    end
  end
  return n
end

function M.newStrip(frames, side)
  local spr = Sprite(frames*side, side, ColorMode.RGB)
  local img = Image(frames*side, side, ColorMode.RGB)
  img:clear(M.CLEAR)
  return spr, img
end

function M.finish(spr, img, path)
  spr.cels[1].image = img
  spr.cels[1].position = Point(0,0)
  spr:saveAs(path)
end

return M
