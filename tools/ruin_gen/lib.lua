-- shared drawing helpers for the ruin + gate sprites
SP="C:/Users/djgnf/AppData/Local/Temp/claude/C--Users-djgnf-Desktop-godot-games-tockbon/939edd37-7064-46c1-bf48-323835a64c94/scratchpad/"
OUT="C:/Users/djgnf/Desktop/godot_games/tockbon/assets/sprites/base/"
PC=app.pixelColor

function hx(s) return tonumber(s:sub(2,3),16),tonumber(s:sub(4,5),16),tonumber(s:sub(6,7),16) end
function C(s) local r,g,b=hx(s) return {r,g,b} end
function mixc(a,b,t) return {a[1]+(b[1]-a[1])*t, a[2]+(b[2]-a[2])*t, a[3]+(b[3]-a[3])*t} end

-- ── canvas ────────────────────────────────────────────────────────────────
function newcv(w,h) W,H=w,h IMG=Image(w,h,ColorMode.RGB) end
function get(x,y)
  if x<0 or y<0 or x>=W or y>=H then return 0,0,0,0 end
  local p=IMG:getPixel(x,y) return PC.rgbaR(p),PC.rgbaG(p),PC.rgbaB(p),PC.rgbaA(p)
end
function alphaAt(x,y) local _,_,_,a=get(x,y) return a end
function put(x,y,c,a)
  if x<0 or y<0 or x>=W or y>=H then return end
  a=a or 255
  IMG:putPixel(x,y,PC.rgba(math.floor(c[1]+.5),math.floor(c[2]+.5),math.floor(c[3]+.5),math.floor(a+.5)))
end
-- blend colour c over what is already there, keeping existing alpha
function tint(x,y,c,w)
  local r,g,b,a=get(x,y) if a==0 then return end
  local n=mixc({r,g,b},c,w) put(x,y,n,a)
end

-- ── primitives ────────────────────────────────────────────────────────────
function rect(x0,y0,x1,y1,c,a)
  if x0>x1 then x0,x1=x1,x0 end if y0>y1 then y0,y1=y1,y0 end
  for y=y0,y1 do for x=x0,x1 do put(x,y,c,a) end end
end
function hl(x0,x1,y,c,a) if x0>x1 then x0,x1=x1,x0 end for x=x0,x1 do put(x,y,c,a) end end
function vl(x,y0,y1,c,a) if y0>y1 then y0,y1=y1,y0 end for y=y0,y1 do put(x,y,c,a) end end
function ell(cx,cy,rx,ry,c,a)
  for y=math.floor(cy-ry),math.ceil(cy+ry) do for x=math.floor(cx-rx),math.ceil(cx+rx) do
    if ((x-cx)/rx)^2+((y-cy)/ry)^2<=1.0 then put(x,y,c,a) end end end
end
function ring(cx,cy,r0,r1,c,a)
  for y=math.floor(cy-r1),math.ceil(cy+r1) do for x=math.floor(cx-r1),math.ceil(cx+r1) do
    local d=math.sqrt((x-cx)^2+(y-cy)^2)
    if d>=r0 and d<=r1 then put(x,y,c,a) end end end
end
-- filled convex/simple polygon, scanline
function poly(pts,c,a)
  local ymin,ymax=1e9,-1e9
  for _,p in ipairs(pts) do ymin=math.min(ymin,p[2]) ymax=math.max(ymax,p[2]) end
  for y=math.floor(ymin),math.ceil(ymax) do
    local xs={}
    for i=1,#pts do
      local p1,p2=pts[i],pts[(i%#pts)+1]
      local y1,y2=p1[2],p2[2]
      if (y1<=y and y2>y) or (y2<=y and y1>y) then
        xs[#xs+1]=p1[1]+(y-y1)/(y2-y1)*(p2[1]-p1[1])
      end
    end
    table.sort(xs)
    for i=1,#xs-1,2 do
      for x=math.floor(xs[i]+.5),math.floor(xs[i+1]+.5) do put(x,y,c,a) end
    end
  end
end
-- thick line
function line(x0,y0,x1,y1,c,t,a)
  t=t or 1
  local n=math.max(math.abs(x1-x0),math.abs(y1-y0))
  if n==0 then n=1 end
  for i=0,n do
    local x=x0+(x1-x0)*i/n local y=y0+(y1-y0)*i/n
    for dy=-(t-1),(t-1) do for dx=-(t-1),(t-1) do
      if dx*dx+dy*dy<=(t-1)*(t-1)+0.3 then put(math.floor(x+.5)+dx,math.floor(y+.5)+dy,c,a) end
    end end
  end
end

-- ── outline: paint 1px border around every opaque island ──────────────────
function outline(c)
  local marks={}
  local N4={{1,0},{-1,0},{0,1},{0,-1}}
  for y=0,H-1 do for x=0,W-1 do
    if alphaAt(x,y)>=250 then
      for _,d in ipairs(N4) do
        local nx,ny=x+d[1],y+d[2]
        if nx>=0 and ny>=0 and nx<W and ny<H and alphaAt(nx,ny)<250 then marks[#marks+1]={nx,ny} end
      end
    end
  end end
  for _,m in ipairs(marks) do put(m[1],m[2],c,255) end
end

-- ── baked ground shadow, matching the rest of the set (#090a14 @ a90) ─────
function groundshadow(cx,cy,rx,ry)
  local sc=C("#090a14")
  for y=math.floor(cy-ry),math.ceil(cy+ry) do for x=math.floor(cx-rx),math.ceil(cx+rx) do
    if ((x-cx)/rx)^2+((y-cy)/ry)^2<=1.0 and alphaAt(x,y)==0 then put(x,y,sc,90) end
  end end
end

-- ── saturation guard ──────────────────────────────────────────────────────
-- relight's shade() rewrites s<0.06 to hue 250 on the shaded bands only — that is what
-- makes a grey sprite two-faced.  Opposed hues cancel to near-grey, so sweep before saving.
function rgb2hsv(r,g,b)
  r,g,b=r/255,g/255,b/255
  local mx,mn=math.max(r,g,b),math.min(r,g,b) local d=mx-mn local h=0
  if d>0 then
    if mx==r then h=((g-b)/d)%6 elseif mx==g then h=(b-r)/d+2 else h=(r-g)/d+4 end
    h=h*60
  end
  return h,(mx==0 and 0 or d/mx),mx
end
function hsv2rgb(h,s,v)
  h=h%360 local c=v*s local x=c*(1-math.abs((h/60)%2-1)) local m=v-c
  local r,g,b=0,0,0
  if h<60 then r,g,b=c,x,0 elseif h<120 then r,g,b=x,c,0 elseif h<180 then r,g,b=0,c,x
  elseif h<240 then r,g,b=0,x,c elseif h<300 then r,g,b=x,0,c else r,g,b=c,0,x end
  return {(r+m)*255,(g+m)*255,(b+m)*255}
end
function satguard(minS,fallbackHue)
  minS=minS or 0.11 fallbackHue=fallbackHue or 262
  local n=0
  for y=0,H-1 do for x=0,W-1 do
    local r,g,b,a=get(x,y)
    if a>0 then
      local h,s,v=rgb2hsv(r,g,b)
      if s<minS then
        if s<0.035 then h=fallbackHue end   -- hue is just noise down here
        put(x,y,hsv2rgb(h,minS,v),a) n=n+1
      end
    end
  end end
  print("   satguard raised "..n.." px to s="..minS)
end

-- ── save ──────────────────────────────────────────────────────────────────
function finish(name)
  local spr=Sprite(W,H,ColorMode.RGB)
  local cel=spr.layers[1]:cel(1)
  cel.image=IMG cel.position=Point(0,0)
  spr:saveAs(SP..name..".aseprite")
  spr:saveCopyAs(OUT..name..".png")
  spr:close()
  print("saved "..name.." "..W.."x"..H)
end

-- ── palettes ──────────────────────────────────────────────────────────────
-- ruin structural ramp: hue 262 deg, s 0.10~0.18 (relight-safe grey-violet)
RD=C("#1b191f")  -- v .12 s .18   void / holes
R0=C("#322f38")  -- v .22 s .17
R1=C("#494552")  -- v .32 s .16
R2=C("#696373")  -- v .45 s .14   main stone
R3=C("#898294")  -- v .58 s .12
R4=C("#a7a1b3")  -- v .70 s .10
ROL=C("#16131c") -- outline, violet-black (s .32)
-- per-building memory accents, same low-sat band, hue shifted
AG0=C("#404d43") AG1=C("#5f7064") AG2=C("#7e9183")   -- alchemy  h135 s.13~.17
AW0=C("#4d453f") AW1=C("#70675e") AW2=C("#94897f")   -- workshop h28  s.14~.18
AM0=C("#524343") AM1=C("#756363") AM2=C("#998484")   -- market   h358 s.14~.18
AU0=C("#575347") AU1=C("#807a6b") AU2=C("#a39e8c")   -- monument h45  s.14~.18
