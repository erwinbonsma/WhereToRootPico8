pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- where to root? v0.2
-- (c) 2023  eriban

frate=30
seed_r=2.2
tree_r=3
max_r=max(seed_r,tree_r)
tree_h=5
branch_l=8
yscale=0.75
seeddrop_h=6

cellsz=8
roots_r=16
max_growrate=0.05/frate

player_pals={
 {--red
  [6]=8,[5]=2,[7]=14
 },
 {--pink
  [6]=14,[5]=2,[7]=15
 },
 {--green
  [6]=10,[5]=3,[7]=11
 },
 {--blue
  [6]=13,[5]=2,[7]=12
 }
}

--maps level-menu positions to
--levels
levelmenu_pos={
 1,2,3,0,
 0,0,4,0,
 0,0,0,0,
 0,0,0,0,
 0,0,0,0
}

level_defs={{
 name="basic",
 data={
  mapdef={0,0,15,15},
  goals={{3,3,3,3},{3,9,3,3},{9,3,3,3},{9,9,3,3}},
  plyrs={{35,35}}
 }
},{
 name="walls",
 data={
  mapdef={15,0,15,15},
  goals={{3,3,4,4},{3,8,4,4},{8,3,4,4},{8,8,4,4}},
  plyrs={{39,39}}
 }
},{
 name="tiles",
 data={
  mapdef={30,0,15,15},
  goals={{3,3,3,3},{3,9,3,3},{9,3,3,3},{9,9,3,3}},
  plyrs={{35,35}}
 }
},{
 name="water",
 data={
  mapdef={45,0,15,15},
  goals={{2,2,4,4},{2,9,4,4},{9,2,4,4},{9,9,4,4}},
  plyrs={{31,31}}
 }
},{
 name="fancy",
 data={
  mapdef={17,18},
  goals={{3,3,4,4},{9,5,4,4},{3,9,4,4},{9,11,4,4}},
  plyrs={{39,39},{88,55},{39,87},{88,103}}
 }
}}

--sprite flags
flag_goal=0
flag_wall=1
flag_water=2
flag_barren=3

function vlen(dx,dy)
 return sqrt(dx*dx+dy*dy)
end

--wrap coroutine with a name to
--facilitate debugging crashes
function cowrap(
 name,coroutine,...
)
 local w={
  name=name,
  coroutine=cocreate(coroutine),
  args={...}
 }
 return w
end

--returns true when routine died
function coinvoke(wrapped_cr)
 local cr=wrapped_cr.coroutine
 if not coresume(
  cr,
  wrapped_cr.args
 ) then
  printh(
   "coroutine "..
   wrapped_cr.name.." crashed"
  )
  while true do end
 end
 return costatus(cr)=="dead"
end

function wait(steps)
 for i=1,steps do
  yield()
 end
end

function istree(obj)
 return getmetatable(obj)==tree
end

function isseed(obj)
 return getmetatable(obj)==seed
end

--class inheritance
function extend(clz,baseclz)
 for k,v in pairs(baseclz) do
  clz[k]=v
 end
end

stats={}

function stats:new()
 local o=setmetatable({},self)
 self.__index=self

 o.lvls={}

 return o
end

function stats:mark_done(
 level
)
 self.lvls[level]=true
end

function stats:is_done(level)
 return self.lvls[level]!=nil
end

levelmenu={}

function levelmenu:new()
 local o=setmetatable({},self)
 self.__index=self

 o:_setpos(0)

 o.grid=cellgrid:new({
  mx=0,my=18,nrows=17,ncols=17
 })

 o.hbridges={}
 for b in all({0,1}) do
  o.hbridges[b]=true
 end
 o.vbridges={}
 for b in all({2}) do
  o.vbridges[b]=true
 end

 return o
end

function levelmenu:_setpos(pos)
 self.pos=pos
 self.cx=pos%4
 self.cy=flr(pos/4)
 self.lvl=levelmenu_pos[pos+1]
end

function levelmenu:_connected(
 p1,p2
)
 assert(p2>p1)
 if p2-p1==1 then
  return self.hbridges[p1]
 end
 if p2-p1==4 then
  return self.vbridges[p1]
 end
 return false
end

function levelmenu:_try_move(
 delta_pos
)
 local pnew=self.pos+delta_pos
 if self:_connected(
  min(self.pos,pnew),
  max(self.pos,pnew)
 ) then
  self:_setpos(pnew)
 end
end

function levelmenu:update()
 if btnp(⬅️) and self.cx>0 then
  self:_try_move(-1)
 end
 if btnp(➡️) and self.cx<3 then
  self:_try_move(1)
 end
 if btnp(⬆️) and self.cy>0 then
  self:_try_move(-4)
 end
 if btnp(⬇️) and self.cy<4 then
  self:_try_move(4)
 end
 if btnp(❎) then
  start_game(self.lvl)
 end
end

function levelmenu:draw()
 cls()

 camera(4,-12)
 self.grid:draw()

 palt(7,true)
 palt(0,false)
 for x=1,3 do
  for y=1,3 do
   spr(66,
    (self.cx*4+x)*8,
    (self.cy*4+y)*6-2
   )
  end
 end

 for p=0,19 do
  local x=(p%4)*32+16
  local y=flr(p/4)*24+10

  if self.hbridges[p] then
   local open=(
    levelmenu_pos[p+1]!=0 or
    levelmenu_pos[p+2]!=0
   ) and false
   spr(
    open and 81 or 80,x+16,y
   )
   spr(
    open and 70 or 69,x+16,y+6
   )
  end

  if self.vbridges[p] then
   local open=(
    levelmenu_pos[p+1]!=0 or
    levelmenu_pos[p+5]!=0
   ) and false
   spr(open and 82 or 80,x,y+12)
  end
 end

 palt()
 camera()

 local name=level_defs[
  self.lvl
 ].name
 print(name,64-#name*2,120,7)
end
-->8
--cellgrid

cellgrid={}
function cellgrid:new(o)
 o=setmetatable(o or {},self)
 self.__index=self

 o.nrows=o.nrows or 18
 o.ncols=o.ncols or 16

 o.head={
  x=0,y=-100,r=0
 }
 o.tail={
  x=0,y=o.nrows*8+100,r=0
 }
 o.head._nxt=o.tail
 o.tail._prv=o.head

 o.observers={}

 return o
end

--insert obj into linked list,
--after prev
function cellgrid:_insert(
 prev,obj
)
 assert(
  obj._nxt==nil and
  obj._prv==nil
 )
 assert(
  prev.y<=obj.y and
  obj.y<=prev._nxt.y
 )

 obj._nxt=prev._nxt
 obj._prv=prev
 obj._nxt._prv=obj
 prev._nxt=obj
end

function cellgrid:_obj_before_y(
 y,start_at
)
 local prev=start_at
 if prev==nil then
  if y<self.nrows*4 then
   prev=self.head
  else
   prev=self.tail._prv
  end
 end

 while prev._nxt.y<y do
  prev=prev._nxt
 end
 while prev.y>y do
  prev=prev._prv
 end

 assert(
  prev.y<=y and prev._nxt.y>=y
 )
 return prev
end

function cellgrid:_remove(obj)
 assert(
  obj._nxt!=nil and
  obj._prv!=nil
 )
 assert(
  obj._prv._nxt==obj and
  obj._nxt._prv==obj
 )
 obj._prv._nxt=obj._nxt
 obj._nxt._prv=obj._prv
 obj._prv=nil
 obj._nxt=nil
end

function cellgrid:add_observer(
 observer
)
 add(self.observers,observer)
end

function cellgrid:add(obj)
 self:_insert(
  self:_obj_before_y(obj.y),obj
 )

 for o in all(self.observers) do
  o:unit_added(obj)
 end
end

function cellgrid:del(obj)
 self:_remove(obj)

 for o in all(self.observers) do
  o:unit_removed(obj)
 end
end

function cellgrid:moved(obj)
 if (
  obj._prv.y<=obj.y and
  obj._nxt.y>=obj.y
 ) then
  --position in linked-list
  --remains unchanged
  return
 end

 local start_at=obj._prv
 self:_remove(obj)
 local prev=self:_obj_before_y(
  obj.y,start_at
 )
 self:_insert(prev,obj)
end

function cellgrid:_invalid_pos(
 x,y
)
 return (
  x<0 or x>=self.ncols*8 or
  y<0 or y>=self.nrows*8
 )
end

function cellgrid:_maphit(
 x,y,vx,vy,r
)
 if (vx==0 and vy==0) return true

 local cz=cellsz
 local mx=x%cz
 local my=y%cz
 --dx/dy is distance along axis
 --to cell in dir specified by
 --vx/vy
 local dx=vx*((cz+vx*cz)/2-mx)
 local dy=vy*((cz+vy*cz)/2-my)

 return (dx*dx+dy*dy < r*r)
end

function cellgrid:_maphasflag(
 mx,my,flag
)
 local si=mget(
  self.mx+mx,self.my+my
 )
 return fget(si,flag)
end

function cellgrid:_iswater(mx,my)
 return self:_maphasflag(
  mx,my,flag_water
 )
end

function cellgrid:_isbarren(mx,my)
 return self:_maphasflag(
  mx,my,flag_barren
 )
end

function cellgrid:_iswall(mx,my)
 return self:_maphasflag(
  mx,my,flag_wall
 )
end

function cellgrid:iswater(x,y)
 return self:_iswater(
  flr(x/cellsz),
  flr(y/cellsz)
 )
end

function cellgrid:isbarren(x,y)
 return self:_isbarren(
  flr(x/cellsz),
  flr(y/cellsz)
 )
end

--the direction a seed above
--the water is pushed in (by the
--neighbouring ground) to be
--fully above the water
function cellgrid:water_force(
 x,y,r
)
 local mx=flr(x/cellsz)
 local my=flr(y/cellsz)

 local fx=0
 local fy=0
 for v in all({-1,1}) do
  if (
   self:_maphit(x,y,v,0,r) and
   not self:_iswater(mx+v,my)
  ) then
   fx=-v
  end
  if (
   self:_maphit(x,y,0,v,r) and
   not self:_iswater(mx,my+v)
  ) then
   fy=-v
  end
 end

 return {x=fx,y=fy}
end

function cellgrid:hits_wall(
 x,y,r
)
 local mx=flr(x/cellsz)
 local my=flr(y/cellsz)
 for dx=-1,1 do
  for dy=-1,1 do
   if self:_maphit(
    x,y,dx,dy,r
   ) and self:_iswall(
    mx+dx,my+dy
   ) then
    return true
   end
  end
 end

 return false
end

function cellgrid:_fits_map(
 x,y,r
)
 if (self.mx==nil) return true

 local mx=flr(x/cellsz)
 local my=flr(y/cellsz)

 for dx=-1,1 do
  for dy=-1,1 do
   if (
    dx!=0 or dy!=0
   ) and self:_maphit(
    x,y,dx,dy,r
   ) and self:_iswall(
    mx+dx,my+dy
   ) then
    return false
   end
  end
 end

 return true
end

--visits all objects that an
--object at position (x,y) with
--radius r hits.
-- when objx is provided, it is
--the starting point for the
--search but excluded
-- search is aborted when the
--visitor return true
function cellgrid:visit_hits(
 x,y,r,visitor,objx
)
 if self:_invalid_pos(x,y) then
  return
 end

 local obj=self:_obj_before_y(
  y-r-max_r,objx
 )
 local maxy=y+r+max_r
 while obj.y<=maxy do
  if obj!=objx then
   if (
    vlen(x-obj.x,y-obj.y)
    <obj.r+r
   ) then
    if (visitor(obj)) return
   end
  end
  obj=obj._nxt
 end
end

function cellgrid:fits(
 x,y,r,objx
)
 if (
  self:_invalid_pos(x,y) or
  not self:_fits_map(x,y,r)
 ) then
  return false
 end

 local fits=true
 local visitor=function(obj)
  fits=false
  return true --abort search
 end

 self:visit_hits(
  x,y,r,visitor,objx
 )

 return fits
end

function cellgrid:update_units()
 local unit=self.head._nxt

 while unit!=self.tail do
  local destroy=unit:update()
  local nxt=unit._nxt

  if (destroy) self:del(unit)

  unit=nxt
 end
end

function cellgrid:visit_units(
 visitor
)
 local unit=self.head._nxt

 while unit!=self.tail do
  visitor(unit)
  unit=unit._nxt
 end
end

--draws all units with y<maxy
--ordered by their y position.
--starts from start_unit (or
--first unit if nil).
--return first unit with y>=maxy
function cellgrid:draw_units(
 start_unit,maxy
)
 local unit=(
  start_unit or self.head._nxt
 )
 maxy=maxy or self.nrows*6

 while unit.y<maxy do
  unit:draw()
  unit=unit._nxt
 end

 return unit
end

function cellgrid:draw()
 assert(self.mx!=nil)
 local drawunit=nil
 for row=1,self.nrows do
  palt(7,true)
  palt(0,false)
  map(
   self.mx,self.my+row-1,
   0,row*6-8,self.ncols,1
  )
  pal(0)

  drawunit=self:draw_units(
   drawunit,row*cellsz
  )
 end
end

--creates a function that checks
--if a grid cell coordinate is
--inside a given rectangle
function rectgoal(args)
 local x0=args[1]
 local y0=args[2]
 local w=args[3]
 local h=args[4]
 return function(x,y)
  return (
   x>=x0 and x<x0+w and
   y>=y0 and y<y0+h
  )
 end
end

areagoal={}
function areagoal:new(
 areas,players
)
 local o=setmetatable({},self)
 self.__index=self

 o.areas=areas
 o.players=players

 o.counts={}
 for plyr in all(players) do
  local pc={}
  for area in all(areas) do
   pc[area]=0
  end
  o.counts[plyr]=pc
 end
 o.winner=nil

 return o
end

function areagoal:_is_done(
 counts
)
 for area in all(self.areas) do
  if (counts[area]==0) return false
 end
 return true
end

function areagoal:unit_added(
 unit
)
 if (not istree(unit)) return

 local plyr=unit.player
 local cellx=unit.x/cellsz
 local celly=unit.y/cellsz
 for area in all(self.areas) do
  if area(cellx,celly) then
   local cf=self.counts[plyr]
   cf[area]+=1
   unit.area=area
   if (
    cf[area]==1 and
    self:_is_done(cf)
   ) then
    self.winner=plyr
   end
   return
  end
 end

 unit.area=nil
end

function areagoal:unit_removed(
 unit
)
 local c=self.counts
 if unit.area!=nil then
  c[unit.player][unit.area]-=1
  unit.area=nil
 end
end

function areagoal:draw()
 local x=10
 local y=2
 local c=self.counts
 for p in all(self.players) do
  pal(p.pal)
  spr(4,x,y-1)
  x+=7
  for area in all(self.areas) do
   print(c[p][area],x,y,6)
   x+=4
  end
  x+=4
  pal(0)
 end
end

-->8
--animations

function seeddrop_anim(args)
 local s=args[1]
 local kills=args[2]

 s.vh=0
 while s.h>0 do
  s.vh-=0.04
  s.h+=s.vh
  yield()

  if s.h<4 and kills!=nil then
   for kill in all(kills) do
    if isseed(kill) then
     kill.anim=cowrap(
      "seedsquash",
      seedsquash_anim,kill
     )
    else
     kill.destroy=true
    end
   end
   kills=nil
  end
 end

 s.h=0
 s.vh=nil
end

function seedsquash_anim(args)
 local s=args[1]

 s.si=13
 wait(4)

 while s.si<15 do
  s.si+=1
  wait(4)
 end

 s.destroy=true
end

function seedsplat_anim(args)
 local s=args[1]

 s.vh=0
 while s.h>2 do
  s.vh-=0.04
  s.h+=s.vh
  yield()
 end

 s.h=2
 s.vh=nil

 seedsquash_anim({s})
end

function waterdrop_anim(args)
 local s=args[1]
 local f=grid:water_force(
  s.x,s.y,s.r
 )

 while f.x!=0 or f.y!=0 do
  s.x+=f.x*s.speed
  s.y+=f.y*s.speed
  yield()
  f=grid:water_force(
   s.x,s.y,s.r
  )
 end

 s.vh=0
 while s.h>-2 do
  s.vh-=0.04
  s.h+=s.vh
  yield()
 end
 s.h=-2
 s.vh=nil

 s.si=5
 wait(2)

 while s.si<12 do
  s.si+=1
  wait(2)
 end

 s.destroy=true
end

function seedroot_anim(args)
 local s=args[1]
 local t=args[2]
 s.vh=0.5
 while s.h>0 or s.vh>0 do
  s.vh-=0.04
  s.h+=s.vh
  yield()
 end
 yield()

 local steps=s.si
 for i=0,s.si-1 do
  s.h=-i
  wait(10)
 end

 if s:_tree_fits(t) then
  grid:add(t)
 end

 s.destroy=true
end

function seedrot_anim(args)
 local s=args[1]

 while s.si>1 do
  s.si-=1
  wait(30)
 end

 s.destroy=true
end

function gameend_anim(args)
 local g=args[1]
 local msg=args[2]

 g.msg=msg

 wait(90)

 scene=menu
end
-->8
--seed

seed={}
function seed:new(dx,dy,o)
 o=setmetatable(o or {},self)
 self.__index=self

 o.dx=dx
 o.dy=dy
 o.age=0
 o.growrate=(
  0.04+rnd(0.02)
 )/frate
 o.speed=o.speed or 0.1
 o.moving=true
 o.selected=false
 o.anim=nil
 o.si=o.si or 4

 return o
end

--check if tree fits. it may
--hit seeds, but not another
--tree
function seed:_tree_fits(t)
 local fits=true
 local visitor=function(obj)
  if istree(obj) then
   fits=false
  end
 end

 grid:visit_hits(
  t.x,t.y,t.r,visitor,self
 )

 return fits
end

function seed:root()
 if ((
  self.anim!=nil and
  not self.rotting
 ) or grid:isbarren(
  self.x,self.y
 )) then
  return false
 end

 local t=tree:new(
  self.x,self.y,{
   player=self.player
  }
 )

 self.anim=cowrap(
  "root",seedroot_anim,self,t
 )

 --anim destroys seed

 return true
end

function seed:update()
 if self.destroy then
  --handle destruction by other
  --seeds w/o impacting ongoing
  --seed update iteration
  return true
 end

 if self.anim!=nil then
  if coinvoke(self.anim) then
   self.anim=nil
  end

  return self.destroy
 end

 self.age+=self.growrate

 if self.age>1 then
  self.rotting=true
  self.anim=cowrap(
   "rot",seedrot_anim,self
  )
 end

 if (not self.moving) return

 local dx=self.dx*self.speed
 local dy=self.dy*self.speed
 if grid:fits(
  self.x+dx,self.y+dy,self.r,self
 ) then
  self.x+=dx
  self.y+=dy
  grid:moved(self)

  if grid:iswater(
   self.x,self.y
  ) then
   self.anim=cowrap(
    "waterdrop",
    waterdrop_anim,self
   )
  end
 else
  self.moving=false
  self.growrate*=2
 end
end

function seed:draw()
 local y=flr(
  self.y*yscale
 )-self.h-5
 pal(self.player.pal)
 if self.h>=0 then
  spr(self.si,self.x-3,y)
 else
  sspr(
   self.si*8,0,8,6+self.h,
   self.x-3,y
  )
 end

 if self.selected then
  spr(16,self.x-3,y-7)
 end

 pal(0)
end

-->8
--tree

function create_angles(n,dmin)
 local angles={}
 -- first angle is always zero

 while #angles<n-1 do
  --find range of options
  local r=0
  local ap=0
  for a in all(angles) do
   r+=max(0,a-ap-dmin*2)
   ap=a
  end
  r+=max(0,1-ap-dmin*2)

  if r==0 then
   -- no room remaining
   return
  end

  local v=rnd(r)

  local insertpos
  local ap=0
  for i,a in pairs(angles) do
   local w=max(0,a-ap-dmin*2)
   if v<w then
    insertpos=i
		  break
   end
   v-=w
   ap=a
  end
  local angle=ap+v+dmin
  if insertpos!=nil then
   add(angles,angle,insertpos)
  else
   add(angles,angle)
  end
 end

 add(angles,0)
 local offset=rnd(1)
 for i=1,#angles do
  angles[i]+=offset
  angles[i]-=flr(angles[i])
 end

 return angles
end

tree={}
function tree:new(x,y,o)
 o=setmetatable(o or {},self)
 self.__index=self

 o.x=x
 o.y=y
 o.r=o.r or tree_r
 o.maxseeds=o.maxseeds or 3

 o.age=o.age or 0
 o.rate_refresh=0

 o.seeds=nil

 return o
end

function tree:_blossom()
 self.seeds={}
 local angles=create_angles(
  self.maxseeds,0.15
 )

 for a in all(angles) do
  local s=seed:new(
   sin(a),cos(a),{
    player=self.player
   }
  )
  s.x=self.x+s.dx*branch_l
  s.y=self.y+s.dy*branch_l
  s.r=seed_r
  if hgrid:fits(s.x,s.y,s.r) then
   s.h=seeddrop_h
   s.si=1
   hgrid:add(s)
   add(self.seeds,s)
  end
 end
 self.seed_si=1
end

function tree:_can_drop(
 s,kills
)
 if grid:hits_wall(
  s.x,s.y,s.r
 ) then
  return false
 end

 local fits=true
 local visitor=function(obj)
  --drop destroys seeds and
  --small trees
  if isseed(obj) then
   add(kills,obj)
  else
   assert(istree(obj))
   if obj.age<0.25 then
    add(kills,obj)
   else
    --high tree prevents drop
    fits=false
   end
  end
 end

 grid:visit_hits(
  s.x,s.y,s.r,visitor
 )

 return fits
end

function tree:_dropseeds()
 for s in all(self.seeds) do
  hgrid:del(s)

  local kills={}
  if self:_can_drop(
   s,kills
  ) then
   s.anim=cowrap(
    "seeddrop",seeddrop_anim,
    s,kills
   )
  else
   s.anim=cowrap(
    "seedsplat",seedsplat_anim,
    s
   )
  end

  grid:add(s)
 end
end

function tree:_update_growrate()
 local c=1 --crowdedness
 local visitor=function(obj)
  if istree(obj) then
   local d=vlen(
    obj.x-self.x,obj.y-self.y
   )
   c+=max(roots_r-d,0)/roots_r
  end
 end
 grid:visit_hits(
  self.x,self.y,roots_r,
  visitor,self
 )

 self.growrate=max_growrate/c
end

function tree:update()
 if self.destroy then
  return true
 end

 if self.age>=self.rate_refresh then
  self:_update_growrate()
  self.rate_refresh+=0.1
 end
 self.age+=self.growrate

 if (self.age<0.7) return

 if self.seeds==nil then
  self:_blossom()
  return
 end

 local seed_si=max(1,min(4,ceil(
  (self.age-0.7)/0.3*5
 )))
 if seed_si!=self.seed_si then
  for s in all(self.seeds) do
   s.si=seed_si
  end
  self.seed_si=seed_si
 end

 if (self.age<1) return

 self:_dropseeds()
 return true
end

tree_sprites={
 192,193,208,209,
 194,196,198,200,202,204,206,
 224,226,228,230,232,234
}

--draws the trunk
function tree:draw()
 local h=flr(
  min(self.age,0.25)*4*tree_h
 )

 local x=self.x
 local y=flr(self.y*yscale)
 line(x,y,x,y-h,4)
 line(x+1,y,x+1,y-h,5)
 line(
  x,y-h,x+1,y-h,
  self.player.pal[6]
 )
end

function tree:draw_crown()
 if (self.age<=0.3) return

 local si=min(
  ceil((self.age-0.3)*40),17
 )
 pal(7,self.player.pal[6])
 if si<5 then
  spr(
   tree_sprites[si],
   self.x-3,
   self.y*yscale-8
  )
 else
  spr(
   tree_sprites[si],
   self.x-7,
   self.y*yscale-11,
   2,2
  )
 end
 pal(0)
end

-->8
--players

player={}
player.__index=player

function player:new(o)
 assert(o.pal!=nil)

 setmetatable(o,self)

 o.seeds={}
 o.trees={}

 return o
end

function player:_listfor(obj)
 if isseed(obj) then
  return self.seeds
 end
 if istree(obj) then
  return self.trees
 end
end

function player:unit_added(obj)
 if obj.player!=self then
  return false
 end

 local l=self:_listfor(obj)

 add(l,obj)
 obj._pi=#l

 return true
end

function player:unit_removed(
 obj
)
 if obj.player!=self then
  return false
 end

 local l=self:_listfor(obj)
 assert(l[obj._pi]==obj)

 local last=deli(l)
 if obj!=last then
  last._pi=obj._pi
  l[obj._pi]=last
 end

 return true
end

--human player
hplayer={}
extend(hplayer,player)
hplayer.__index=hplayer

function hplayer:new(o)
 o=player.new(self,o)
 setmetatable(o,self)

 o.selected=nil

 return o
end

function hplayer:_unselect()
 if self.selected!=nil then
  self.selected.selected=false
  self.selected=nil
 end
end

function hplayer:_select(obj)
 if obj!=nil then
  assert(self.selected==nil)
  self.selected=obj
  obj.selected=true
 end
end

function hplayer:unit_added(obj)
 if (
  player.unit_added(self,obj)
  and isseed(obj)
  and #self.seeds==1
 ) then
  self:_select(obj,true)
 end
end

function hplayer:unit_removed(
 obj
)
 if (
  player.unit_removed(self,obj)
  and obj==self.selected
 ) then
  self:_unselect()
  self:_select_closest(
   obj.x,obj.y
  )
 end
end

function hplayer:_select_closest(
 x,y
)
 local dmin=1000
 local nearest=nil
 for s in all(self.seeds) do
  local d=vlen(s.x-x,s.y-y)
  if d<dmin then
   dmin=d
   nearest=s
  end
 end
 self:_select(nearest)
end

function hplayer:_move_selection(
 dx,dy
)
 local sel=self.selected
 if (sel==nil) return

 local nxt=nil
 local dmin=2000
 for s in all(self.seeds) do
  if s!=sel then
   local vx=s.x-sel.x
   local vy=s.y-sel.y
   local mx=vx*dx
   local my=vy*dy
   if mx>=0 and my>=0 then
    --direction matches
    local d=abs(mx)+abs(my)
    if (
     (dx!=0)==(abs(vx)<=abs(vy))
    ) then
     --not in target quadrant
     d+=1000
    end

    if d<dmin then
     dmin=d
     nxt=s
    end
   end
  end
 end

 if nxt!=nil then
  self:_unselect()
  self:_select(nxt)
 end
end

function hplayer:update()
 if btnp(⬅️) then
  self:_move_selection(-1,0)
 end
 if btnp(➡️) then
  self:_move_selection(1,0)
 end
 if btnp(⬆️) then
  self:_move_selection(0,-1)
 end
 if btnp(⬇️) then
  self:_move_selection(0,1)
 end
 if (
  btnp(❎) and
  self.selected!=nil
 ) then
  self.selected:root()
 end
end

--computer player
cplayer={}
extend(cplayer,player)
cplayer.__index=cplayer

function cplayer:new(o)
 o=player.new(self,o)
 setmetatable(o,self)

 o.switch_count=0
 o.selected_idx=1
 o:_nxt_rooting()

 return o
end

function cplayer:_nxt_rooting()
 self.root_age=0.2+rnd(0.7)
end

function cplayer:update()
 local ns=#self.seeds
 if (ns==0) return

 self.switch_count-=1
 if self.switch_count<0 then
  self.selected_idx+=1
  self.switch_count=15
 end

 if self.selected_idx>ns then
  self.selected_idx=1
 end

 local s=self.seeds[
  self.selected_idx
 ]
 if s.age>=self.root_age then
  s:root()
  self:_nxt_rooting()
 end
end

-->8
--main

function _init()
 pal({
  [1]=-16,--dark brown (bg)
  [8]=-8, --dark red
  [9]=-13,--blue/green
  [5]=-11,--dark grey (tree)
  [10]=-5,--med. green
  [6]=-15
 },1)

 progress_stats=stats:new()
 menu=levelmenu:new()

 scene=menu
end

game={}
function game:new(level)
 local o=setmetatable({},self)
 self.__index=self

 o:load_level(level)

 return o
end

function game:load_level(level)
 local ld=level_defs[
  level
 ].data
 self.level=level

 --todo: make members?
 grid=cellgrid:new({
  mx=ld.mapdef[1],
  my=ld.mapdef[2],
  ncols=ld.mapdef[3],
  nrows=ld.mapdef[4]
 })
 hgrid=cellgrid:new()

 self.players={}
 for i,p in pairs(ld.plyrs) do
  local plyr={
   pal=player_pals[i]
  }
  if i==1 then
   plyr=hplayer:new(plyr)
  else
   plyr=cplayer:new(plyr)
  end
  add(self.players,plyr)
  grid:add_observer(plyr)

  local t=tree:new(
   p[1],p[2],{player=plyr}
  )
  grid:add(t)
  t.age=0.7
 end

 local areas={}
 for args in all(ld.goals) do
  add(areas,rectgoal(args))
 end
 self.goal=areagoal:new(
  areas,self.players
 )
 grid:add_observer(self.goal)
end

function game:update()
 if self.anim!=nil then
  if coinvoke(self.anim) then
   self.anim=nil
  end

  return
 end

 grid:update_units()

 for p in all(self.players) do
  p:update()
 end

 local msg=nil
 local human=self.players[1]
 local winner=self.goal.winner
 if winner!=nil then
  if winner==human then
   msg="level complete!"
  else
   msg="beaten by bots"
  end
 elseif (
  #human.seeds+#human.trees==0
 ) then
  msg="game over"
 end

 if msg!=nil then
  self.anim=cowrap(
   "gameend",
   gameend_anim,self,msg
  )
 end
end

function draw_treetop(unit)
 if istree(unit) then
  unit:draw_crown()
 end
end

function game:draw()
 cls()

 camera(
  grid.ncols*4-64,
  grid.nrows*3-70
 )

 --draw map and units on ground
 grid:draw()

 --draw tree tops
 grid:visit_units(draw_treetop)

 --draw seeds on top of trees
 hgrid:draw_units(nil)

 camera()

 self.goal:draw()
 if self.msg!=nil then
  print(
   self.msg,63-#self.msg*2,62,7
  )
 end
end

function start_game(level)
 scene=game:new(level)
end

function _draw()
 scene:draw()
end

function _update()
 scene:update()
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000000000000000000000000000006600000000000000000000000000000000000000000000c0000c00000000000000000000000000000000060000000
00077000000000000000000000060000006765000000000000000000000000000000000000c00c0000c00c000000000000000000000660000600000000000060
000770000000000000076000006750000066650000000000000000000000000000000000000cc000000cc0000cc00cc000000000006765000006670000000000
0070070000060000000650000005000000055000000000000000000000000000000cc000000cc00000000000000cc00000c00c00006665000067650000066000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600006000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000006
00060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67777760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06777600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00676000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777000000007115511755555555555555515555555155555555000000000000000000000000
77777777777777777777777777777777777777777777777777777777000000001555555155555551555555515555555155555551000000000000000000000000
11001111001101001551115100000000666666661111111116666661000000005555555555555555555555515555555155555555000000000000000000000000
11111100110000111110551100000000666666666666666666666666000000005555555555555551555555515555555155555551000000000000000000000000
01111111001110005155100166666666666666666666666666666666000000001555555155555555555555515555555155555555000000000000000000000000
11101111011101101011155166666666666666666666666666666666000000000115511011111111515151511111111151515151000000000000000000000000
11111001100001001105511166666666666666666666666666666666000000000000000000000000000000000000000000000000000000000000000000000000
10011111000110115511115566666666666666666666666666666666000000001000000100000000000000000000000000000000000000000000000000000000
77777777775775777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777777755775575555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555665551111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555665550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555665555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555665555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555551661555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555516666155555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555551000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555551000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
51515151000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000777777777777777701111110111551115555555573333337
00000000000000000000000000000000000000000000000000000000000000000000000000000000777777777777777711555511155555515555555533339933
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000006666666615555551555555555555555533333339
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666ddd6615555551555555555555555539933399
00000000000000000000000000000000000000000000000000000000000000000000000000000000666666666666666611555511155555515555555593339999
0000000000000000000000000000000000000000000000000000000000000000000000000000000066666666d66666dd01111110011551105555555519999991
000000000000000000000000000000000000000000000000000000000000000000000000000000006666666666ddd66600000000000000000000000014141441
000000000000000000000000000000000000000000000000000000000000000000000000000000006dd666d66666666610000001100000010000000001441410
4414041444140414441404144414041444a41404140414041404842424841404a400000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4404140444041404440414044404140444a43434041404140414041404140414a400000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4434343444343434443434344434343444a44444140414041404140414041404a400000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4404140444041404440414044404140444949494949494949494949494949494b400000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44140414441404144414041444140414440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44041404440414044404140444041404440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44343434443434344434343444343434440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000040000400000000000000000000000000000000000000000000000000004400000004000000440000000400000074000000040000007400000004000
00404400054044500004000000000000004400000000040000440000000004000044500000005400004450000000540000445000000057000044500000005700
00577500005775000005400000004000005540000000440000554000000044000055400000004440005540000000444000554000000044400455400000004440
00445400004454000000540000445000000054000044550000005400004455000000540000445550000054000044555000005400004455500500540000445550
00550500045505400000054044550000000005404455000000000540445500000000054044550000000005404455000000000540445500000000054044550000
00000000050000500000005775000000000000577500000000000057750000000000005775000000000000577500000000000057750000000000005775000000
00000000000000000000004454000000000000445400000000000044540000000000004454000000000000445400000000000044540000000000004454000000
40000000400000000000445505400000000044550540000000004455054000000000445505400000000044550540000000004455054000000000445505400000
54000044540000440004550000540000044455000054000004445500005400000444550000540000044455000054000004445500005400000444550000540040
05404455054044550005000000054000055500000005440005550000000544000545000000054400054500000005440005750000000544000575000000054450
00577500005775000000000000005000000000000000550000000000000055000054000000044500005400000004450000540000000475000054000000047500
00445400004454000000000000000000000000000000000000000000000000000005000000055000000500000005500000050000000550000005000000055000
44550540445505400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55000054550000540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000005000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000040000000000000004000000000000000440004000000000044400400000000004470070000000000000000000000000000000000000
00074000000040000007450000044000000745000004400000074550005440000007455500544000000745550054400000000000000000000000000000000000
00445000000057000044500000055700004450000005570000445000000557000044500000055700004450000005570000000000000000000000000000000000
04554000000044400455400000004440045540000000444004554000000044400455400000004440045540000000444000000000000000000000000000000000
05005400004455540500540000445554450054000044555445005400004455544500540000445554750054000044555400000000000000000000000000000000
00000540445500050000054044550005500005404455000550000540445500055000054044550004500005404455000700000000000000000000000000000000
00000057750000000000005775000000000000577500000000000057750000000000005775000005000000577500000500000000000000000000000000000000
00000044540000000000004454000000000000445400000000000044540000004000004454000000700000445400000000000000000000000000000000000000
40004455054000004000445505400000400044550540000440004455054000044000445505400004400044550540000700000000000000000000000000000000
54445500005400405444550000540040544455000054004554445500005400455444550000540045544455000054004500000000000000000000000000000000
05750000000544500575000000054450057500000005445005750000000544500575000000054450057500000005445000000000000000000000000000000000
00540000000475000054400000047500005440000004750000544000000475000054400000047500005440000004750000000000000000000000000000000000
00050000000550000005500000455000000550000045500000055400044550000005540044455000000557007445500000000000000000000000000000000000
00000000000000000000000000500000000000000050000000000500055000000000050055500000000005005550000000000000000000000000000000000000
__label__
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggoooogggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggoooogggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggooeeoo22gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggooeeoo22gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggoooooo22ggggggggggooooggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggeeeegggggggggggggg
ggggggggggggggggggggggggggggoooooo22ggggggggggooooggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggeeeegggggggggggggg
gggggggggggggggggggggggggggggg2222ooggggooggooeeoo22gggggggggggggggggggggggggggggggggggggggggg4444eeggggeeggeeffee22gggggggggggg
gggggggggggggggggggggggggggggg2222ooggggooggooeeoo22gggggggggggggggggggggggggggggggggggggggggg4444eeggggeeggeeffee22gggggggggggg
ggggggggggggggggggggggggggoo44llllllggggll44oooooo22ggggggggggggggggggggggggggggggggggggggee44llllllggggll44eeeeee22gggggggggggg
ggggggggggggggggggggggggggoo44llllllggggll44oooooo22ggggggggggggggggggggggggggggggggggggggee44llllllggggll44eeeeee22gggggggggggg
gggggggggggggggggggggggg4444llggggggggggggllll2222gggggggggggggggggggggggggggggggggggggg4444llggggggggggggllll2222gggggggggggggg
gggggggggggggggggggggggg4444llggggggggggggllll2222gggggggggggggggggggggggggggggggggggggg4444llggggggggggggllll2222gggggggggggggg
gggggggggggggggggggggg44llll44gggggggggggggg444444gggggggggggggggggggggggggggggggggggg44llll44gggggggggggggg444444gggggggggggggg
gggggggggggggggggggggg44llll44gggggggggggggg444444gggggggggggggggggggggggggggggggggggg44llll44gggggggggggggg444444gggggggggggggg
ggggggggggggggggggggoollggggll44gggggggg4444llllll44ggggggggggggggggggggggggggggggeeeellggggll44gggggggg4444llllll44gggggggggggg
ggggggggggggggggggggoollggggll44gggggggg4444llllll44ggggggggggggggggggggggggggggggeeeellggggll44gggggggg4444llllll44gggggggggggg
ggggggggggggggggggggllggggggggll44gg4444llllggggggooggggggggggggggggggggggggggggeeffee22ggggggll44gg4444llllggggggeegggggggggggg
ggggggggggggggggggggllggggggggll44gg4444llllggggggooggggggggggggggggggggggggggggeeffee22ggggggll44gg4444llllggggggeegggggggggggg
gggggggggggggggggggggggggggggggglloooollggggggggooooggggggggggggggggggggggggggggeeeeee22gggggggglleeeellggggggggggllgggggggggggg
gggggggggggggggggggggggggggggggglloooollggggggggooooggggggggggggggggggggggggggggeeeeee22gggggggglleeeellggggggggggllgggggggggggg
ggggggggggggggggggggoogggggggggg4444ll44ggggggooeeoo22gggggggggggggggggggggggggggg2222gggggggggg4444ll44gggggggggggggggggggggggg
ggggggggggggggggggggoogggggggggg4444ll44ggggggooeeoo22gggggggggggggggggggggggggggg2222gggggggggg4444ll44gggggggggggggggggggggggg
gggggggggggggggggggg44gggggg4444llllllll44ggggoooooo22gggggggggggggggggggggggggggggg44gggggg4444llllllll44ggggggggeegggggggggggg
gggggggggggggggggggg44gggggg4444llllllll44ggggoooooo22gggggggggggggggggggggggggggggg44gggggg4444llllllll44ggggggggeegggggggggggg
ggggggggggggggggggggll444444llllgg44llggll44gggg2222ggggggggggggggggggggggggggggggggll444444llllgg44llgglleeeegg44llgggggggggggg
ggggggggggggggggggggll444444llllgg44llggll44gggg2222ggggggggggggggggggggggggggggggggll444444llllgg44llgglleeeegg44llgggggggggggg
gggggggggggggggggggggglloollgggggg44llggggll4444llgggggggggggggggggggggggggggggggggggglleellgggggg44llggeeffee22llgggggggggggggg
gggggggggggggggggggggglloollgggggg44llggggll4444llgggggggggggggggggggggggggggggggggggglleellgggggg44llggeeffee22llgggggggggggggg
ggggggggggggggggggggggggll4444gggg44llgggg44oollggggggggggggggggggggggggggggggggggggggggll4444gggg44llggeeeeee22gggggggggggggggg
ggggggggggggggggggggggggll4444gggg44llgggg44oollggggggggggggggggggggggggggggggggggggggggll4444gggg44llggeeeeee22gggggggggggggggg
ggggggggggggggggggggggggggllllooggggoo4444llllgggggggggggggggggggggggggggggggggggggggggggglllleeggggee44442222gggggggggggggggggg
ggggggggggggggggggggggggggllllooggggoo4444llllgggggggggggggggggggggggggggggggggggggggggggglllleeggggee44442222gggggggggggggggggg
ggggggggggggggggggggggggggggggllggggllllllggggggggggggggggggggggggggggggggggggggggggggggggggggllggggllllllgggggggggggggggggggggg
ggggggggggggggggggggggggggggggllggggllllllggggggggggggggggggggggggggggggggggggggggggggggggggggllggggllllllgggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggrrrrggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggddddgggggggggggggg
ggggggggggggggggggggggggrrrrggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggddddgggggggggggggg
ggggggggggggggggggggggrrbbrr33ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggddccdd22gggggggggggg
ggggggggggggggggggggggrrbbrr33ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggddccdd22gggggggggggg
ggggggggggggggggggggggrrrrrr334444rrggggrrgggggggggggggggggggggggggggggggggggggggggggggggggggg4444ddggggddggdddddd22gggggggggggg
ggggggggggggggggggggggrrrrrr334444rrggggrrgggggggggggggggggggggggggggggggggggggggggggggggggggg4444ddggggddggdddddd22gggggggggggg
gggggggggggggggggggggggg333344llllllggggll4444ggggrrrrggggggggggggggggggggggggggggggggggggdd44llllllggggll44442222gggggggggggggg
gggggggggggggggggggggggg333344llllllggggll4444ggggrrrrggggggggggggggggggggggggggggggggggggdd44llllllggggll44442222gggggggggggggg
gggggggggggggggggggggggg4444llggggggggggggllllrrrrbbrr33gggggggggggggggggggggggggggggggg4444llggggggggggggllllddgggggggggggggggg
gggggggggggggggggggggggg4444llggggggggggggllllrrrrbbrr33gggggggggggggggggggggggggggggggg4444llggggggggggggllllddgggggggggggggggg
gggggggggggggggggggggg44llll44gggggggggggggg4444rrrrrr33ggggggggggggggggggggggggggdddd44llll44gggggggggggggg444444gggggggggggggg
gggggggggggggggggggggg44llll44gggggggggggggg4444rrrrrr33ggggggggggggggggggggggggggdddd44llll44gggggggggggggg444444gggggggggggggg
ggggggggggggggggggggrrllggggll44gggggggg4444llllll3333ggggggggggggggggggggggggggddccdd22ggggll44gggggggg4444llllll44gggggggggggg
ggggggggggggggggggggrrllggggll44gggggggg4444llllll3333ggggggggggggggggggggggggggddccdd22ggggll44gggggggg4444llllll44gggggggggggg
ggggggggggggggggggggllggggggggll44gg4444llllggggggrrggggggggggggggggggggggggggggdddddd22ggggggll44gg4444llllggggggddgggggggggggg
ggggggggggggggggggggllggggggggll44gg4444llllggggggrrggggggggggggggggggggggggggggdddddd22ggggggll44gg4444llllggggggddgggggggggggg
ggggggggggggggggggggggggggggggggllrrrrllggggggggggllgggggggggggggggggggggggggggggg2222ggggggggggllddddllggggggddddllgggggggggggg
ggggggggggggggggggggggggggggggggllrrrrllggggggggggllgggggggggggggggggggggggggggggg2222ggggggggggllddddllggggggddddllgggggggggggg
ggggggggggggggggggggrrgggggggggg4444ll44ggggggggggggggggggggggggggggggggggggggggggggddgggggggggg4444ll44ggggddccdd22gggggggggggg
ggggggggggggggggggggrrgggggggggg4444ll44ggggggggggggggggggggggggggggggggggggggggggggddgggggggggg4444ll44ggggddccdd22gggggggggggg
gggggggggggggggggggg44gggggg4444llllllll44ggggggggrrgggggggggggggggggggggggggggggggg44gggggg4444llllllll44ggdddddd22gggggggggggg
gggggggggggggggggggg44gggggg4444llllllll44ggggggggrrgggggggggggggggggggggggggggggggg44gggggg4444llllllll44ggdddddd22gggggggggggg
ggggggggggggggggggggll444444llllrrrrllggll44gggg44llggggggggggggggggggggggggggggggggll444444llllgg44llggll44gg2222llgggggggggggg
ggggggggggggggggggggll444444llllrrrrllggll44gggg44llggggggggggggggggggggggggggggggggll444444llllgg44llggll44gg2222llgggggggggggg
ggggggggggggggggggggggllrrllggrrbbrr33ggggll4444llggggggggggggggggggggggggggggggggggggllddllgggggg44llggggll4444llgggggggggggggg
ggggggggggggggggggggggllrrllggrrbbrr33ggggll4444llggggggggggggggggggggggggggggggggggggllddllgggggg44llggggll4444llgggggggggggggg
ggggggggggggggggggggggggll4444rrrrrr33gggg44rrllggggggggggggggggggggggggggggggggggggggggll4444gggg44llgggg44ddllgggggggggggggggg
ggggggggggggggggggggggggll4444rrrrrr33gggg44rrllggggggggggggggggggggggggggggggggggggggggll4444gggg44llgggg44ddllgggggggggggggggg
ggggggggggggggggggggggggggllllrr3333rr4444llllggggggggggggggggggggggggggggggggggggggggggggllllddggggdd4444llllgggggggggggggggggg
ggggggggggggggggggggggggggllllrr3333rr4444llllggggggggggggggggggggggggggggggggggggggggggggllllddggggdd4444llllgggggggggggggggggg
ggggggggggggggggggggggggggggggllggggllllllggggggggggggggggggggggggggggggggggggggggggggggggggggllggggllllllgggggggggggggggggggggg
ggggggggggggggggggggggggggggggllggggllllllggggggggggggggggggggggggggggggggggggggggggggggggggggllggggllllllgggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000104040404000202020202000000080202000000000000000000000000000800000000000000000000000000000000000000000000000000040402020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4c494949494949494949494949494a4c494949494949494949494949494a6060606060606060606060606060604444444444444444444444444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a404140414041404140414041404a4a404140414041404140414041404a6040414041404140414041404140604440414041404144414041404140440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a414041404140414041404140414a4a414041404140414041404140414a6041404140414041404140414041604441424242424044404242424241440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a404142424241404142424241404a4a404142424242404242424241404a6040414242426060604242424140604440424242424150414242424240440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a414042424240414042424240414a4a4140424242424a4242424240414a6041404242426060604242424041604441424242424050404242424241440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a404142424241404142424241404a4a4041424242424a4242424241404a6040414242426060604242424140604440424242424145414242424240440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a414041404140414041404140414a4a4140424242424a4242424240414a6041406060606060606060604041604441404140414044404140414041440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a404140414041404140414041404a4a4041404949494c4949494041404a6040416060606060606060604140604443435050434344434350504343440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a414041404140414041404140414a4a4140424242424a4242424240414a6041406060606060606060604041604441404140414044404140414041440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a404142424241404142424241404a4a4041424242424a4242424241404a6040414242426060604242424140604440424242424144414242424240440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a414042424240414042424240414a4a4140424242424a4242424240414a6041404242426060604242424041604441424242424050404242424241440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a404142424241404142424241404a4a404142424242404242424241404a6040414242426060604242424140604440424242424150414242424240440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a414041404140414041404140414a4a414041404140414041404140414a6041404140414041404140414041604441424242424045404242424241440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a404140414041404140414041404a4a404140414041404140414041404a6040414041404140414041404140604440414041404144414041404140440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
49494949494949494949494949494b49494949494949494949494949494b6060606060606060606060606060604443434343434344434343434343440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444444444444444444444444444444c49494949494949494949494949494a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44404140444041404440414044404140444a40414041404140414041404143434a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44414041444140414441404144414041444a41404140414041404140414044444a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44404140444041404440414046404140444a40414842424840414041404140414a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44434343444343434443434344434343444a41404242424241404140414041404a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44404140444041404440414044404140444a40414242424240414842424840414a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44414041444140414441404144414041444a41404842424841404242424241404a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44404140444041404440414044404140444a40414041404140414242424240414a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44434343444343434443434344434343444a41404140414041404842424841404a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44404140444041404440414044404140444a40414842424840414041404140414a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44414041444140414441404144414041444a41404242424241404140414041404a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44404140444041404440414044404140444a40414242424240414842424840414a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44434343444343434443434344434343444a41404842424841404242424241404a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44404140444041404440414044404140444a40414041404140414242424240414a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
