-- composite the finished PNGs onto a grass backdrop so alpha/shadow reads honestly
local SP="C:/Users/djgnf/AppData/Local/Temp/claude/C--Users-djgnf-Desktop-godot-games-tockbon/939edd37-7064-46c1-bf48-323835a64c94/scratchpad/"
local OUT="C:/Users/djgnf/Desktop/godot_games/tockbon/assets/sprites/base/"
local pc=app.pixelColor
local list=PREVIEW_LIST
local imgs,tw,th={},0,0
for _,n in ipairs(list) do
  local s=app.open((n:sub(1,1)=="@") and (SP..n:sub(2)..".png") or (OUT..n..".png"))
  if s then
    local im=Image(s.width,s.height,ColorMode.RGB) im:drawSprite(s,1,Point(0,0))
    imgs[#imgs+1]={im=im,w=s.width,h=s.height}
    tw=tw+s.width+10 if s.height>th then th=s.height end
    s:close()
  else print("FAIL "..n) end
end
th=th+8
local out=Image(tw,th,ColorMode.RGB)
-- grass backdrop with a little tonal noise, like the campus ground
for y=0,th-1 do for x=0,tw-1 do
  local n=((x*7+y*13)%5)
  local g={62+n,104+n*2,44+n}
  out:putPixel(x,y,pc.rgba(g[1],g[2],g[3],255))
end end
local xo=5
for _,e in ipairs(imgs) do
  for y=0,e.h-1 do for x=0,e.w-1 do
    local p=e.im:getPixel(x,y) local a=pc.rgbaA(p)
    if a>0 then
      local dx,dy=xo+x,th-4-e.h+y
      local q=out:getPixel(dx,dy)
      local t=a/255
      local r=pc.rgbaR(q)+(pc.rgbaR(p)-pc.rgbaR(q))*t
      local g=pc.rgbaG(q)+(pc.rgbaG(p)-pc.rgbaG(q))*t
      local b=pc.rgbaB(q)+(pc.rgbaB(p)-pc.rgbaB(q))*t
      out:putPixel(dx,dy,pc.rgba(math.floor(r),math.floor(g),math.floor(b),255))
    end
  end end
  xo=xo+e.w+10
end
local spr=Sprite(tw,th,ColorMode.RGB)
spr.cels[1].image=out spr.cels[1].position=Point(0,0)
spr:saveAs(SP.."prev.aseprite")
spr:close()
print("prev "..tw.."x"..th)
