-- does any pixel land in the relight trap?  shade() rewrites s<0.06 to hue 250,
-- and only on the shaded bands, which is what makes a two-faced sprite.
local OUT="C:/Users/djgnf/Desktop/godot_games/tockbon/assets/sprites/base/"
local pc=app.pixelColor
local files={"gate_arch","bld_alchemy_ruin","bld_workshop_ruin","bld_market_ruin","monument_circle_ruin"}
for _,n in ipairs(files) do
  local s=app.open(OUT..n..".png")
  local W,H=s.width,s.height
  local im=Image(W,H,ColorMode.RGB) im:drawSprite(s,1,Point(0,0))
  local total,trap,low,hist=0,0,0,{}
  local worst,worsthex=1,""
  for y=0,H-1 do for x=0,W-1 do
    local p=im:getPixel(x,y) local a=pc.rgbaA(p)
    if a>0 then
      local r,g,b=pc.rgbaR(p),pc.rgbaG(p),pc.rgbaB(p)
      local mx,mn=math.max(r,g,b),math.min(r,g,b)
      local sat=(mx==0) and 0 or (mx-mn)/mx
      total=total+1
      if sat<0.06 then trap=trap+1
        if sat<worst then worst=sat worsthex=string.format("#%02x%02x%02x",r,g,b) end
      elseif sat<0.10 then low=low+1 end
      local k=string.format("#%02x%02x%02x",r,g,b)
      hist[k]=(hist[k] or 0)+1
    end
  end end
  local arr={} for k,v in pairs(hist) do arr[#arr+1]={k=k,v=v} end
  table.sort(arr,function(p,q) return p.v>q.v end)
  print(string.format("%-24s %dx%d  px=%d  TRAP(s<0.06)=%d  low(0.06..0.10)=%d  uniq=%d",
        n,W,H,total,trap,low,#arr))
  if trap>0 then print("      worst "..worsthex.." s="..string.format("%.3f",worst)) end
  local line="      top: "
  for i=1,8 do line=line..arr[i].k.."*"..arr[i].v.."  " end
  print(line)
  s:close()
end
