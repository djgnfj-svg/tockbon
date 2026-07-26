local D="C:/Users/djgnf/AppData/Local/Temp/claude/C--Users-djgnf-Desktop-godot-games-tockbon/939edd37-7064-46c1-bf48-323835a64c94/scratchpad/"
dofile(D.."lib.lua") dofile(D.."ruinlib.lua")

-- 기념비 잔해 — 옛 마을의 증거.  original: gilt ring x32..64 y10..42 floating
-- over a plinth x38..58 y50..64 on a two-step base, ground y84.
-- the ring is the memory: it has come down and leans, broken, against the stump.
newcv(96,96)
local STONE={RD,R1,R2,R3,R4}
local GOLD={C("#3c3935"),AU0,AU1,AU2,C("#bdb4a4")}
local GRND=84

-- ── two-step base, chipped ──────────────────────────────────────────────
for y=74,GRND do for x=12,84 do
  local l=12+math.floor((GRND-y)*0.15) local r=84-math.floor((GRND-y)*0.15)
  if x>=l and x<=r then
    local c=R2
    if y<=75 then c=R3 end
    if x<=l+1 then c=R3 end
    if x>=r-2 then c=R1 end
    if y>=GRND-1 then c=R1 end
    put(x,y,c)
  end
end end
for y=64,74 do for x=20,76 do
  local c=R2
  if y<=65 then c=R3 end
  if x<=21 then c=R3 end
  if x>=74 then c=R1 end
  put(x,y,c)
end end
-- a corner knocked clean off
for y=64,76 do for x=62,80 do
  if (x-62)+(76-y)>18 then IMG:putPixel(x,y,0) end
end end
for y=64,76 do for x=60,80 do
  if alphaAt(x,y)>0 and alphaAt(x+1,y-1)==0 and x>58 then put(x,y,R3) end
end end
hl(20,76,64,R3) hl(20,62,64,R4)
for y=68,72,4 do hl(22,60,y,R1) end
crack({{30,64},{27,70},{31,74}},R1)
crack({{50,74},{47,79},{52,GRND}},R1)

-- ── the plinth, snapped at half height ──────────────────────────────────
for y=40,66 do for x=50,66 do
  local cut=40+chunk(x,19.0,3,5)
  if y>=cut then
    local c=R2
    if x<=51 then c=R3 end
    if x>=64 then c=R1 end
    put(x,y,c)
    if y<=cut+1 then put(x,y,R3) end
  end
end end
for y=50,62,11 do hl(50,66,y,R1) end
crack({{56,48},{59,56},{57,66}},R1)

-- ── the ring: down, broken where it struck, leaning on the stump ────────
local rcx,rcy,rrx,rry,th=34,42,20,21,3.6
local function brokenA(a) return a>24 and a<86 end     -- the quarter that shattered
for y=rcy-rry-4,rcy+rry+4 do for x=rcx-rrx-10,rcx+rrx+10 do
  local sx=x-(y-rcy)*0.26                       -- shear: it leans
  local d=math.sqrt(((sx-rcx)/rrx)^2+((y-rcy)/rry)^2)
  if d>=1-th/rrx and d<=1+th/rrx then
    local a=math.deg(math.atan(y-rcy,sx-rcx)) if a<0 then a=a+360 end
    if not brokenA(a) then
      local t=((sx-rcx)*-0.7071+(y-rcy)*-0.7071)/rrx
      local c=GOLD[3]
      if t>0.30 then c=GOLD[4] end
      if t>0.72 then c=GOLD[5] end
      if t<-0.35 then c=GOLD[2] end
      if d>1+ (th-1.2)/rrx then c=GOLD[1] end   -- outer edge in shade
      put(x,y,c)
    end
  end
end end
-- fresh cross-sections at the two break ends
for _,a in ipairs({24,86}) do
  local r=math.rad(a)
  local x0=rcx+math.cos(r)*(rrx-th) local y0=rcy+math.sin(r)*(rry-th)
  local x1=rcx+math.cos(r)*(rrx+th) local y1=rcy+math.sin(r)*(rry+th)
  line(x0+(y0-rcy)*0.26,y0,x1+(y1-rcy)*0.26,y1,GOLD[5],1)
end
-- where it bit into the stone when it landed
rubble(34,68,9,3,STONE,37.0,6)

-- ── an arc that snapped off, lying flat on the base ─────────────────────
for y=66,80 do for x=56,88 do
  local d=math.sqrt(((x-72)/14)^2+((y-75)/6.2)^2)
  if d>=0.54 and d<=1.0 then
    local a=math.deg(math.atan(y-75,x-72)) if a<0 then a=a+360 end
    if a>182 and a<352 then
      local c=GOLD[4]
      if y<73 then c=GOLD[5] end
      if y>76 then c=GOLD[2] end
      put(x,y,c)
    end
  end
end end

-- ── moss and grit where nobody has swept in a long time ─────────────────
for _,p in ipairs({{16,78,8,3},{68,80,10,3},{34,72,9,2}}) do
  for y=p[2],p[2]+p[4] do for x=p[1],p[1]+p[3] do
    if alphaAt(x,y)>0 and prand(x*2.1+y*4.7)<0.5 then put(x,y,AG1) end end end
end
weather(12,50,84,GRND,STONE,13.0,0.028)
rubble(18,GRND,10,4,STONE,43.0,7)
rubble(80,GRND,9,4,STONE,51.0,6)

outline(ROL)
groundshadow(48,GRND+5,44,7)
satguard(0.11,262)
finish("monument_circle_ruin")
