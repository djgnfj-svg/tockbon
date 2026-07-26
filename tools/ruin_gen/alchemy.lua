local D="C:/Users/djgnf/AppData/Local/Temp/claude/C--Users-djgnf-Desktop-godot-games-tockbon/939edd37-7064-46c1-bf48-323835a64c94/scratchpad/"
dofile(D.."lib.lua") dofile(D.."ruinlib.lua")

-- 정제대(연금술 실습동) 잔해.  original: body x20..106 y78..144, upper block
-- x24..98 y56..78, green dome x40..90 y44..56, crystal spire x60..68 y28..44.
newcv(128,160)
local STONE={RD,R1,R2,R3,R4}
local GREEN={AG0,AG0,AG1,AG2,C("#8fa294")}
local GDARK=mixc(AG0,RD,0.45)
local GRND=144

-- ── main body: intact on the left, collapsed away to the right ────────────
local function topf(x)
  if x<34 then return 70
  elseif x<62 then return 54 + (x-34)*0.10
  elseif x<74 then return 58 + (x-62)*2.9          -- the break
  elseif x<94 then return 98 + (x-74)*0.40
  elseif x<=106 then return 110 + (x-94)*1.30 end
  return 130
end
brokenwall(20,106,GRND,topf,STONE,3.0)

-- broken remnant of the yellow ledge that ran across the facade
rect(20,72,54,76,R1) rect(20,72,52,74,R3) hl(20,50,72,R4)
for x=50,56 do local h=chunk(x,71.0,2,2) rect(x,72+h,x+1,76,R1) end

-- ── the dome, sheared in half: the shaded side still stands ───────────────
local dcx,dcy,drx,dry=44,68,26,26
local function brk(y) return 50+math.floor((y-(dcy-dry))*0.20)+chunk(y,91.0,5,3) end
for y=dcy-dry,dcy do for x=dcx-drx,dcx+drx do
  local nout=((x-dcx)/drx)^2+((y-dcy)/dry)^2
  if nout<=1.0 then
    local b=brk(y)
    if x<=b-3 then                                     -- convex outer surface
      local t=((x-dcx)*-0.7071+(y-dcy)*-0.7071)/drx
      local c=GREEN[3]
      if t>0.22 then c=GREEN[4] end
      if t>0.58 then c=GREEN[5] end
      if nout>0.87 then c=GREEN[2] end
      put(x,y,c)
    elseif x<=b then                                   -- the cut: shell thickness
      put(x,y,GREEN[5])
      if x==b then put(x,y,GREEN[2]) end
    elseif x<=b+4 then                                 -- hollow behind the cut
      put(x,y,GDARK)
    end
  end
end end
-- courses of dome tiling, and a few bitten out near the break
for i=0,4 do
  local a=math.rad(184+i*13)
  line(dcx+math.cos(a)*drx*0.42,dcy+math.sin(a)*dry*0.42,
       dcx+math.cos(a)*drx*0.97,dcy+math.sin(a)*dry*0.97,GREEN[2],1)
end
for _,p in ipairs({{34,48},{28,58},{40,46},{24,66}}) do
  ell(p[1],p[2],2.2,1.6,GREEN[2]) put(p[1],p[2]-1,GREEN[1])
end

-- verdigris where the dome shed over the wall
for _,p in ipairs({{30,84,9,4},{66,104,7,3},{88,124,6,3}}) do
  for y=p[2],p[2]+p[4] do for x=p[1],p[1]+p[3] do
    if alphaAt(x,y)>0 and prand(x*1.7+y*3.3)<0.55 then put(x,y,AG1) end end end
end

-- ── a plate of the dome, fallen and half-buried in the rubble ─────────────
for y=118,140 do for x=76,110 do
  local sx,sy=(x-93)/17,(y-141)/22
  local nout=sx*sx+sy*sy local nin=((x-93)/12)^2+((y-141)/16)^2
  if nout<=1.0 and nin>1.0 and y<=138 then
    local c=GREEN[3]
    if x<88 then c=GREEN[4] end
    if x>101 then c=GREEN[1] end
    if y>132 then c=GREEN[2] end
    put(x,y,c)
  end
end end
hl(80,88,127,GREEN[5]) hl(97,104,124,GREEN[2])

-- ── doorway: the arch held, the crown did not ─────────────────────────────
local dx0,dx1,dmx,dhw=40,64,52,12
local spring=124
for y=110,GRND do for x=dx0,dx1 do
  local inside
  if y>=spring then inside=math.abs(x-dmx)<=dhw
  else inside=((x-dmx)/dhw)^2+((y-spring)/14)^2<=1.0 end
  if inside then put(x,y,RD) end
end end
-- arch ring, with a bite taken out of the crown on the collapse side
for a=0,180 do
  local r=math.rad(180+a)
  for t=0,3 do
    local x=math.floor(dmx+math.cos(r)*(dhw+t)+.5)
    local y=math.floor(spring+math.sin(r)*(14+t)+.5)
    if y<=spring then
      local c=R2 if t>=3 then c=R1 end if a<55 then c=R3 end
      if not (a>96 and a<134) then put(x,y,c) end
    end
  end
end
vl(dx0-1,spring-8,GRND,R3) vl(dx1+1,spring-2,GRND,R1)
-- the fallen crown stone, lying in the doorway
rect(56,134,68,140,R2) hl(56,68,134,R3) hl(56,68,140,R1) vl(68,134,140,R1)
rubble(50,GRND,14,8,STONE,44.0,12)

-- the snapped-off crystal spire, toppled clear of the wall
for i=0,17 do
  local t=i/17
  local x=math.floor(8+i*1.05+.5) local y=math.floor(142-i*0.62+.5)
  local hw=math.floor(1+t*3.2)
  vl(x,y-hw,y+hw,R2) put(x,y-hw,R3) put(x,y+hw,R1)
end
rect(24,130,29,138,R1) hl(24,29,130,R2) vl(24,130,138,R2)

-- ── one flask bracket left on the wall, the glass gone ────────────────────
ring(32,96,4.6,6.6,R1) ring(32,96,4.6,5.8,R3)
for i=0,6 do local a=math.rad(292+i*15)
  ell(32+math.cos(a)*5.6,96+math.sin(a)*5.6,1.2,1.2,RD) end
rect(29,88,35,90,R1) hl(29,35,88,R3) vl(32,90,91,R1)
for _,p in ipairs({{26,124},{40,130},{31,135}}) do
  ell(p[1],p[2],1.6,1,R3) put(p[1],p[2]-1,R4) end

-- ── weathering, cracks, rubble at the base ───────────────────────────────
crack({{27,80},{30,92},{28,104},{32,118}},R1)
crack({{80,104},{84,116},{81,128}},R1)
weather(20,54,106,GRND,STONE,7.0,0.032)
rubble(100,GRND,20,12,STONE,17.0,26)
rubble(24,GRND,13,6,STONE,29.0,10)
rubble(13,GRND,7,5,STONE,53.0,5)
rubble(117,GRND,8,5,STONE,61.0,6)

outline(ROL)
groundshadow(64,GRND+7,58,9)
satguard(0.11,262)
finish("bld_alchemy_ruin")
