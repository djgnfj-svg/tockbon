local D="C:/Users/djgnf/AppData/Local/Temp/claude/C--Users-djgnf-Desktop-godot-games-tockbon/939edd37-7064-46c1-bf48-323835a64c94/scratchpad/"
dofile(D.."lib.lua") dofile(D.."ruinlib.lua")

-- 매점 잔해.  original: striped awning x9..135 y27..48, dark timber stall
-- x15..129 y51..117.  low and wide, and the one wreck built of wood not stone.
-- value plan: dark timber frame + dark empty stall, pale striped rag on top.
newcv(144,128)
local STONE={RD,R1,R2,R3,R4}
local WOOD={C("#241f1c"),C("#332e29"),AW0,AW1,AW2}          -- dark, like the original stall
local CLOTH={C("#5c4c4c"),C("#756363"),C("#998484"),C("#ab9898"),C("#c4aeae")}
local GRND=117

-- ── back of the stall: a broken board wall, the dark that everything reads on ──
for x=26,110 do
  local t=58+math.floor((x-26)*0.34)+chunk(x,17.0,4,3)
  if x>92 then t=t+(x-92)*1.6 end
  for y=t,96 do
    local c=WOOD[2]
    if ((x-26)%7)==0 then c=WOOD[1] end
    if x<32 then c=WOOD[3] end
    put(x,y,c)
    if y<=t+1 then put(x,y,WOOD[3]) end
  end
end
-- one shelf board still up, one slid off
for y=74,77 do hl(30,86,y,WOOD[3]) end
hl(30,86,74,WOOD[5]) hl(30,86,77,WOOD[1])
beam(60,90,96,80,3,WOOD)
-- stock left behind, in silhouette
for _,p in ipairs({{40,66},{47,68},{78,70}}) do
  rect(p[1],p[2],p[1]+4,p[2]+7,WOOD[1]) rect(p[1]+1,p[2]-3,p[1]+3,p[2],WOOD[1])
  vl(p[1],p[2],p[2]+7,WOOD[3])
end
ell(66,90,3.5,4.5,WOOD[1]) ring(66,90,3.5,4.6,WOOD[3])

-- ── the counter, sagging off its right leg ──────────────────────────────
local function ctop(x) local t=90+math.floor((x-20)*0.05)
  if x>102 then t=t+math.floor((x-102)*0.62) end return t end
for x=20,122 do
  local t=ctop(x)
  for y=t,GRND do
    local c=WOOD[3]
    if ((x-20)%9)==0 then c=WOOD[2] end
    if y<=t+3 then c=WOOD[4] end
    if y<=t+1 then c=WOOD[5] end
    if y>=GRND-2 then c=WOOD[1] end
    put(x,y,c)
  end
end
for y=100,GRND do for x=60,82 do
  if ((x-71)/11)^2+((y-110)/10)^2<=1.0 then put(x,y,RD) end
end end
for _,p in ipairs({{61,103,3,-5},{79,104,-3,-5}}) do
  beam(p[1],p[2],p[1]+p[3],p[2]+p[4],2,WOOD) end
beam(104,102,124,114,3,WOOD)

-- ── the frame: left post standing, right post a stump ───────────────────
local function timberpost(x0,x1,y0,y1,seed)
  for y=y0,y1 do for x=x0,x1 do
    local cut=y0+chunk(x,seed,2,3)
    if y>=cut then
      local c=WOOD[3]
      if x<=x0+1 then c=WOOD[4] end
      if x>=x1-1 then c=WOOD[1] end
      put(x,y,c)
      if y<=cut+1 then put(x,y,WOOD[5]) end
    end
  end end
  for y=y0+9,y1,12 do hl(x0,x1,y,WOOD[1]) end
end
timberpost(14,23,30,GRND,7.0)
timberpost(122,130,92,GRND,13.0)
for _,p in ipairs({{124,92,-5},{128,93,-7}}) do
  vl(p[1],p[2]+p[3],p[2],WOOD[2]) put(p[1],p[2]+p[3],WOOD[4]) end

-- head rail, snapped two thirds along
for y=32,39 do for x=14,86 do
  local c=WOOD[3] if y<=33 then c=WOOD[5] end if y>=38 then c=WOOD[1] end
  put(x,y,c)
end end
for _,p in ipairs({{86,33,5},{86,36,3},{86,39,7}}) do hl(p[1],p[1]+p[3],p[2],WOOD[2]) end

-- ── the awning, torn to rags — the one thing that says "this was the market" ──
-- gaps between the rags matter more than the rags: you see the dark stall through them
local strips={{16,27,68},{31,39,82},{45,57,56},{62,69,88},{75,86,72}}
for si,s in ipairs(strips) do
  local x0,x1,ybot=s[1],s[2],s[3]
  for x=x0,x1 do
    local yb=ybot-math.floor(math.abs(math.sin((x-x0)*0.8+si*1.7))*7)-chunk(x,29.0+si,3,2)
    local stripe=(math.floor((x-x0)/5)%2)==0
    for y=39,yb do
      local c=stripe and CLOTH[2] or CLOTH[5]
      if x<=x0 then c=CLOTH[4] end
      if x>=x1 then c=CLOTH[1] end
      if y>yb-3 then c=stripe and CLOTH[1] or CLOTH[3] end
      put(x,y,c)
    end
    put(x,yb,CLOTH[1])
  end
  if si==2 or si==5 then
    local hy=ybot-18
    ell(x0+6,hy,3,4,RD) ring(x0+6,hy,3,4.3,CLOTH[1])
  end
end
-- a corner of it has come away and hangs by one tie
poly({{86,40},{95,45},{89,66},{85,54}},CLOTH[3])
poly({{86,40},{90,42},{86,60},{85,54}},CLOTH[5])
line(95,45,89,66,CLOTH[1],1)

-- ── ground debris ──────────────────────────────────────────────────────
beam(4,113,26,109,3,WOOD)
beam(96,114,126,116,2,WOOD)
rect(88,104,106,GRND,WOOD[3]) hl(88,106,104,WOOD[5]) vl(88,104,GRND,WOOD[4])
for y=107,GRND,5 do hl(88,106,y,WOOD[1]) end
poly({{97,104},{106,104},{106,112}},RD)
rubble(36,GRND,15,4,STONE,23.0,8)
rubble(132,GRND,9,4,STONE,31.0,6)

outline(ROL)
groundshadow(72,GRND+6,66,8)
satguard(0.11,262)
finish("bld_market_ruin")
