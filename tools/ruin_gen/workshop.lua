local D="C:/Users/djgnf/AppData/Local/Temp/claude/C--Users-djgnf-Desktop-godot-games-tockbon/939edd37-7064-46c1-bf48-323835a64c94/scratchpad/"
dofile(D.."lib.lua") dofile(D.."ruinlib.lua")

-- 공방(마도구 공방) 잔해.  original: stone body x18..111 y78..147, half-timber
-- upper storey, brown shingle hip roof y33..75, brick chimney x81..90 y15..33.
newcv(128,160)
local STONE={RD,R1,R2,R3,R4}
local WOOD={C("#332e29"),AW0,AW1,AW2,C("#a89c92")}
local GRND=147

-- ── stone lower storey, still standing as a hollow shell ─────────────────
local function topf(x)
  if x<40 then return 116-(x-18)*0.55
  elseif x<68 then return 100
  elseif x<=111 then return 93 end
  return 93
end
brokenwall(18,111,GRND,topf,STONE,5.0)

-- ── half-timber upper storey: one gable fragment left standing ───────────
local gx0,gx1,gy0,gy1=68,111,66,94
for y=gy0,gy1 do for x=gx0,gx1 do
  -- broken left edge: a diagonal shear
  local lim=68+math.floor((gy1-y)*0.62)+chunk(y,13.0,4,2)
  local topcut=gy0+chunk(x,17.0,5,3)
  if x>=lim and y>=topcut then put(x,y,WOOD[3]) end
end end
-- plaster panels lighter, timber frame darker
for y=gy0,gy1 do for x=gx0,gx1 do
  if alphaAt(x,y)>0 and y>=gy0 then
    local t=((x-90)*-0.7071+(y-80)*-0.7071)/26
    if t>0.10 then put(x,y,WOOD[4]) end
  end
end end
local function post(x,y0,y1) for y=y0,y1 do for xx=x,x+2 do
  if alphaAt(xx,y)>0 then put(xx,y,WOOD[2]) end end
  if alphaAt(x,y)>0 then put(x,y,WOOD[3]) end end end
local function rail(y,x0,x1) for x=x0,x1 do for yy=y,y+2 do
  if alphaAt(x,yy)>0 then put(x,yy,WOOD[2]) end end
  if alphaAt(x,y)>0 then put(x,y,WOOD[3]) end end end
post(72,gy0,gy1) post(88,gy0,gy1) post(104,gy0,gy1)
rail(gy1-2,gx0,gx1) rail(78,gx0,gx1)
-- the diagonal brace that says "half-timbered"
beam(74,gy1-3,88,68,2,WOOD)
-- panels that fell out
for _,p in ipairs({{92,68,11,8},{76,82,10,9}}) do
  for y=p[2],p[2]+p[4] do for x=p[1],p[1]+p[3] do
    if alphaAt(x,y)>0 then put(x,y,RD) end end end
end
-- empty window in the gable
rect(93,82,105,92,RD)
rect(93,82,105,83,WOOD[2]) rect(93,91,105,92,WOOD[2])
vl(93,82,92,WOOD[2]) vl(105,82,92,WOOD[2])
vl(99,84,87,WOOD[2]) hl(94,98,87,WOOD[2])

-- ── chimney stump ─────────────────────────────────────────────────────────
local cx0,cx1=90,102
for y=38,gy0+3 do for x=cx0,cx1 do
  local cut=38+chunk(x,23.0,3,4)
  if y>=cut then
    local c=R2
    if x<=cx0+1 then c=R3 end
    if x>=cx1-2 then c=R1 end
    put(x,y,c)
    if y==cut or y==cut+1 then put(x,y,R3) end
  end
end end
for y=48,66,9 do hl(cx0,cx1,y,R1) end
-- the flue, open to the sky
for y=40,45 do for x=cx0+3,cx1-3 do if alphaAt(x,y)>0 then put(x,y,RD) end end end
hl(cx0+3,cx1-3,40,R1)
crack({{95,46},{98,56},{96,66}},R1)
-- bricks that came off it
for _,p in ipairs({{78,60},{108,58},{84,54}}) do
  rect(p[1],p[2],p[1]+4,p[2]+3,R2) hl(p[1],p[1]+4,p[2],R3) hl(p[1],p[1]+4,p[2]+3,R1)
end

-- ── broken rafters standing out of the wall top ──────────────────────────
beam(64,96,50,64,2,WOOD)
beam(58,99,44,74,2,WOOD)
beam(70,94,78,62,2,WOOD)
beam(44,100,34,84,2,WOOD)
-- one snapped and hanging
beam(50,64,58,76,2,WOOD)

-- ── the roof panel that slid off, leaning on the left wall ───────────────
local A,Bp,Cp,Dp={4,GRND},{27,GRND},{51,101},{31,96}
poly({A,Bp,Cp,Dp},WOOD[3])
for k=0,11 do
  local t=k/11
  local p1={A[1]+(Dp[1]-A[1])*t, A[2]+(Dp[2]-A[2])*t}
  local p2={Bp[1]+(Cp[1]-Bp[1])*t, Bp[2]+(Cp[2]-Bp[2])*t}
  line(p1[1],p1[2],p2[1],p2[2],WOOD[2],1)
end
-- lit upper-left face, shaded lower-right
for k=0,11 do
  local t=k/11
  local p1={A[1]+(Dp[1]-A[1])*t, A[2]+(Dp[2]-A[2])*t}
  put(p1[1],p1[2]-1,WOOD[5]) put(p1[1]+1,p1[2]-2,WOOD[5]) put(p1[1],p1[2],WOOD[4])
  local p2={Bp[1]+(Cp[1]-Bp[1])*t, Bp[2]+(Cp[2]-Bp[2])*t}
  put(p2[1],p2[2],WOOD[1]) put(p2[1]-1,p2[2],WOOD[2])
end
-- broken lath poking out of its bottom edge
for _,p in ipairs({{8,GRND-3,2,-7},{16,GRND-2,5,-6}}) do
  beam(p[1],p[2],p[1]+p[3],p[2]+p[4],2,WOOD) end

-- ── doorway ──────────────────────────────────────────────────────────────
local dmx,dhw,spring=68,12,128
for y=112,GRND do for x=dmx-dhw,dmx+dhw do
  local inside
  if y>=spring then inside=true
  else inside=((x-dmx)/dhw)^2+((y-spring)/15)^2<=1.0 end
  if inside then put(x,y,RD) end
end end
for a=0,180 do
  local r=math.rad(180+a)
  for t=0,2 do
    local x=math.floor(dmx+math.cos(r)*(dhw+t)+.5)
    local y=math.floor(spring+math.sin(r)*(15+t)+.5)
    if y<=spring then local c=R2 if a<50 then c=R3 end if t>=2 then c=R1 end put(x,y,c) end
  end
end
-- a beam has fallen across the opening
beam(54,140,84,130,3,WOOD)

-- ── breach punched through the right wall ────────────────────────────────
for y=98,124 do for x=86,108 do
  local n=((x-97)/11.5)^2+((y-111)/13.5)^2
  local j=chunk(x*1.3+y,37.0,3,0.18)
  if n<=1.0+j*0.1 then put(x,y,RD) end
end end
for y=98,124 do for x=86,108 do
  local n=((x-97)/11.5)^2+((y-111)/13.5)^2
  if n>0.78 and n<=1.0 and alphaAt(x,y)>0 then
    local col=R1 if x<97 and y<111 then col=R3 end
    if alphaAt(x,y)>0 and IMG:getPixel(x,y)~=0 then put(x,y,col) end
  end
end end
rubble(97,124,11,5,STONE,41.0,7)

-- ── the sign bracket, sign long gone ─────────────────────────────────────
hl(108,118,100,R1) vl(118,100,106,R1) put(108,99,R3) put(118,107,R1)
for _,p in ipairs({{117,108},{118,111}}) do ell(p[1],p[2],1.2,1.4,R2) end

-- ── weathering, rubble ───────────────────────────────────────────────────
crack({{34,104},{38,116},{35,128},{39,140}},R1)
weather(18,92,111,GRND,STONE,9.0,0.030)
rubble(28,GRND,16,7,STONE,19.0,14)
rubble(104,GRND,18,9,STONE,27.0,18)
rubble(118,GRND,7,5,STONE,63.0,5)
-- scattered planks
beam(96,GRND-2,116,GRND-6,2,WOOD)
beam(34,GRND-1,48,GRND-4,2,WOOD)

outline(ROL)
groundshadow(62,GRND+7,60,9)
satguard(0.11,262)
finish("bld_workshop_ruin")
