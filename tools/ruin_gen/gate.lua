dofile("C:/Users/djgnf/AppData/Local/Temp/claude/C--Users-djgnf-Desktop-godot-games-tockbon/939edd37-7064-46c1-bf48-323835a64c94/scratchpad/lib.lua")

-- start from the shipped flat source so the silhouette stays continuous
local src=app.open("C:/Users/djgnf/Desktop/godot_games/tockbon/assets/aseprite/gate_arch.aseprite")
app.command.ChangePixelFormat{format="rgb"}
src=app.activeSprite
app.command.FlattenLayers()
newcv(src.width,src.height)
IMG:drawSprite(src,1,Point(0,0))
src:close()

local T={C("#253a5e"),C("#3c5e8b"),C("#4f8fba"),C("#73bed3"),C("#a4dddb")}
local HOT=C("#d2f0f0")            -- tinted white-hot (s .125, safe from relight h250 clamp)
local function tealAt(v)
  v=math.max(0,math.min(0.9999,v)) local f=v*4 local i=math.floor(f)+1
  return mixc(T[i],T[math.min(5,i+1)],f-(i-1))
end
-- a pixel that already carries strong colour (banner, gold) resists the bounce
local function vividAt(x,y) local r,g,b,a=get(x,y)
  local mx,mn=math.max(r,g,b),math.min(r,g,b)
  if mx==0 then return false end
  return (mx-mn)/mx>0.34
end

-- 1. keystone at the crown of the arch -------------------------------------
-- stone wedge (gate's own ramp) with a gold ring inset, so it reads apart
-- from the wooden lintel plaque sitting right above it
local SD=C("#202e37") local SM=C("#394a50") local SS=C("#577277") local SL=C("#819796")
local GM=C("#de9e41") local GL=C("#e8c170")
local kx,ky=80,37
for y=ky-7,ky+7 do
  local half=7-math.floor((y-(ky-7))*0.20)   -- true keystone: wider at the top
  for x=kx-half,kx+half do
    local c=SS
    if x<=kx-half+1 then c=SL end
    if x>=kx+half-1 then c=SM end
    if y<=ky-7 or y>=ky+7 then c=SM end
    put(x,y,c)
  end
end
ring(kx,ky,2.6,4.4,GM) ring(kx,ky,2.6,3.6,GL)
ell(kx,ky,2.0,2.0,HOT)

-- 2. veil mask = interior voids of the arch --------------------------------
local veil,vrow={},{}
for y=0,H-1 do
  local L,R
  for x=0,W-1 do if alphaAt(x,y)>0 then if not L then L=x end R=x end end
  if L and R then
    local lo,hi
    for x=L+1,R-1 do if alphaAt(x,y)==0 then veil[y*W+x]=true if not lo then lo=x end hi=x end end
    if lo then vrow[y]={lo,hi} end
  end
end
local ytop,ybot
for y=0,H-1 do if vrow[y] then if not ytop then ytop=y end ybot=y end end
print("veil rows "..ytop.." .. "..ybot)

-- 3. paint the veil --------------------------------------------------------
for y=ytop,ybot do
  local rr=vrow[y]
  local x0,x1=rr[1],rr[2] local wd=math.max(1,x1-x0)
  local vt=(y-ytop)/math.max(1,ybot-ytop)
  for x=x0,x1 do
    if veil[y*W+x] then
      local u=(x-x0)/wd
      -- steep falloff: deep blue flanks, narrow hot core (not a flat pale slab)
      local edge=(1-math.abs(2*u-1))^1.6
      -- body settles on saturated cyan; only a narrow core goes white-hot
      local B=0.16+0.60*edge+0.06*vt
      if edge>0.88 then B=B+0.22*((edge-0.88)/0.12) end
      -- concentric ripples radiating from the crown: an energy surface, not a waterfall
      B=B+0.10*math.sin(math.sqrt((x-kx)^2+((y-ky)*1.15)^2)*0.52)
      if (x%9==0) then B=B+0.05 end
      local a=170+58*edge
      if y>=ybot-13 then local f=(y-(ybot-13))/13 B=B-0.30*f a=a*(1-0.78*f) end
      put(x,y,tealAt(B),math.max(0,math.min(255,a)))
    end
  end
end
for _,m in ipairs({{74,60},{88,74},{70,94},{92,106},{78,120},{85,50},{68,132},{95,88}}) do
  for dy=0,1 do for dx=0,1 do
    if veil[(m[2]+dy)*W+(m[1]+dx)] then put(m[1]+dx,m[2]+dy,HOT,240) end end end
end

-- 4. inner rim + light bounce on the stone --------------------------------
local N8={{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}}
local dist,q={},{}
for y=0,H-1 do for x=0,W-1 do if veil[y*W+x] then
  for _,d in ipairs(N8) do local nx,ny=x+d[1],y+d[2]
    if alphaAt(nx,ny)>0 and dist[ny*W+nx]==nil then dist[ny*W+nx]=1 q[#q+1]={nx,ny} end end
end end end
local qh=1
while qh<=#q do local c=q[qh] qh=qh+1 local cd=dist[c[2]*W+c[1]]
  if cd<6 then for _,d in ipairs(N8) do local nx,ny=c[1]+d[1],c[2]+d[2]
    if alphaAt(nx,ny)>0 and dist[ny*W+nx]==nil then dist[ny*W+nx]=cd+1 q[#q+1]={nx,ny} end end end
end
for k,d in pairs(dist) do
  local x,y=k%W,math.floor(k/W)
  local w=0.48*(1-(d-1)/6.0)
  if d==1 then w=0.60 end
  if vividAt(x,y) then w=w*0.40 end
  tint(x,y,(d<=2) and T[5] or T[4],w)
end

-- 5. the two crystals, blazing --------------------------------------------
local function orb(cx,cy)
  for y=cy-12,cy+12 do for x=cx-12,cx+12 do
    local dd=math.sqrt((x-cx)^2+(y-cy)^2)
    local a=alphaAt(x,y)
    if dd<=1.5 then put(x,y,HOT)
    elseif dd<=2.9 then put(x,y,T[5])
    elseif dd<=4.3 then put(x,y,T[4])
    elseif dd<=5.5 then put(x,y,T[3])
    elseif dd<=6.4 then if a>0 then put(x,y,T[2],a) else put(x,y,T[2],185) end
    elseif a>0 then
      local w=0.58*(1-(dd-6.4)/5.2)
      if w>0 then if vividAt(x,y) then w=w*0.45 end tint(x,y,T[4],w) end
    end
  end end
end
orb(40,37) orb(120,37)

-- 6. lit runes carved into each pillar shaft -------------------------------
local function rune(cx,cy)
  for y=cy-9,cy+9 do for x=cx-8,cx+8 do
    local dd=math.sqrt((x-cx)^2+((y-cy)*0.62)^2)
    if dd>2.5 and dd<8 and alphaAt(x,y)>0 then tint(x,y,T[4],0.30*(1-(dd-2.5)/5.5)) end
  end end
  local pts={{0,-6},{0,-5},{0,-4},{0,-3},{0,-2},{0,-1},{0,0},{0,1},{0,2},{0,3},{0,4},{0,5},{0,6},
             {-3,-4},{-2,-4},{-1,-4},{1,-4},{2,-4},{3,-4},
             {-3,2},{-2,3},{2,3},{3,2},{-2,-1},{2,-1}}
  for _,p in ipairs(pts) do
    local x,y=cx+p[1],cy+p[2]
    if alphaAt(x,y)>0 then put(x,y,T[4],alphaAt(x,y)) end
  end
  for _,p in ipairs({{0,-1},{0,0},{0,1}}) do put(cx+p[1],cy+p[2],HOT) end
end
rune(40,118) rune(120,118)

-- 7. the ground under the gate is lit, not just shadowed -------------------
for y=140,H-1 do for x=0,W-1 do
  local r,g,b,a=get(x,y)
  local cd=math.abs(x-80)
  if a>0 and a<250 then
    tint(x,y,T[1],0.55*math.max(0,1-cd/60.0))   -- shadow stays a shadow, just cast in portal light
  elseif a==0 and y>=146 then
    local dd=math.sqrt((cd/30)^2+((y-152)/8)^2)
    if dd<1 then put(x,y,tealAt(0.52-0.30*dd),100*(1-dd)) end
  end
end end

satguard(0.11,200)
finish("gate_arch")
