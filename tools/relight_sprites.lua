-- relight_sprites.lua — 스프라이트 입체화(재조명) 후처리 필터
-- 왜: 단색 채움 + 균일 검정 외곽선은 납작한 스티커가 된다. 원본을 다시 그리지 않고 실루엣 기반으로
--     왼쪽 위(광원) 방향 형태 음영을 얹어 부피를 만든다 — 전 스프라이트에 같은 알고리즘이라 톤이 일관된다.
-- 🔴 PNG 익스포트 이후에 도는 후처리다 — aseprite 원본은 납작한 밑그림이고 이 필터가 익스포트된 PNG를 덮어쓴다.
--   그래서 재익스포트하면 음영이 사라진다. 재익스포트한 뒤엔 그 PNG에 이 필터를 다시 돌려라(입력=납작 PNG면 충분).
-- 알고리즘:
--   1. 각 불투명 섬(연결 영역)의 중심·반경을 구한다.
--   2. 중심에서 광원 방향(-1,-1 정규화)으로의 투영 t로 몸 전체를 밝음(+1/+2)·중간·그늘(-1/-2) 밴드로.
--   3. 외곽선: 광원 쪽(윗왼쪽)은 검정 대신 인접 채움색의 어두운 틴트(=색 외곽선/림), 반대쪽은 더 검게.
--   4. lighten=따뜻한 색조 이동, darken=차가운 색조 이동(단조 명도 변화보다 회화적).
--   str=강도(1.0=풀, 0.5=약). 건물은 이미 입체적이라 0.5.
--
-- 사용: Aseprite MCP run_lua_script로 이 파일 내용을 실행하거나, 아래 JOB 리스트를 수정해 재적용.
--   개별 재적용: doPng("<절대경로.png>", 1.0)
-- 제외 대상(적용 금지, 그 이유):
--   타일(tile_*/tileset_*) = 외곽선 음영이 이음새를 깬다 · UI 패널(panel/board/book/btn) = 원래 납작
--   룬/커서 아이콘 = 납작한 심볼 · 이펙트(projectiles/pop/rubbing_spot) = 절차적 VFX

local pc = app.pixelColor
local function rgb2hsv(r,g,b) r,g,b=r/255,g/255,b/255 local mx,mn=math.max(r,g,b),math.min(r,g,b) local d=mx-mn local h=0
  if d>0 then if mx==r then h=((g-b)/d)%6 elseif mx==g then h=(b-r)/d+2 else h=(r-g)/d+4 end h=h*60 end
  local s=mx==0 and 0 or d/mx return h,s,mx end
local function hsv2rgb(h,s,v) h=h%360 local c=v*s local x=c*(1-math.abs((h/60)%2-1)) local m=v-c local r,g,b=0,0,0
  if h<60 then r,g,b=c,x,0 elseif h<120 then r,g,b=x,c,0 elseif h<180 then r,g,b=0,c,x
  elseif h<240 then r,g,b=0,x,c elseif h<300 then r,g,b=x,0,c else r,g,b=c,0,x end
  return math.floor((r+m)*255+.5),math.floor((g+m)*255+.5),math.floor((b+m)*255+.5) end
local function shade(r,g,b,step,str) if step==0 then return r,g,b end local h,s,v=rgb2hsv(r,g,b)
  if s<0.06 then h=250 s=0.14 end  -- 근회색(검정 외곽선)엔 살짝 찬 기저색을 줘 색조 이동이 읽히게
  if step>0 then v=math.min(1,v+0.15*step*str) s=math.max(0,s-0.03*step*str) h=h+9*step*str
  else v=math.max(0.05,v+0.155*step*str) s=math.min(1,s-0.05*step*str) h=h+15*step*str end
  return hsv2rgb(h,s,v) end
local N4={{1,0},{-1,0},{0,1},{0,-1}}
local N8={{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}}
local Lx,Ly=-0.7071,-0.7071

local function relight(flat,W,H,str)
  local function A(x,y) if x<0 or y<0 or x>=W or y>=H then return 0 end return pc.rgbaA(flat:getPixel(x,y)) end
  local isOp,isOut={},{}
  for y=0,H-1 do for x=0,W-1 do if A(x,y)>0 then isOp[y*W+x]=true
    for _,d in ipairs(N4) do if A(x+d[1],y+d[2])==0 then isOut[y*W+x]=true break end end end end end
  local island,isl={},{} local nid=0
  for y=0,H-1 do for x=0,W-1 do local k=y*W+x if isOp[k] and not island[k] then nid=nid+1
    local q={k} island[k]=nid local head=1 local sx,sy,cnt=0,0,0 local pts={}
    while head<=#q do local c=q[head] head=head+1 local cx,cy=c%W,math.floor(c/W) sx=sx+cx sy=sy+cy cnt=cnt+1 pts[#pts+1]=c
      for _,d in ipairs(N8) do local nx,ny=cx+d[1],cy+d[2] if nx>=0 and ny>=0 and nx<W and ny<H then local nk=ny*W+nx
        if isOp[nk] and not island[nk] then island[nk]=nid q[#q+1]=nk end end end end
    local ccx,ccy=sx/cnt,sy/cnt local rad=1
    for _,c in ipairs(pts) do local cx,cy=c%W,math.floor(c/W) local dd=math.sqrt((cx-ccx)^2+(cy-ccy)^2) if dd>rad then rad=dd end end
    isl[nid]={cx=ccx,cy=ccy,r=rad} end end end
  local out=Image(flat)
  local function nf(x,y) for _,d in ipairs(N8) do local nx,ny=x+d[1],y+d[2] local nk=ny*W+nx
      if isOp[nk] and not isOut[nk] then return flat:getPixel(nx,ny) end end
    for _,d in ipairs(N8) do local nx,ny=x+d[1],y+d[2] if isOp[ny*W+nx] then return flat:getPixel(nx,ny) end end
    return flat:getPixel(x,y) end
  for y=0,H-1 do for x=0,W-1 do local k=y*W+x if isOp[k] then
    local px=flat:getPixel(x,y) local r,g,b,a=pc.rgbaR(px),pc.rgbaG(px),pc.rgbaB(px),pc.rgbaA(px)
    local I=isl[island[k]] local t=((x-I.cx)*Lx+(y-I.cy)*Ly)/I.r
    local form=0 if t>0.62 then form=2 elseif t>0.18 then form=1 elseif t<-0.5 then form=-2 elseif t<-0.12 then form=-1 end
    if isOut[k] then local ox,oy=0,0 for _,d in ipairs(N8) do if A(x+d[1],y+d[2])==0 then ox=ox+d[1] oy=oy+d[2] end end
      local m=math.sqrt(ox*ox+oy*oy) local dot=m>0 and (ox/m*Lx+oy/m*Ly) or 0
      if dot>0.2 then local f=nf(x,y) local nr,ng,nb=shade(pc.rgbaR(f),pc.rgbaG(f),pc.rgbaB(f),math.max(0,form),str) out:putPixel(x,y,pc.rgba(nr,ng,nb,a))
      else local nr,ng,nb=shade(r,g,b,-2,str) out:putPixel(x,y,pc.rgba(nr,ng,nb,a)) end
    else local nr,ng,nb=shade(r,g,b,form,str) out:putPixel(x,y,pc.rgba(nr,ng,nb,a)) end
  end end end
  return out
end

function doPng(path,str)  -- 전역: 개별 재적용 편의
  local spr=app.open(path) if not spr then print("FAIL open "..path) return end
  app.command.ChangePixelFormat{format="rgb"} spr=app.activeSprite
  app.command.FlattenLayers()
  local W,H=spr.width,spr.height
  local flat=Image(W,H,ColorMode.RGB) flat:drawSprite(spr,1,Point(0,0))
  local lit=relight(flat,W,H,str)
  local layer=spr.layers[1] local cel=layer:cel(1)
  if cel then cel.image=lit cel.position=Point(0,0) else spr:newCel(layer,1,lit,Point(0,0)) end
  spr:saveAs(path) spr:close() print("OK "..path)
end

-- ── 적용 목록 (분류표다 — 실행 목록이 아니다) ─────────────────────
local B="C:/Users/djgnf/Desktop/godot_games/tockbon/assets/sprites/"
local FULL={
 "player/player_witch_sheet.png","player/player.png","player/floating_wand.png",
 "enemies/slime.png","enemies/slime_elite.png","enemies/mist.png","enemies/vine.png","enemies/hound.png",
 "enemies/beetle.png","enemies/gale.png","enemies/gale_hurt.png","enemies/snake_head.png","enemies/snake_body.png",
 "enemies/snake_tail.png","enemies/snake_head_hurt.png",
 "base/npc_guide.png","base/scarecrow.png","base/props.png",
 "props/coin.png","props/shopkeeper.png","props/mat_slime_core.png","props/mat_moon_sap.png","props/mat_hound_fang.png",
 "props/mat_vine.png","props/mat_beetle_shell.png","props/mat_mist_essence.png","props/mat_night_bloom.png",
 "field/gather.png","field/tree_pine.png","field/tree_round.png","field/tree_dead.png","field/bush.png",
 "field/rock.png","field/flowers.png","field/chest.png","ui/items.png"}
local MILD={  -- 건물: 이미 입체적이라 약하게
 "base/bld_library.png","base/bld_workshop.png","base/bld_alchemy.png","base/bld_market.png","base/gate_arch.png",
 "base/monument_circle.png","base/lamp_post.png","base/bench.png","base/fence_hedge.png",
 -- 폐허 잔해 — 온전 버전과 같은 MILD 대역이라야 한 세대로 보인다
 "base/bld_alchemy_ruin.png","base/bld_workshop_ruin.png","base/bld_market_ruin.png","base/monument_circle_ruin.png"}

-- 🔴🔴 **이미 적용된 파일을 다시 돌리지 마라 — 음영이 두 번 먹어 뭉개진다.**
-- relight는 익스포트 후처리라 결과가 PNG에 굳는다(멱등이 아니다). 위 두 목록은 「분류표」지
-- 「실행 목록」이 아니다 — 전체 재적용은 aseprite에서 **전량 재익스포트한 직후**에만 맞다.
-- 새로 그린 것만 돌릴 때는 아래처럼 그 파일만 담아라:
-- local NEW={"base/gate_arch.png","base/bld_alchemy_ruin.png","base/bld_workshop_ruin.png",
--            "base/bld_market_ruin.png","base/monument_circle_ruin.png"}
-- for _,f in ipairs(NEW) do doPng(B..f,0.5) end        -- 🔴 건물·잔해는 0.5(MILD)다. 1.0을 쓰면 그것만 다른 세대로 보인다
-- print("done new="..#NEW)
--
-- 전량 재적용(재익스포트 직후에만):
-- for _,f in ipairs(FULL) do doPng(B..f,1.0) end
-- for _,f in ipairs(MILD) do doPng(B..f,0.5) end
-- print("done full="..#FULL.." mild="..#MILD)
