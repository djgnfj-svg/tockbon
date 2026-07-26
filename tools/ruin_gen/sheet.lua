-- 사용자에게 보여줄 합본: 위=온전 / 아래=잔해, 맨 왼쪽=문
local SP="C:/Users/djgnf/AppData/Local/Temp/claude/C--Users-djgnf-Desktop-godot-games-tockbon/939edd37-7064-46c1-bf48-323835a64c94/scratchpad/"
local OUT="C:/Users/djgnf/Desktop/godot_games/tockbon/assets/sprites/base/"
local pc=app.pixelColor
local pairsList={{"bld_alchemy","bld_alchemy_ruin"},{"bld_workshop","bld_workshop_ruin"},
                 {"bld_market","bld_market_ruin"},{"monument_circle","monument_circle_ruin"}}
local function load(n)
  local s=app.open(OUT..n..".png")
  local im=Image(s.width,s.height,ColorMode.RGB) im:drawSprite(s,1,Point(0,0))
  local r={im=im,w=s.width,h=s.height} s:close() return r
end
local gate=load("gate_arch")
local cols={} local tw=gate.w+24
for _,p in ipairs(pairsList) do
  local a,b=load(p[1]),load(p[2])
  cols[#cols+1]={a,b} tw=tw+math.max(a.w,b.w)+14
end
local rowh=176
local th=rowh*2+12
local out=Image(tw,th,ColorMode.RGB)
for y=0,th-1 do for x=0,tw-1 do
  local n=((x*7+y*13)%5) local band=(y<rowh) and 0 or 10
  out:putPixel(x,y,pc.rgba(58+n+band,98+n*2+band,42+n+band,255))
end end
local function blit(e,ox,oy)
  for y=0,e.h-1 do for x=0,e.w-1 do
    local p=e.im:getPixel(x,y) local a=pc.rgbaA(p)
    if a>0 then
      local dx,dy=ox+x,oy+y
      if dx>=0 and dy>=0 and dx<tw and dy<th then
        local q=out:getPixel(dx,dy) local t=a/255
        out:putPixel(dx,dy,pc.rgba(
          math.floor(pc.rgbaR(q)+(pc.rgbaR(p)-pc.rgbaR(q))*t),
          math.floor(pc.rgbaG(q)+(pc.rgbaG(p)-pc.rgbaG(q))*t),
          math.floor(pc.rgbaB(q)+(pc.rgbaB(p)-pc.rgbaB(q))*t),255))
      end
    end
  end end
end
blit(gate,8,th-8-gate.h)
local xo=gate.w+24
for _,c in ipairs(cols) do
  local w=math.max(c[1].w,c[2].w)
  blit(c[1],xo+(w-c[1].w)//2, rowh-6-c[1].h)
  blit(c[2],xo+(w-c[2].w)//2, th-8-c[2].h)
  xo=xo+w+14
end
local spr=Sprite(tw,th,ColorMode.RGB)
spr.cels[1].image=out spr.cels[1].position=Point(0,0)
spr:saveAs(SP.."sheet.aseprite") spr:close()
print("sheet "..tw.."x"..th)
