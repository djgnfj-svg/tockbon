-- ruin-specific helpers: broken masonry, rubble, cracks, fallen timber

function prand(i)
  local s=math.sin(i*12.9898+78.233)*43758.5453
  return s-math.floor(s)
end
-- blocky jitter: masonry breaks in stone-sized chunks, not per-pixel fuzz
function chunk(x,seed,size,amp)
  return math.floor((prand(math.floor(x/size)*3.7+seed)-0.5)*2*amp+0.5)
end

MASS={}   -- MASS[y*W+x] = true for the last wall drawn (used by courses/cracks)

-- broken wall mass.  topf(x) -> crest y.  pal = {d0,d1,mid,lit,hi}
function brokenwall(x0,x1,ybot,topf,pal,seed,opt)
  opt=opt or {}
  local top={}
  for x=x0,x1 do top[x]=topf(x)+chunk(x,seed,5,2.5) end
  -- fill + crest lip
  for x=x0,x1 do
    for y=top[x],ybot do put(x,y,pal[3]) end
    put(x,top[x],pal[4]) put(x,top[x]+1,pal[4])
    if chunk(x,seed+9,4,1.5)>0 then put(x,top[x],pal[5]) end
  end
  -- side faces: light comes from the upper left
  local ytop=1e9 for x=x0,x1 do if top[x]<ytop then ytop=top[x] end end
  for y=ytop,ybot do
    local lo,hi
    for x=x0,x1 do if top[x]<=y then if not lo then lo=x end hi=x end end
    if lo then
      for i=0,1 do if top[lo+i] and top[lo+i]<=y-2 then put(lo+i,y,pal[4]) end end
      for i=0,2 do if top[hi-i] and top[hi-i]<=y-2 then put(hi-i,y,pal[2]) end end
    end
  end
  -- masonry courses
  if not opt.nocourse then
    local ch=opt.course or 9
    for y=ybot-ch,0,-ch do
      for x=x0,x1 do
        if top[x] and y>=top[x]+3 then put(x,y,pal[2]) end
      end
      local band=math.floor((ybot-y)/ch)
      for x=x0,x1 do
        if ((x - (band%2)*8) % 16)==0 and top[x] and y-ch+1>=top[x]+3 then
          for yy=math.max(top[x]+3,y-ch+1),y-1 do put(x,yy,pal[2]) end
        end
      end
    end
  end
  -- record occupancy
  for x=x0,x1 do for y=top[x],ybot do MASS[y*W+x]=true end end
  return top
end

-- rubble heap: stone-sized blocks with a lit top edge
function rubble(cx,ybot,halfw,height,pal,seed,n)
  n=n or 26
  for i=1,n do
    local r1,r2,r3=prand(i*1.7+seed),prand(i*3.1+seed),prand(i*5.3+seed)
    local t=(i-1)/math.max(1,n-1)
    local w=3+math.floor(r1*4)
    local h=2+math.floor(r2*3)
    local spread=halfw*(0.35+0.65*r3)
    local x=cx+math.floor((r1*2-1)*spread)
    local y=ybot-math.floor(r2*height*(1-0.55*math.abs(x-cx)/math.max(1,halfw)))
    rect(x,y,x+w,y+h,pal[3])
    hl(x,x+w,y,pal[4])
    hl(x,x+w,y+h,pal[2])
    vl(x+w,y,y+h,pal[2])
  end
end

-- jagged crack running down a wall
function crack(pts,c)
  for i=1,#pts-1 do line(pts[i][1],pts[i][2],pts[i+1][1],pts[i+1][2],c,1) end
end

-- a fallen beam / plank
function beam(x0,y0,x1,y1,t,pal)
  line(x0,y0,x1,y1,pal[3],t)
  local dx,dy=x1-x0,y1-y0
  local len=math.max(1,math.sqrt(dx*dx+dy*dy))
  local nx,ny=-dy/len,dx/len
  line(x0+nx*(t-1),y0+ny*(t-1),x1+nx*(t-1),y1+ny*(t-1),pal[4],1)
  line(x0-nx*(t-1),y0-ny*(t-1),x1-nx*(t-1),y1-ny*(t-1),pal[2],1)
end

-- weathering: sparse darker speckle inside a mass (2px clumps, low contrast)
function weather(x0,y0,x1,y1,pal,seed,density)
  density=density or 0.05
  for y=y0,y1 do for x=x0,x1 do
    if alphaAt(x,y)>0 and prand(x*2.3+y*7.1+seed)<density then
      put(x,y,pal[2]) put(x+1,y,pal[2])
    end
  end end
end
